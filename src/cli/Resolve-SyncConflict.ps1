# Resolve-SyncConflict Command
# Merge conflict detection and resolution guidance

using module ../services/ConflictService.psm1
using module ../models/Conflict.psm1

function Resolve-SyncConflict {
    <#
    .SYNOPSIS
    Resolves merge conflicts in agent files.

    .DESCRIPTION
    Provides conflict resolution capabilities:
    - Lists all current conflicts
    - Displays resolution guidance for specific files
    - Executes auto-resolution strategies (KeepLocal, KeepRemote)
    - Validates that conflicts are properly resolved

    .PARAMETER FilePath
    Specific file to resolve (optional - if not provided, lists all conflicts).

    .PARAMETER Strategy
    Resolution strategy to use:
    - Manual: Display step-by-step instructions for manual resolution
    - KeepLocal: Keep your local changes, discard remote changes
    - KeepRemote: Discard your local changes, accept remote changes
    - Merge: Attempt to combine both changes (manual guidance)
    - Rebase: Rebase local commits on top of remote (manual guidance)

    .PARAMETER AutoResolve
    Automatically resolve using specified strategy (only works with KeepLocal/KeepRemote).

    .EXAMPLE
    Resolve-SyncConflict
    # List all current conflicts

    .EXAMPLE
    Resolve-SyncConflict -FilePath agents/my-agent.md -Strategy Manual
    # Get manual resolution instructions for specific file

    .EXAMPLE
    Resolve-SyncConflict -FilePath agents/my-agent.md -Strategy KeepLocal -AutoResolve
    # Automatically resolve by keeping local version

    .EXAMPLE
    Resolve-SyncConflict -FilePath agents/my-agent.md -Strategy KeepRemote -AutoResolve
    # Automatically resolve by accepting remote version

    .OUTPUTS
    PSCustomObject with resolution status, strategy used, and instructions.
    #>

    [CmdletBinding()]
    param(
        [string]$FilePath,

        [ValidateSet("Manual", "KeepLocal", "KeepRemote", "Merge", "Rebase")]
        [string]$Strategy = "Manual",

        [switch]$AutoResolve
    )

    begin {
        Write-Verbose "Starting Resolve-SyncConflict command..."
    }

    process {
        try {
            # Get all conflicts
            $conflicts = Get-Conflicts

            if ($conflicts.Count -eq 0) {
                Write-Host "✓ No conflicts detected!" -ForegroundColor Green
                Write-Host "  All files are in sync." -ForegroundColor Gray
                Write-Host ""
                Write-Host "Run Sync-Agents to commit and push any pending changes." -ForegroundColor Cyan
                return [PSCustomObject]@{
                    Status = "NoConflicts"
                    Message = "No conflicts detected"
                }
            }

            # If no file specified, list all conflicts
            if (-not $FilePath) {
                Write-Host ""
                Write-Host "Merge Conflicts Detected" -ForegroundColor Red
                Write-Host "========================" -ForegroundColor Red
                Write-Host ""
                Write-Host "The following files have conflicts:" -ForegroundColor Yellow
                Write-Host ""

                foreach ($conflict in $conflicts) {
                    $icon = if ($conflict.CanAutoResolve()) { "⚡" } else { "⚠" }
                    $color = if ($conflict.CanAutoResolve()) { "Yellow" } else { "Red" }

                    Write-Host "  $icon $($conflict.FilePath)" -ForegroundColor $color

                    if ($conflict.CanAutoResolve()) {
                        Write-Host "     Auto-resolvable (whitespace or simple changes)" -ForegroundColor Gray
                    }
                }

                Write-Host ""
                Write-Host "Resolution Options:" -ForegroundColor Cyan
                Write-Host "  1. Resolve specific file:" -ForegroundColor Gray
                Write-Host "     Resolve-SyncConflict -FilePath <file> -Strategy <strategy>" -ForegroundColor White
                Write-Host ""
                Write-Host "  2. Quick resolution:" -ForegroundColor Gray
                Write-Host "     Resolve-SyncConflict -FilePath <file> -Strategy KeepLocal -AutoResolve" -ForegroundColor White
                Write-Host "     Resolve-SyncConflict -FilePath <file> -Strategy KeepRemote -AutoResolve" -ForegroundColor White
                Write-Host ""

                return [PSCustomObject]@{
                    Status = "ConflictsFound"
                    ConflictCount = $conflicts.Count
                    ConflictingFiles = $conflicts | ForEach-Object { $_.FilePath }
                }
            }

            # Find specific conflict
            $conflict = $conflicts | Where-Object { $_.FilePath -eq $FilePath }

            if (-not $conflict) {
                Write-Host "✗ File not in conflict: $FilePath" -ForegroundColor Red
                Write-Host "  This file is not currently in a merge conflict state." -ForegroundColor Gray
                Write-Host ""
                Write-Host "Run: Resolve-SyncConflict (without parameters) to see all conflicts" -ForegroundColor Cyan
                return [PSCustomObject]@{
                    Status = "NotInConflict"
                    FilePath = $FilePath
                }
            }

            # Convert strategy string to enum
            $strategyEnum = [ResolutionStrategy]::$Strategy

            # Auto-resolve if requested
            if ($AutoResolve) {
                if ($strategyEnum -notin @([ResolutionStrategy]::KeepLocal, [ResolutionStrategy]::KeepRemote)) {
                    Write-Host "✗ Cannot auto-resolve with strategy: $Strategy" -ForegroundColor Red
                    Write-Host "  Auto-resolve only works with KeepLocal or KeepRemote strategies." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Use -Strategy Manual to get step-by-step instructions." -ForegroundColor Cyan
                    exit 1
                }

                Write-Host ""
                Write-Host "Auto-Resolving Conflict" -ForegroundColor Cyan
                Write-Host "=======================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "File:     $FilePath" -ForegroundColor Gray
                Write-Host "Strategy: $Strategy" -ForegroundColor Gray
                Write-Host ""

                $result = Resolve-ConflictAuto -FilePath $FilePath -Strategy $strategyEnum

                if ($result.Success) {
                    Write-Host "✓ Conflict resolved successfully!" -ForegroundColor Green
                    Write-Host "  $($result.Message)" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Next Steps:" -ForegroundColor Cyan
                    Write-Host "  1. Verify the file looks correct" -ForegroundColor Gray
                    Write-Host "  2. Run: Sync-Agents to complete the merge" -ForegroundColor White
                    Write-Host ""

                    return [PSCustomObject]@{
                        Status = "Resolved"
                        FilePath = $FilePath
                        Strategy = $Strategy
                        Message = $result.Message
                    }
                }
                else {
                    Write-Host "✗ Auto-resolution failed!" -ForegroundColor Red
                    Write-Host "  $($result.Message)" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Try manual resolution:" -ForegroundColor Yellow
                    Write-Host "  Resolve-SyncConflict -FilePath '$FilePath' -Strategy Manual" -ForegroundColor White
                    exit 2
                }
            }

            # Provide resolution guidance
            $guidance = Get-ResolutionGuidance -FilePath $FilePath -Strategy $strategyEnum

            Write-Host ""
            Write-Host "Conflict Resolution Guidance" -ForegroundColor Cyan
            Write-Host "============================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "File:     $FilePath" -ForegroundColor Gray
            Write-Host "Strategy: $Strategy" -ForegroundColor Gray
            Write-Host ""

            # Display conflict details
            if ($conflict.LocalChanges -or $conflict.RemoteChanges) {
                Write-Host "Conflict Details:" -ForegroundColor Yellow
                Write-Host ""

                Write-Host "  LOCAL CHANGES (your version):" -ForegroundColor Cyan
                if ($conflict.LocalChanges) {
                    $conflict.LocalChanges -split "`n" | Select-Object -First 5 | ForEach-Object {
                        Write-Host "    $_" -ForegroundColor Gray
                    }
                    if (($conflict.LocalChanges -split "`n").Count -gt 5) {
                        Write-Host "    ... ($($conflict.LocalChanges -split "`n" | Measure-Object).Count lines total)" -ForegroundColor DarkGray
                    }
                }
                else {
                    Write-Host "    (empty or deleted)" -ForegroundColor DarkGray
                }
                Write-Host ""

                Write-Host "  REMOTE CHANGES (incoming version):" -ForegroundColor Magenta
                if ($conflict.RemoteChanges) {
                    $conflict.RemoteChanges -split "`n" | Select-Object -First 5 | ForEach-Object {
                        Write-Host "    $_" -ForegroundColor Gray
                    }
                    if (($conflict.RemoteChanges -split "`n").Count -gt 5) {
                        Write-Host "    ... ($($conflict.RemoteChanges -split "`n" | Measure-Object).Count lines total)" -ForegroundColor DarkGray
                    }
                }
                else {
                    Write-Host "    (empty or deleted)" -ForegroundColor DarkGray
                }
                Write-Host ""
            }

            # Display auto-resolve suggestion if applicable
            if ($conflict.CanAutoResolve()) {
                $suggestedStrategy = $conflict.GetSuggestedStrategy()
                Write-Host "⚡ This conflict can be auto-resolved!" -ForegroundColor Yellow
                Write-Host "   Suggested strategy: $suggestedStrategy" -ForegroundColor Gray
                Write-Host ""
            }

            # Display instructions
            Write-Host "Resolution Instructions:" -ForegroundColor Cyan
            foreach ($instruction in $guidance.Instructions) {
                Write-Host "  $instruction" -ForegroundColor Gray
            }
            Write-Host ""

            # Display conflict markers reference
            if ($strategyEnum -eq [ResolutionStrategy]::Manual) {
                Write-Host "Conflict Markers:" -ForegroundColor Yellow
                Write-Host "  $($guidance.ConflictMarkers.Start)  <- Your local changes start here" -ForegroundColor Cyan
                Write-Host "  $($guidance.ConflictMarkers.Divider)       <- Divider between versions" -ForegroundColor Gray
                Write-Host "  $($guidance.ConflictMarkers.End) <- Remote changes end here" -ForegroundColor Magenta
                Write-Host ""
            }

            return [PSCustomObject]@{
                Status = "GuidanceProvided"
                FilePath = $FilePath
                Strategy = $Strategy
                CanAutoResolve = $conflict.CanAutoResolve()
                Instructions = $guidance.Instructions
            }
        }
        catch {
            Write-Host "✗ Error during conflict resolution!" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            Write-Error $_.Exception
            exit 5
        }
    }

    end {
        Write-Verbose "Resolve-SyncConflict command completed."
    }
}

# Make function available when script is dot-sourced
Export-ModuleMember -Function Resolve-SyncConflict
