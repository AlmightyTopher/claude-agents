# Conflict Model
# Represents a Git merge conflict that requires user resolution

class Conflict {
    [guid]$ConflictId
    [string]$FilePath
    [datetime]$DetectedAt
    [string]$LocalChanges
    [string]$RemoteChanges
    [ResolutionStatus]$ResolutionStatus
    [ResolutionStrategy]$ResolutionStrategy
    [datetime]$ResolvedAt

    # Constructor
    Conflict([string]$filePath) {
        $this.ConflictId = [guid]::NewGuid()
        $this.FilePath = $filePath
        $this.DetectedAt = Get-Date
        $this.LocalChanges = ""
        $this.RemoteChanges = ""
        $this.ResolutionStatus = [ResolutionStatus]::Unresolved
        $this.ResolutionStrategy = [ResolutionStrategy]::None
        $this.ResolvedAt = [datetime]::MinValue
    }

    # Set conflict details
    [void] SetConflictDetails([string]$localChanges, [string]$remoteChanges) {
        $this.LocalChanges = $localChanges
        $this.RemoteChanges = $remoteChanges
    }

    # Mark conflict as resolved
    [void] Resolve([ResolutionStrategy]$strategy) {
        if ($this.ResolutionStatus -eq [ResolutionStatus]::Resolved) {
            Write-Warning "Conflict already resolved"
            return
        }

        $this.ResolutionStatus = [ResolutionStatus]::Resolved
        $this.ResolutionStrategy = $strategy
        $this.ResolvedAt = Get-Date

        # Validate resolution time is after detection
        if ($this.ResolvedAt -lt $this.DetectedAt) {
            throw "Invalid resolution time: must be after detection time"
        }
    }

    # Mark conflict as abandoned
    [void] Abandon() {
        $this.ResolutionStatus = [ResolutionStatus]::Abandoned
        $this.ResolvedAt = Get-Date
    }

    # Reopen conflict (resolution failed)
    [void] Reopen() {
        if ($this.ResolutionStatus -ne [ResolutionStatus]::Resolved) {
            Write-Warning "Can only reopen resolved conflicts"
            return
        }

        $this.ResolutionStatus = [ResolutionStatus]::Unresolved
        $this.ResolutionStrategy = [ResolutionStrategy]::None
        $this.ResolvedAt = [datetime]::MinValue
    }

    # Check if conflict can be auto-resolved
    [bool] CanAutoResolve() {
        # Simple heuristics for auto-resolution
        $localLines = $this.LocalChanges -split "`n"
        $remoteLines = $this.RemoteChanges -split "`n"

        # If one side is empty, can auto-resolve
        if ([string]::IsNullOrWhiteSpace($this.LocalChanges) -or
            [string]::IsNullOrWhiteSpace($this.RemoteChanges)) {
            return $true
        }

        # If changes are whitespace-only differences
        $localTrimmed = ($this.LocalChanges -replace '\s+', '')
        $remoteTrimmed = ($this.RemoteChanges -replace '\s+', '')
        if ($localTrimmed -eq $remoteTrimmed) {
            return $true
        }

        # If changes are in completely different line ranges (no overlap)
        # This is a simplified check - real implementation would parse git diff
        return $false
    }

    # Get suggested resolution strategy
    [ResolutionStrategy] GetSuggestedStrategy() {
        if ($this.CanAutoResolve()) {
            # If whitespace-only, keep local
            $localTrimmed = ($this.LocalChanges -replace '\s+', '')
            $remoteTrimmed = ($this.RemoteChanges -replace '\s+', '')
            if ($localTrimmed -eq $remoteTrimmed) {
                return [ResolutionStrategy]::KeepLocal
            }

            # If one side is empty
            if ([string]::IsNullOrWhiteSpace($this.LocalChanges)) {
                return [ResolutionStrategy]::KeepRemote
            }
            if ([string]::IsNullOrWhiteSpace($this.RemoteChanges)) {
                return [ResolutionStrategy]::KeepLocal
            }

            return [ResolutionStrategy]::Merge
        }

        # Complex conflict requires manual resolution
        return [ResolutionStrategy]::Manual
    }

    # Get conflict markers for manual resolution
    [hashtable] GetConflictMarkers() {
        return @{
            Start = "<<<<<<< HEAD"
            Divider = "======="
            End = ">>>>>>> origin/master"
        }
    }

    # Convert to hashtable for serialization
    [hashtable] ToHashtable() {
        return @{
            ConflictId = $this.ConflictId.ToString()
            FilePath = $this.FilePath
            DetectedAt = $this.DetectedAt.ToString('o')
            LocalChanges = $this.LocalChanges
            RemoteChanges = $this.RemoteChanges
            ResolutionStatus = $this.ResolutionStatus.ToString()
            ResolutionStrategy = $this.ResolutionStrategy.ToString()
            ResolvedAt = if ($this.ResolvedAt -ne [datetime]::MinValue) {
                $this.ResolvedAt.ToString('o')
            } else {
                $null
            }
        }
    }
}

# ResolutionStatus enum
enum ResolutionStatus {
    Unresolved
    Resolved
    Abandoned
}

# ResolutionStrategy enum
enum ResolutionStrategy {
    None
    Merge
    Rebase
    KeepLocal
    KeepRemote
    Manual
}

# Export the class and enums
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
