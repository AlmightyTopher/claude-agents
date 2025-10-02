# SyncLog Model
# Chronological record of all sync operations for auditing and troubleshooting

using module ./SyncOperation.psm1

class SyncLog {
    [guid]$LogId
    [System.Collections.ArrayList]$Operations
    [datetime]$SessionStart
    [datetime]$SessionEnd
    [int]$TotalFiles
    [int]$SuccessCount
    [int]$FailureCount
    [int]$ConflictCount

    # Constructor
    SyncLog() {
        $this.LogId = [guid]::NewGuid()
        $this.Operations = [System.Collections.ArrayList]::new()
        $this.SessionStart = Get-Date
        $this.SessionEnd = [datetime]::MinValue
        $this.TotalFiles = 0
        $this.SuccessCount = 0
        $this.FailureCount = 0
        $this.ConflictCount = 0
    }

    # Add operation to log
    [void] AddOperation([SyncOperation]$operation) {
        [void]$this.Operations.Add($operation)

        # Update counters based on operation status
        switch ($operation.Status) {
            Success {
                $this.SuccessCount++
            }
            Failed {
                $this.FailureCount++
                if ($operation.ErrorMessage -match "conflict") {
                    $this.ConflictCount++
                }
            }
        }

        # Update total files count
        $this.TotalFiles += $operation.AffectedFiles.Count
    }

    # End the session
    [void] EndSession() {
        $this.SessionEnd = Get-Date

        # Validate session end is after start
        if ($this.SessionEnd -lt $this.SessionStart) {
            throw "Invalid session end time: must be after session start"
        }
    }

    # Get session duration
    [timespan] GetSessionDuration() {
        if ($this.SessionEnd -eq [datetime]::MinValue) {
            return (Get-Date) - $this.SessionStart
        }
        return $this.SessionEnd - $this.SessionStart
    }

    # Get operations by type
    [System.Collections.ArrayList] GetOperationsByType([OperationType]$type) {
        $filtered = [System.Collections.ArrayList]::new()
        foreach ($op in $this.Operations) {
            if ($op.OperationType -eq $type) {
                [void]$filtered.Add($op)
            }
        }
        return $filtered
    }

    # Get operations by status
    [System.Collections.ArrayList] GetOperationsByStatus([OperationStatus]$status) {
        $filtered = [System.Collections.ArrayList]::new()
        foreach ($op in $this.Operations) {
            if ($op.Status -eq $status) {
                [void]$filtered.Add($op)
            }
        }
        return $filtered
    }

    # Get failed operations
    [System.Collections.ArrayList] GetFailedOperations() {
        return $this.GetOperationsByStatus([OperationStatus]::Failed)
    }

    # Get operations within time range
    [System.Collections.ArrayList] GetOperationsByTimeRange([datetime]$start, [datetime]$end) {
        $filtered = [System.Collections.ArrayList]::new()
        foreach ($op in $this.Operations) {
            if ($op.Timestamp -ge $start -and $op.Timestamp -le $end) {
                [void]$filtered.Add($op)
            }
        }
        return $filtered
    }

    # Check if session is healthy (no failures)
    [bool] IsHealthy() {
        return $this.FailureCount -eq 0 -and $this.ConflictCount -eq 0
    }

    # Get summary statistics
    [hashtable] GetSummary() {
        return @{
            TotalOperations = $this.Operations.Count
            SuccessCount = $this.SuccessCount
            FailureCount = $this.FailureCount
            ConflictCount = $this.ConflictCount
            TotalFiles = $this.TotalFiles
            SessionDuration = $this.GetSessionDuration().ToString()
            IsHealthy = $this.IsHealthy()
        }
    }

    # Validate log integrity
    [bool] ValidateIntegrity() {
        # Check session end is after start
        if ($this.SessionEnd -ne [datetime]::MinValue) {
            if ($this.SessionEnd -lt $this.SessionStart) {
                return $false
            }
        }

        # Check counters match operations
        $actualSuccess = ($this.Operations | Where-Object { $_.Status -eq [OperationStatus]::Success }).Count
        $actualFailure = ($this.Operations | Where-Object { $_.Status -eq [OperationStatus]::Failed }).Count

        if ($actualSuccess -ne $this.SuccessCount) {
            Write-Warning "Success count mismatch: expected $($this.SuccessCount), actual $actualSuccess"
            return $false
        }

        if ($actualFailure -ne $this.FailureCount) {
            Write-Warning "Failure count mismatch: expected $($this.FailureCount), actual $actualFailure"
            return $false
        }

        return $true
    }

    # Convert to hashtable for JSON serialization
    [hashtable] ToHashtable() {
        $operationsArray = @()
        foreach ($op in $this.Operations) {
            $operationsArray += $op.ToHashtable()
        }

        return @{
            LogId = $this.LogId.ToString()
            Operations = $operationsArray
            SessionStart = $this.SessionStart.ToString('o')
            SessionEnd = if ($this.SessionEnd -ne [datetime]::MinValue) {
                $this.SessionEnd.ToString('o')
            } else {
                $null
            }
            TotalFiles = $this.TotalFiles
            SuccessCount = $this.SuccessCount
            FailureCount = $this.FailureCount
            ConflictCount = $this.ConflictCount
        }
    }

    # Create from JSON hashtable (deserialization)
    static [SyncLog] FromHashtable([hashtable]$data) {
        $log = [SyncLog]::new()
        $log.LogId = [guid]$data.LogId
        $log.SessionStart = [datetime]::Parse($data.SessionStart)

        if ($data.SessionEnd) {
            $log.SessionEnd = [datetime]::Parse($data.SessionEnd)
        }

        $log.TotalFiles = $data.TotalFiles
        $log.SuccessCount = $data.SuccessCount
        $log.FailureCount = $data.FailureCount
        $log.ConflictCount = $data.ConflictCount

        # Deserialize operations
        foreach ($opData in $data.Operations) {
            $operation = [SyncOperation]::FromHashtable($opData)
            [void]$log.Operations.Add($operation)
        }

        return $log
    }
}

# Export the class
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
