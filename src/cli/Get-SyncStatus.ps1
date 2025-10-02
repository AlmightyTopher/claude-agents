# Get-SyncStatus Command
# Display current synchronization status

using module ../services/SyncService.psm1

function Get-SyncStatus {
    <#
    .SYNOPSIS
    Displays current synchronization status of the agent repository.

    .DESCRIPTION
    Shows:
    - Last pull time
    - Pending changes count
    - Local/remote commit differences
    - Conflict status
    - Repository health
    - Suggested next action

    .PARAMETER Detailed
    Show verbose status including individual file changes.

    .PARAMETER Json
    Output in JSON format for programmatic use.

    .EXAMPLE
    Get-SyncStatus
    # Show quick status

    .EXAMPLE
    Get-SyncStatus -Detailed
    # Show detailed status with file list

    .EXAMPLE
    Get-SyncStatus -Json
    # Output in JSON format

    .OUTPUTS
    PSCustomObject with sync status information.
    #>

    [CmdletBinding()]
    param(
        [switch]$Detailed,
        [switch]$Json
    )

    begin {
        Write-Verbose "Getting sync status..."
    }

    process {
        try {
            # Get status from service (from SyncService module)
            $status = SyncService\Get-SyncStatus

            # JSON output mode
            if ($Json) {
                $jsonOutput = @{
                    lastPullTime = if ($status.LastPullTime -ne [datetime]::MinValue) {
                        $status.LastPullTime.ToString('o')
                    } else { $null }
                    pendingChanges = $status.PendingChanges
                    localCommits = $status.LocalCommits
                    remoteCommits = $status.RemoteCommits
                    hasConflicts = $status.HasConflicts
                    isHealthy = $status.IsHealthy
                    modifiedFiles = $status.ModifiedFiles
                    untrackedFiles = $status.UntrackedFiles
                    deletedFiles = $status.DeletedFiles
                    conflictingFiles = $status.ConflictingFiles
                    nextAction = $status.NextAction
                } | ConvertTo-Json -Depth 10

                Write-Output $jsonOutput
                return
            }

            # Standard output mode
            Write-Host ""
            Write-Host "Sync Status" -ForegroundColor Cyan
            Write-Host "===========" -ForegroundColor Cyan
            Write-Host ""

            # Last pull time
            $lastPullDisplay = if ($status.LastPullTime -eq [datetime]::MinValue) {
                "Never (first time)"
            }
            else {
                $timeAgo = (Get-Date) - $status.LastPullTime
                if ($timeAgo.TotalMinutes -lt 1) {
                    "Just now"
                }
                elseif ($timeAgo.TotalMinutes -lt 60) {
                    "$([math]::Round($timeAgo.TotalMinutes)) minutes ago"
                }
                elseif ($timeAgo.TotalHours -lt 24) {
                    "$([math]::Round($timeAgo.TotalHours)) hours ago"
                }
                else {
                    "$([math]::Round($timeAgo.TotalDays)) days ago"
                }
            }
            Write-Host "Last Pull:        $lastPullDisplay" -ForegroundColor Gray

            # Pending changes
            $changesColor = if ($status.PendingChanges -gt 0) { "Yellow" } else { "Green" }
            $changesText = if ($status.PendingChanges -eq 0) {
                "0 files"
            }
            else {
                $parts = @()
                if ($status.ModifiedFiles.Count -gt 0) {
                    $parts += "$($status.ModifiedFiles.Count) modified"
                }
                if ($status.UntrackedFiles.Count -gt 0) {
                    $parts += "$($status.UntrackedFiles.Count) added"
                }
                if ($status.DeletedFiles.Count -gt 0) {
                    $parts += "$($status.DeletedFiles.Count) deleted"
                }
                "$($status.PendingChanges) files ($($parts -join ', '))"
            }
            Write-Host "Pending Changes:  $changesText" -ForegroundColor $changesColor

            # Local commits
            $localColor = if ($status.LocalCommits -gt 0) { "Yellow" } else { "Green" }
            $localText = if ($status.LocalCommits -eq 0) {
                "0 (in sync)"
            }
            else {
                "$($status.LocalCommits) (ahead of remote)"
            }
            Write-Host "Local Commits:    $localText" -ForegroundColor $localColor

            # Remote commits
            $remoteColor = if ($status.RemoteCommits -gt 0) { "Yellow" } else { "Green" }
            $remoteText = if ($status.RemoteCommits -eq 0) {
                "0 (in sync)"
            }
            else {
                "$($status.RemoteCommits) (behind remote)"
            }
            Write-Host "Remote Commits:   $remoteText" -ForegroundColor $remoteColor

            # Conflicts
            $conflictText = if ($status.HasConflicts) {
                "$($status.ConflictingFiles.Count) conflict(s)"
            }
            else {
                "None"
            }
            $conflictColor = if ($status.HasConflicts) { "Red" } else { "Green" }
            Write-Host "Conflicts:        $conflictText" -ForegroundColor $conflictColor

            # Health
            $healthSymbol = if ($status.IsHealthy) { "✓" } else { "⚠" }
            $healthText = if ($status.IsHealthy) { "Healthy" } else { "Out of sync" }
            $healthColor = if ($status.IsHealthy) { "Green" } else { "Yellow" }
            Write-Host "Health:           $healthSymbol $healthText" -ForegroundColor $healthColor

            # Detailed mode
            if ($Detailed) {
                Write-Host ""
                Write-Host "Detailed Information" -ForegroundColor Cyan
                Write-Host "====================" -ForegroundColor Cyan
                Write-Host ""

                # Modified files
                if ($status.ModifiedFiles.Count -gt 0) {
                    Write-Host "Modified Files:" -ForegroundColor Yellow
                    $status.ModifiedFiles | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Gray
                    }
                    Write-Host ""
                }

                # Untracked files
                if ($status.UntrackedFiles.Count -gt 0) {
                    Write-Host "Untracked Files:" -ForegroundColor Yellow
                    $status.UntrackedFiles | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Gray
                    }
                    Write-Host ""
                }

                # Deleted files
                if ($status.DeletedFiles.Count -gt 0) {
                    Write-Host "Deleted Files:" -ForegroundColor Yellow
                    $status.DeletedFiles | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Gray
                    }
                    Write-Host ""
                }

                # Conflicting files
                if ($status.ConflictingFiles.Count -gt 0) {
                    Write-Host "Conflicting Files:" -ForegroundColor Red
                    $status.ConflictingFiles | ForEach-Object {
                        Write-Host "  - $_" -ForegroundColor Red
                    }
                    Write-Host ""
                }

                # Last sync operations
                $latestLog = Get-LatestSyncLog
                if ($latestLog -and $latestLog.Operations.Count -gt 0) {
                    Write-Host "Last 5 Sync Operations:" -ForegroundColor Cyan
                    $recentOps = $latestLog.Operations | Sort-Object Timestamp -Descending | Select-Object -First 5

                    foreach ($op in $recentOps) {
                        $timeStr = $op.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        $statusSymbol = if ($op.Status -eq "Success") { "✓" } else { "✗" }
                        $statusColor = if ($op.Status -eq "Success") { "Green" } else { "Red" }

                        Write-Host "  $timeStr | " -NoNewline -ForegroundColor Gray
                        Write-Host "$($op.OperationType.ToString().PadRight(7))" -NoNewline -ForegroundColor Cyan
                        Write-Host " | " -NoNewline
                        Write-Host "$statusSymbol $($op.Status)" -NoNewline -ForegroundColor $statusColor

                        if ($op.AffectedFiles.Count -gt 0) {
                            Write-Host " | $($op.AffectedFiles.Count) files" -ForegroundColor Gray
                        }
                        else {
                            Write-Host ""
                        }
                    }
                    Write-Host ""
                }
            }

            # Next action
            Write-Host ""
            $actionColor = if ($status.HasConflicts) { "Red" } elseif ($status.PendingChanges -gt 0 -or $status.RemoteCommits -gt 0) { "Yellow" } else { "Green" }
            Write-Host "Next Action: " -NoNewline
            Write-Host $status.NextAction -ForegroundColor $actionColor
            Write-Host ""

            # Return status object
            return [PSCustomObject]@{
                LastPullTime = $status.LastPullTime
                PendingChanges = $status.PendingChanges
                LocalCommits = $status.LocalCommits
                RemoteCommits = $status.RemoteCommits
                HasConflicts = $status.HasConflicts
                IsHealthy = $status.IsHealthy
                ModifiedFiles = $status.ModifiedFiles
                UntrackedFiles = $status.UntrackedFiles
                DeletedFiles = $status.DeletedFiles
                NextAction = $status.NextAction
            }
        }
        catch {
            Write-Host "✗ Error getting sync status!" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            Write-Error $_.Exception
            exit 1
        }
    }

    end {
        Write-Verbose "Get-SyncStatus command completed."
    }
}

# Make function available when script is dot-sourced
Export-ModuleMember -Function Get-SyncStatus
