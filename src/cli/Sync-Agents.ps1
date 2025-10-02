# Sync-Agents Command
# Main synchronization command: pull, validate, commit, push

using module ../services/SyncService.psm1

function Sync-Agents {
    <#
    .SYNOPSIS
    Synchronizes agent files with remote GitHub repository.

    .DESCRIPTION
    Performs complete sync workflow:
    1. Pulls latest changes from remote
    2. Validates modified agent files
    3. Commits changes with descriptive message
    4. Pushes to remote repository

    .PARAMETER Force
    Skip confirmation prompts for destructive operations (e.g., file deletions).

    .PARAMETER DryRun
    Preview changes without making modifications.

    .PARAMETER Message
    Custom commit message (overrides auto-generated message).

    .PARAMETER Path
    Specific file or directory to sync (default: all agent files).

    .EXAMPLE
    Sync-Agents
    # Sync all changes

    .EXAMPLE
    Sync-Agents -DryRun
    # Preview sync without making changes

    .EXAMPLE
    Sync-Agents -Message "feat: add new agent capabilities"
    # Sync with custom commit message

    .EXAMPLE
    Sync-Agents -Path agents/my-agent.md
    # Sync specific file

    .EXAMPLE
    Sync-Agents -Force
    # Sync without confirmation prompts

    .OUTPUTS
    PSCustomObject with sync results including status, files affected, commit hash, and duration.
    #>

    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$DryRun,
        [string]$Message,
        [string]$Path = "."
    )

    begin {
        Write-Verbose "Starting Sync-Agents command..."

        # Verify we're in a git repository
        if (-not (Test-Path .git)) {
            Write-Error "Not a git repository. Run 'git init' first."
            exit 1
        }

        # Display what we're about to do
        if ($DryRun) {
            Write-Host "[DRY RUN] Previewing sync operations..." -ForegroundColor Cyan
        }
    }

    process {
        try {
            # Check for deletions and prompt if needed
            if (-not $Force -and -not $DryRun) {
                $gitStatus = GitService\Get-GitStatus
                if ($gitStatus.DeletedFiles.Count -gt 0) {
                    Write-Host "The following files will be deleted:" -ForegroundColor Yellow
                    $gitStatus.DeletedFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }

                    $confirm = Read-Host "Are you sure you want to delete these files? [Y/N]"
                    if ($confirm -ne 'Y' -and $confirm -ne 'y') {
                        Write-Host "Sync cancelled." -ForegroundColor Yellow
                        return
                    }
                }
            }

            # Execute sync
            $syncParams = @{
                Path = $Path
                DryRun = $DryRun
            }

            if ($Message) {
                $syncParams.CustomMessage = $Message
            }

            $result = SyncService\Sync-Repository @syncParams

            # Display results based on status
            switch ($result.Status) {
                "Success" {
                    Write-Host "✓ Sync successful!" -ForegroundColor Green
                    Write-Host "  Files pulled: $($result.FilesPulled)" -ForegroundColor Gray
                    Write-Host "  Files modified: $($result.FilesModified)" -ForegroundColor Gray
                    Write-Host "  Files deleted: $($result.FilesDeleted)" -ForegroundColor Gray

                    if ($result.CommitHash) {
                        Write-Host "  Commit: $($result.CommitHash.Substring(0, 7))" -ForegroundColor Gray
                    }

                    Write-Host "  Duration: $([math]::Round($result.Duration.TotalSeconds, 2))s" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host $result.Message -ForegroundColor Green
                }

                "Conflict" {
                    Write-Host "✗ Merge conflicts detected!" -ForegroundColor Red
                    Write-Host "  Conflicting files:" -ForegroundColor Yellow
                    $result.ConflictingFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
                    Write-Host ""
                    Write-Host "Resolution required:" -ForegroundColor Yellow
                    Write-Host "  Run: Resolve-SyncConflict" -ForegroundColor Cyan
                    exit 1
                }

                "ValidationFailed" {
                    Write-Host "✗ Validation errors detected!" -ForegroundColor Red
                    Write-Host "  Invalid files:" -ForegroundColor Yellow

                    foreach ($file in $result.InvalidFiles) {
                        Write-Host "    - $($file.File)" -ForegroundColor Yellow
                        foreach ($error in $file.Errors) {
                            Write-Host "      • $error" -ForegroundColor Red
                        }
                    }

                    Write-Host ""
                    Write-Host "Fix validation errors and retry sync." -ForegroundColor Yellow
                    exit 2
                }

                "NetworkError" {
                    Write-Host "⚠ Network error!" -ForegroundColor Yellow
                    Write-Host "  $($result.Message)" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Local changes have been preserved." -ForegroundColor Green
                    Write-Host "Retry sync when connection is restored." -ForegroundColor Cyan
                    exit 3
                }

                "DryRun" {
                    Write-Host "[DRY RUN] Preview complete" -ForegroundColor Cyan
                    Write-Host "  Would pull from remote" -ForegroundColor Gray

                    if ($result.FilesModified -gt 0 -or $result.FilesDeleted -gt 0) {
                        Write-Host "  Would commit $($result.FilesModified + $result.FilesDeleted) files:" -ForegroundColor Gray

                        $gitStatus = GitService\Get-GitStatus
                        $gitStatus.ModifiedFiles | ForEach-Object { Write-Host "    - $_ (modified)" -ForegroundColor Gray }
                        $gitStatus.UntrackedFiles | ForEach-Object { Write-Host "    - $_ (added)" -ForegroundColor Gray }
                        $gitStatus.DeletedFiles | ForEach-Object { Write-Host "    - $_ (deleted)" -ForegroundColor Gray }

                        Write-Host "  Would push to remote" -ForegroundColor Gray
                    }
                    else {
                        Write-Host "  No changes to commit" -ForegroundColor Gray
                    }

                    Write-Host ""
                    Write-Host "No changes made. Run without -DryRun to execute." -ForegroundColor Cyan
                }

                default {
                    Write-Host "✗ Sync failed!" -ForegroundColor Red
                    Write-Host "  $($result.Message)" -ForegroundColor Red
                    exit 5
                }
            }

            # Return result object
            return [PSCustomObject]@{
                Status = $result.Status
                FilesPulled = $result.FilesPulled
                FilesModified = $result.FilesModified
                FilesDeleted = $result.FilesDeleted
                CommitHash = $result.CommitHash
                PushStatus = $result.PushStatus
                Duration = $result.Duration
                Message = $result.Message
            }
        }
        catch {
            Write-Host "✗ Unexpected error during sync!" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            Write-Error $_.Exception
            exit 5
        }
    }

    end {
        Write-Verbose "Sync-Agents command completed."
    }
}

# Make function available when script is dot-sourced
Export-ModuleMember -Function Sync-Agents
