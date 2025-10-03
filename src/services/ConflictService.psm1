# ConflictService
# Merge conflict detection and resolution

using module ../models/Conflict.psm1
using module ./GitService.psm1

function Get-Conflicts {
    [CmdletBinding()]
    param()

    $conflicts = @()

    try {
        # Get files with merge conflicts
        $conflictFiles = git diff --name-only --diff-filter=U 2>$null

        if ($conflictFiles) {
            foreach ($file in ($conflictFiles -split "`n" | Where-Object { $_ })) {
                $conflict = [Conflict]::new($file)

                # Get conflict details from git diff
                $diffOutput = git diff $file 2>$null

                # Parse local and remote changes
                $localChanges = ""
                $remoteChanges = ""
                $inConflict = $false
                $isLocal = $false

                foreach ($line in ($diffOutput -split "`n")) {
                    if ($line -match '^<<<<<<<') {
                        $inConflict = $true
                        $isLocal = $true
                    }
                    elseif ($line -match '^=======') {
                        $isLocal = $false
                    }
                    elseif ($line -match '^>>>>>>>') {
                        $inConflict = $false
                    }
                    elseif ($inConflict) {
                        if ($isLocal) {
                            $localChanges += $line + "`n"
                        }
                        else {
                            $remoteChanges += $line + "`n"
                        }
                    }
                }

                $conflict.SetConflictDetails($localChanges.Trim(), $remoteChanges.Trim())
                $conflicts += $conflict
            }
        }
    }
    catch {
        Write-Warning "Error detecting conflicts: $($_.Exception.Message)"
    }

    return $conflicts
}

function Resolve-ConflictAuto {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ResolutionStrategy]$Strategy
    )

    $result = @{
        Success = $false
        Strategy = $Strategy
        Message = ""
    }

    try {
        switch ($Strategy) {
            ([ResolutionStrategy]::KeepLocal) {
                # Keep local version (ours)
                git checkout --ours $FilePath 2>&1 | Out-Null
                git add $FilePath 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    $result.Success = $true
                    $result.Message = "Resolved using local version"
                }
                else {
                    $result.Message = "Failed to apply KeepLocal strategy"
                }
            }
            ([ResolutionStrategy]::KeepRemote) {
                # Keep remote version (theirs)
                git checkout --theirs $FilePath 2>&1 | Out-Null
                git add $FilePath 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    $result.Success = $true
                    $result.Message = "Resolved using remote version"
                }
                else {
                    $result.Message = "Failed to apply KeepRemote strategy"
                }
            }
            ([ResolutionStrategy]::Merge) {
                # Attempt 3-way merge
                # This is complex and might fail - for now, fall back to manual
                $result.Message = "Automatic merge not yet implemented. Use Manual strategy."
                $result.Success = $false
            }
            ([ResolutionStrategy]::Rebase) {
                # Rebase requires git rebase --continue
                $result.Message = "Rebase strategy requires manual 'git rebase --continue'"
                $result.Success = $false
            }
            default {
                $result.Message = "Invalid auto-resolution strategy: $Strategy"
            }
        }
    }
    catch {
        $result.Message = "Error during auto-resolution: $($_.Exception.Message)"
    }

    return $result
}

function Get-ResolutionGuidance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [ResolutionStrategy]$Strategy
    )

    $guidance = @{
        FilePath = $FilePath
        Strategy = $Strategy
        Instructions = @()
        ConflictMarkers = @{
            Start = "<<<<<<< HEAD"
            Divider = "======="
            End = ">>>>>>> origin/master"
        }
    }

    switch ($Strategy) {
        ([ResolutionStrategy]::Manual) {
            $guidance.Instructions = @(
                "1. Open $FilePath in your editor"
                "2. Look for conflict markers: <<<<<<< HEAD"
                "3. Choose which version to keep or combine both"
                "4. Remove conflict markers (<<<<<<, =======, >>>>>>>)"
                "5. Save the file"
                "6. Run: git add $FilePath"
                "7. Run: Sync-Agents to complete resolution"
            )
        }
        ([ResolutionStrategy]::KeepLocal) {
            $guidance.Instructions = @(
                "Strategy: Keep your local changes, discard remote changes"
                "Run: Resolve-SyncConflict -FilePath '$FilePath' -Strategy KeepLocal -AutoResolve"
            )
        }
        ([ResolutionStrategy]::KeepRemote) {
            $guidance.Instructions = @(
                "Strategy: Discard your local changes, accept remote changes"
                "Run: Resolve-SyncConflict -FilePath '$FilePath' -Strategy KeepRemote -AutoResolve"
            )
        }
        ([ResolutionStrategy]::Merge) {
            $guidance.Instructions = @(
                "Strategy: Attempt to combine both changes"
                "This requires careful manual merging:"
                "1. Open $FilePath"
                "2. Combine changes from both versions"
                "3. Test the result"
                "4. git add $FilePath"
                "5. Sync-Agents to complete"
            )
        }
        ([ResolutionStrategy]::Rebase) {
            $guidance.Instructions = @(
                "Strategy: Rebase local commits on top of remote"
                "This requires Git rebase:"
                "1. git rebase --continue (if already in rebase)"
                "2. Resolve conflicts as they appear"
                "3. git add <resolved-files>"
                "4. git rebase --continue"
                "5. Sync-Agents to push result"
            )
        }
        default {
            $guidance.Instructions = @("Unknown resolution strategy: $Strategy")
        }
    }

    return $guidance
}

function Test-ConflictResolved {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    try {
        # Check if file still has conflict markers
        $content = Get-Content $FilePath -Raw -ErrorAction Stop

        $hasMarkers = $content -match '<<<<<<< HEAD' -or
                      $content -match '=======' -or
                      $content -match '>>>>>>>'

        if ($hasMarkers) {
            return $false
        }

        # Check if file is still in conflict status in git
        $conflictFiles = git diff --name-only --diff-filter=U 2>$null
        $isInConflict = $conflictFiles -split "`n" | Where-Object { $_ -eq $FilePath }

        return -not $isInConflict
    }
    catch {
        Write-Warning "Error checking conflict status: $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Get-Conflicts, Resolve-ConflictAuto, Get-ResolutionGuidance, Test-ConflictResolved
