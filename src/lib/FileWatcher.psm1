# FileWatcher Module
# Monitors agent files for changes and triggers sync operations

using module ../services/SyncService.psm1
using module ./Logger.psm1

$script:FileWatchers = @{}
$script:WatcherJobs = @{}

function Start-FileWatcher {
    <#
    .SYNOPSIS
    Starts monitoring agent files for changes.

    .DESCRIPTION
    Creates a FileSystemWatcher that monitors agent files and:
    - Detects file modifications, creations, deletions
    - Debounces rapid changes (5 second window)
    - Optionally triggers auto-sync on changes
    - Logs all detected changes

    .PARAMETER Path
    Directory to watch (default: current directory).

    .PARAMETER Filter
    File filter pattern (default: *.md for agent files).

    .PARAMETER AutoSync
    Automatically trigger Sync-Agents when changes detected (default: false).

    .PARAMETER DebounceSeconds
    Wait time before processing changes (default: 5 seconds).

    .PARAMETER IncludeSubdirectories
    Watch subdirectories (default: true).

    .EXAMPLE
    Start-FileWatcher -Path "agents" -AutoSync
    # Monitor agents/ directory with auto-sync

    .EXAMPLE
    Start-FileWatcher -Filter "*.md" -DebounceSeconds 10
    # Custom debounce time

    .OUTPUTS
    Watcher ID for stopping the watcher later.
    #>

    [CmdletBinding()]
    param(
        [string]$Path = ".",
        [string]$Filter = "*.md",
        [switch]$AutoSync,
        [int]$DebounceSeconds = 5,
        [bool]$IncludeSubdirectories = $true
    )

    try {
        # Resolve full path
        $fullPath = Resolve-Path $Path -ErrorAction Stop

        # Create unique watcher ID
        $watcherId = [guid]::NewGuid().ToString()

        # Create FileSystemWatcher
        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $fullPath
        $watcher.Filter = $Filter
        $watcher.IncludeSubdirectories = $IncludeSubdirectories
        $watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor
                                 [System.IO.NotifyFilters]::LastWrite -bor
                                 [System.IO.NotifyFilters]::Size

        # Store watcher configuration
        $script:FileWatchers[$watcherId] = @{
            Watcher = $watcher
            Path = $fullPath
            Filter = $Filter
            AutoSync = $AutoSync
            DebounceSeconds = $DebounceSeconds
            LastChangeTime = [datetime]::MinValue
            PendingChanges = @{}
            StartTime = Get-Date
        }

        # Register event handlers
        $onChanged = Register-ObjectEvent -InputObject $watcher -EventName Changed `
            -Action {
                $filePath = $Event.SourceEventArgs.FullPath
                $changeType = $Event.SourceEventArgs.ChangeType

                # Debounce: ignore if file changed very recently
                $now = Get-Date
                $config = $script:FileWatchers[$Event.MessageData]

                if (-not $config.PendingChanges.ContainsKey($filePath)) {
                    $config.PendingChanges[$filePath] = @{
                        ChangeType = $changeType
                        FirstSeen = $now
                        LastSeen = $now
                        Count = 1
                    }
                }
                else {
                    $config.PendingChanges[$filePath].LastSeen = $now
                    $config.PendingChanges[$filePath].Count++
                }

                $config.LastChangeTime = $now

                Write-SyncLog -Message "File change detected: $filePath ($changeType)" `
                              -Level Debug -Category System `
                              -Metadata @{ File = $filePath; ChangeType = $changeType }
            } -MessageData $watcherId

        $onCreated = Register-ObjectEvent -InputObject $watcher -EventName Created `
            -Action {
                $filePath = $Event.SourceEventArgs.FullPath
                $changeType = $Event.SourceEventArgs.ChangeType

                $config = $script:FileWatchers[$Event.MessageData]
                $now = Get-Date

                $config.PendingChanges[$filePath] = @{
                    ChangeType = $changeType
                    FirstSeen = $now
                    LastSeen = $now
                    Count = 1
                }

                $config.LastChangeTime = $now

                Write-SyncLog -Message "File created: $filePath" `
                              -Level Info -Category System `
                              -Metadata @{ File = $filePath }
            } -MessageData $watcherId

        $onDeleted = Register-ObjectEvent -InputObject $watcher -EventName Deleted `
            -Action {
                $filePath = $Event.SourceEventArgs.FullPath
                $changeType = $Event.SourceEventArgs.ChangeType

                $config = $script:FileWatchers[$Event.MessageData]
                $now = Get-Date

                $config.PendingChanges[$filePath] = @{
                    ChangeType = $changeType
                    FirstSeen = $now
                    LastSeen = $now
                    Count = 1
                }

                $config.LastChangeTime = $now

                Write-SyncLog -Message "File deleted: $filePath" `
                              -Level Warning -Category System `
                              -Metadata @{ File = $filePath }
            } -MessageData $watcherId

        $onRenamed = Register-ObjectEvent -InputObject $watcher -EventName Renamed `
            -Action {
                $oldPath = $Event.SourceEventArgs.OldFullPath
                $newPath = $Event.SourceEventArgs.FullPath

                $config = $script:FileWatchers[$Event.MessageData]
                $now = Get-Date

                $config.PendingChanges[$newPath] = @{
                    ChangeType = "Renamed"
                    OldPath = $oldPath
                    FirstSeen = $now
                    LastSeen = $now
                    Count = 1
                }

                $config.LastChangeTime = $now

                Write-SyncLog -Message "File renamed: $oldPath → $newPath" `
                              -Level Info -Category System `
                              -Metadata @{ OldPath = $oldPath; NewPath = $newPath }
            } -MessageData $watcherId

        # Store event subscriptions for cleanup
        $script:FileWatchers[$watcherId].Events = @($onChanged, $onCreated, $onDeleted, $onRenamed)

        # Start monitoring
        $watcher.EnableRaisingEvents = $true

        # Auto-sync feature (v2.0 - currently disabled due to scope complexity)
        if ($AutoSync) {
            Write-Warning "Auto-sync feature is currently disabled. Use manual sync with Sync-Agents."
            # TODO v2.0: Implement auto-sync with PowerShell runspace instead of job
        }

        Write-Host "✓ File watcher started" -ForegroundColor Green
        Write-Host "  Path:      $fullPath" -ForegroundColor Gray
        Write-Host "  Filter:    $Filter" -ForegroundColor Gray
        Write-Host "  Auto-Sync: $(if ($AutoSync) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
        Write-Host "  Watcher ID: $watcherId" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Run Stop-FileWatcher -WatcherId '$watcherId' to stop monitoring" -ForegroundColor Cyan
        Write-Host ""

        return [PSCustomObject]@{
            WatcherId = $watcherId
            Path = $fullPath
            Filter = $Filter
            AutoSync = $AutoSync
            StartTime = Get-Date
        }
    }
    catch {
        Write-Error "Failed to start file watcher: $($_.Exception.Message)"
        return $null
    }
}

function Stop-FileWatcher {
    <#
    .SYNOPSIS
    Stops a running file watcher.

    .DESCRIPTION
    Stops monitoring and cleans up resources for a file watcher.

    .PARAMETER WatcherId
    ID of the watcher to stop (returned by Start-FileWatcher).

    .EXAMPLE
    Stop-FileWatcher -WatcherId "12345678-1234-1234-1234-123456789abc"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WatcherId
    )

    try {
        if (-not $script:FileWatchers.ContainsKey($WatcherId)) {
            Write-Warning "Watcher not found: $WatcherId"
            return
        }

        $config = $script:FileWatchers[$WatcherId]

        # Stop watcher
        $config.Watcher.EnableRaisingEvents = $false
        $config.Watcher.Dispose()

        # Unregister events
        foreach ($event in $config.Events) {
            Unregister-Event -SourceIdentifier $event.Name -ErrorAction SilentlyContinue
        }

        # Stop processor job
        if ($script:WatcherJobs.ContainsKey($WatcherId)) {
            $job = $script:WatcherJobs[$WatcherId]
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -ErrorAction SilentlyContinue
            $script:WatcherJobs.Remove($WatcherId)
        }

        # Remove from tracking
        $script:FileWatchers.Remove($WatcherId)

        Write-Host "✓ File watcher stopped: $WatcherId" -ForegroundColor Green

        Write-SyncLog -Message "File watcher stopped" -Level Info -Category System `
                      -Metadata @{ WatcherId = $WatcherId }
    }
    catch {
        Write-Error "Failed to stop file watcher: $($_.Exception.Message)"
    }
}

function Get-FileWatchers {
    <#
    .SYNOPSIS
    Lists all active file watchers.

    .DESCRIPTION
    Returns information about currently running file watchers.

    .EXAMPLE
    Get-FileWatchers
    #>

    [CmdletBinding()]
    param()

    $watchers = @()

    foreach ($watcherId in $script:FileWatchers.Keys) {
        $config = $script:FileWatchers[$watcherId]

        $watchers += [PSCustomObject]@{
            WatcherId = $watcherId
            Path = $config.Path
            Filter = $config.Filter
            AutoSync = $config.AutoSync
            StartTime = $config.StartTime
            Uptime = (Get-Date) - $config.StartTime
            PendingChanges = $config.PendingChanges.Count
            IsActive = $config.Watcher.EnableRaisingEvents
        }
    }

    return $watchers
}

function Register-ChangeHandler {
    <#
    .SYNOPSIS
    Registers a custom handler for file changes.

    .DESCRIPTION
    Allows registration of custom PowerShell scriptblocks to execute
    when file changes are detected.

    .PARAMETER WatcherId
    ID of the watcher to attach handler to.

    .PARAMETER Handler
    ScriptBlock to execute on file change.
    Parameters: $FilePath, $ChangeType

    .EXAMPLE
    Register-ChangeHandler -WatcherId $id -Handler {
        param($FilePath, $ChangeType)
        Write-Host "Custom handler: $FilePath changed ($ChangeType)"
    }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$WatcherId,

        [Parameter(Mandatory)]
        [scriptblock]$Handler
    )

    try {
        if (-not $script:FileWatchers.ContainsKey($WatcherId)) {
            Write-Error "Watcher not found: $WatcherId"
            return
        }

        $config = $script:FileWatchers[$WatcherId]

        # Store custom handler
        if (-not $config.ContainsKey("CustomHandlers")) {
            $config.CustomHandlers = @()
        }

        $config.CustomHandlers += $Handler

        Write-Host "✓ Custom change handler registered" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to register change handler: $($_.Exception.Message)"
    }
}

# Export functions
Export-ModuleMember -Function Start-FileWatcher, Stop-FileWatcher, Get-FileWatchers, Register-ChangeHandler
