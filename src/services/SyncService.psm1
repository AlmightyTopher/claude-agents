# SyncService
# Main synchronization orchestration

using module ../models/AgentFile.psm1
using module ../models/SyncOperation.psm1
using module ../models/SyncLog.psm1
using module ./GitService.psm1
using module ./ValidationService.psm1
using module ./ConflictService.psm1

function Sync-Repository {
    [CmdletBinding()]
    param(
        [string]$Path = ".",
        [switch]$DryRun,
        [string]$CustomMessage
    )

    $result = @{
        Status = ""
        FilesPulled = 0
        FilesModified = 0
        FilesDeleted = 0
        CommitHash = ""
        PushStatus = ""
        Duration = [timespan]::Zero
        Message = ""
        InvalidFiles = @()
        ConflictingFiles = @()
        LocalChangesPreserved = $false
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $syncLog = [SyncLog]::new()

    try {
        # Step 1: Pull latest changes
        Write-Verbose "Pulling latest changes from remote..."
        $pullOperation = [SyncOperation]::new([OperationType]::Pull)
        $pullTimer = $pullOperation.Start()

        $pullResult = Invoke-GitPull
        $result.FilesPulled = $pullResult.FilesPulled

        if (-not $pullResult.Success) {
            if ($pullResult.HasConflicts) {
                $pullOperation.Fail("Merge conflicts detected", $pullTimer)
                $syncLog.AddOperation($pullOperation)

                $result.Status = "Conflict"
                $result.ConflictingFiles = $pullResult.ConflictingFiles
                $result.Message = "Merge conflicts detected. Run Resolve-SyncConflict for guidance."
                $stopwatch.Stop()
                $result.Duration = $stopwatch.Elapsed
                return $result
            }
            else {
                # Network error or other issue
                $pullOperation.Fail($pullResult.ErrorMessage, $pullTimer)
                $syncLog.AddOperation($pullOperation)

                $result.Status = "NetworkError"
                $result.Message = $pullResult.ErrorMessage
                $result.LocalChangesPreserved = $true
                $stopwatch.Stop()
                $result.Duration = $stopwatch.Elapsed
                return $result
            }
        }

        $pullOperation.Complete($pullTimer)
        $syncLog.AddOperation($pullOperation)

        # Step 2: Get local changes
        Write-Verbose "Checking for local changes..."
        $gitStatus = Get-GitStatus
        $allChangedFiles = $gitStatus.ModifiedFiles + $gitStatus.UntrackedFiles + $gitStatus.DeletedFiles

        if ($allChangedFiles.Count -eq 0) {
            $result.Status = "Success"
            $result.Message = "No changes to sync. Already up to date."
            $result.PushStatus = "NotNeeded"
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            return $result
        }

        $result.FilesModified = $gitStatus.ModifiedFiles.Count + $gitStatus.UntrackedFiles.Count
        $result.FilesDeleted = $gitStatus.DeletedFiles.Count

        # Step 3: Validate changed files
        Write-Verbose "Validating changed files..."
        $invalidFiles = @()

        foreach ($file in ($gitStatus.ModifiedFiles + $gitStatus.UntrackedFiles)) {
            if (Test-Path $file) {
                $validationResult = Test-AgentFile -FilePath $file
                if (-not $validationResult.IsValid) {
                    $invalidFiles += @{
                        File = $file
                        Errors = $validationResult.ValidationErrors
                    }
                }
            }
        }

        if ($invalidFiles.Count -gt 0) {
            $result.Status = "ValidationFailed"
            $result.InvalidFiles = $invalidFiles
            $result.Message = "Fix validation errors before committing"
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            return $result
        }

        if ($DryRun) {
            $result.Status = "DryRun"
            $result.Message = "Dry run complete. No changes made."
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            return $result
        }

        # Step 4: Commit changes
        Write-Verbose "Committing changes..."
        $commitOperation = [SyncOperation]::new([OperationType]::Commit)
        $commitTimer = $commitOperation.Start()

        # Generate commit message
        $commitMessage = if ($CustomMessage) {
            $CustomMessage
        }
        else {
            $fileCount = $allChangedFiles.Count
            $modifiedCount = $gitStatus.ModifiedFiles.Count
            $addedCount = $gitStatus.UntrackedFiles.Count
            $deletedCount = $gitStatus.DeletedFiles.Count

            $parts = @()
            if ($modifiedCount -gt 0) { $parts += "$modifiedCount modified" }
            if ($addedCount -gt 0) { $parts += "$addedCount added" }
            if ($deletedCount -gt 0) { $parts += "$deletedCount deleted" }

            "sync: update $fileCount agent file(s) - " + ($parts -join ", ")
        }

        $commitResult = Invoke-GitCommit -Message $commitMessage -Files $allChangedFiles

        if (-not $commitResult.Success) {
            $commitOperation.Fail($commitResult.ErrorMessage, $commitTimer)
            $syncLog.AddOperation($commitOperation)

            $result.Status = "CommitFailed"
            $result.Message = $commitResult.ErrorMessage
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            return $result
        }

        $commitOperation.SetCommitInfo($commitMessage, $commitResult.CommitHash)
        $commitOperation.Complete($commitTimer)
        $syncLog.AddOperation($commitOperation)

        $result.CommitHash = $commitResult.CommitHash

        # Step 5: Push to remote
        Write-Verbose "Pushing to remote..."
        $pushOperation = [SyncOperation]::new([OperationType]::Push)
        $pushTimer = $pushOperation.Start()

        $pushResult = Invoke-GitPush

        if (-not $pushResult.Success) {
            $pushOperation.Fail($pushResult.ErrorMessage, $pushTimer)
            $syncLog.AddOperation($pushOperation)

            $result.Status = if ($pushResult.ErrorCode -eq 3) { "NetworkError" } else { "PushFailed" }
            $result.Message = $pushResult.ErrorMessage
            $result.PushStatus = "Failed"
            $result.LocalChangesPreserved = $true
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            return $result
        }

        $pushOperation.Complete($pushTimer)
        $syncLog.AddOperation($pushOperation)

        $result.Status = "Success"
        $result.PushStatus = "Success"
        $result.Message = "Successfully synced $($allChangedFiles.Count) file(s)"
    }
    catch {
        $result.Status = "Error"
        $result.Message = "Unexpected error: $($_.Exception.Message)"
    }
    finally {
        $stopwatch.Stop()
        $result.Duration = $stopwatch.Elapsed

        # Write sync log
        $syncLog.EndSession()
        Write-SyncLog -SyncLog $syncLog
    }

    return $result
}

function Get-SyncStatus {
    [CmdletBinding()]
    param()

    $result = @{
        LastPullTime = [datetime]::MinValue
        PendingChanges = 0
        LocalCommits = 0
        RemoteCommits = 0
        HasConflicts = $false
        IsHealthy = $true
        ModifiedFiles = @()
        UntrackedFiles = @()
        DeletedFiles = @()
        ConflictingFiles = @()
        NextAction = ""
    }

    try {
        # Get Git status
        $gitStatus = Get-GitStatus
        $result.ModifiedFiles = $gitStatus.ModifiedFiles
        $result.UntrackedFiles = $gitStatus.UntrackedFiles
        $result.DeletedFiles = $gitStatus.DeletedFiles
        $result.PendingChanges = ($gitStatus.ModifiedFiles + $gitStatus.UntrackedFiles + $gitStatus.DeletedFiles).Count
        $result.LocalCommits = $gitStatus.LocalCommits
        $result.RemoteCommits = $gitStatus.RemoteCommits

        # Check for conflicts
        $conflicts = Get-Conflicts
        if ($conflicts.Count -gt 0) {
            $result.HasConflicts = $true
            $result.ConflictingFiles = $conflicts | ForEach-Object { $_.FilePath }
            $result.IsHealthy = $false
        }

        # Get last pull time from logs
        $latestLog = Get-LatestSyncLog
        if ($latestLog) {
            $pullOps = $latestLog.GetOperationsByType([OperationType]::Pull)
            if ($pullOps.Count -gt 0) {
                $result.LastPullTime = ($pullOps | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp
            }
        }

        # Determine health status
        if ($result.RemoteCommits -gt 10) {
            $result.IsHealthy = $false
        }

        # Suggest next action
        if ($result.HasConflicts) {
            $result.NextAction = "Run Resolve-SyncConflict to fix conflicts"
        }
        elseif ($result.RemoteCommits -gt 0) {
            $result.NextAction = "Run Sync-Agents to pull latest changes"
        }
        elseif ($result.PendingChanges -gt 0) {
            $result.NextAction = "Run Sync-Agents to commit and push changes"
        }
        else {
            $result.NextAction = "All up to date!"
        }
    }
    catch {
        Write-Warning "Error getting sync status: $($_.Exception.Message)"
    }

    return $result
}

function Write-SyncLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SyncLog]$SyncLog,

        [string]$LogDirectory = "logs"
    )

    try {
        # Ensure log directory exists
        if (-not (Test-Path $LogDirectory)) {
            New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
        }

        # Get log file path for today
        $logFileName = "sync-$(Get-Date -Format 'yyyy-MM-dd').json"
        $logPath = Join-Path $LogDirectory $logFileName

        # Load existing log if it exists
        $existingLog = $null
        if (Test-Path $logPath) {
            $content = Get-Content $logPath -Raw | ConvertFrom-Json
            $existingLog = [SyncLog]::FromHashtable($content)
        }

        # Merge with existing log
        if ($existingLog) {
            foreach ($op in $SyncLog.Operations) {
                $existingLog.AddOperation($op)
            }
            $logToWrite = $existingLog
        }
        else {
            $logToWrite = $SyncLog
        }

        # Write to file
        $logToWrite.ToHashtable() | ConvertTo-Json -Depth 10 | Set-Content $logPath -Encoding UTF8
    }
    catch {
        Write-Warning "Error writing sync log: $($_.Exception.Message)"
    }
}

function Get-LatestSyncLog {
    [CmdletBinding()]
    param(
        [string]$LogDirectory = "logs"
    )

    try {
        if (-not (Test-Path $LogDirectory)) {
            return $null
        }

        $latestLog = Get-ChildItem $LogDirectory -Filter "sync-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($latestLog) {
            $content = Get-Content $latestLog.FullName -Raw | ConvertFrom-Json
            return [SyncLog]::FromHashtable($content)
        }
    }
    catch {
        Write-Warning "Error reading sync log: $($_.Exception.Message)"
    }

    return $null
}

# Export functions
Export-ModuleMember -Function Sync-Repository, Get-SyncStatus, Write-SyncLog, Get-LatestSyncLog
