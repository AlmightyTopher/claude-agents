# Logger Module
# Centralized logging for sync operations

function Write-SyncLog {
    <#
    .SYNOPSIS
    Writes a log entry to the sync log file.

    .DESCRIPTION
    Appends a structured log entry to the daily sync log file with:
    - Timestamp
    - Log level (Info, Warning, Error, Debug)
    - Category (Pull, Commit, Push, Validation, Conflict, Status)
    - Message
    - Optional metadata (file paths, operation details)

    .PARAMETER Message
    The log message to write.

    .PARAMETER Level
    Log level: Info, Warning, Error, Debug (default: Info).

    .PARAMETER Category
    Operation category for filtering logs.

    .PARAMETER Metadata
    Additional structured data to include (hashtable).

    .EXAMPLE
    Write-SyncLog -Message "Starting sync operation" -Level Info -Category Status

    .EXAMPLE
    Write-SyncLog -Message "Validation failed" -Level Error -Category Validation -Metadata @{ File = "agent.md" }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info",

        [ValidateSet("Pull", "Commit", "Push", "Validation", "Conflict", "Status", "System")]
        [string]$Category = "System",

        [hashtable]$Metadata = @{}
    )

    try {
        $logDirectory = Get-LogPath
        $logFileName = "sync-$(Get-Date -Format 'yyyy-MM-dd').log"
        $logPath = Join-Path $logDirectory $logFileName

        # Create log directory if needed
        if (-not (Test-Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
        }

        # Build log entry
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $logEntry = [PSCustomObject]@{
            Timestamp = $timestamp
            Level = $Level
            Category = $Category
            Message = $Message
            Metadata = $Metadata
            ProcessId = $PID
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }

        # Format as JSON line
        $jsonLine = $logEntry | ConvertTo-Json -Compress -Depth 10

        # Append to log file
        Add-Content -Path $logPath -Value $jsonLine -Encoding UTF8

        # Trigger log rotation if needed
        $shouldRotate = Test-LogRotationNeeded -LogPath $logPath
        if ($shouldRotate) {
            Rotate-Logs -LogDirectory $logDirectory
        }

        # Output to verbose stream
        Write-Verbose "[$Level] [$Category] $Message"
    }
    catch {
        # Fallback to console if logging fails
        Write-Warning "Failed to write log entry: $($_.Exception.Message)"
        Write-Warning "Original message: $Message"
    }
}

function Get-LogPath {
    <#
    .SYNOPSIS
    Gets the directory path for log files.

    .DESCRIPTION
    Returns the absolute path to the logs directory.
    Creates the directory if it doesn't exist.

    .EXAMPLE
    $logDir = Get-LogPath
    #>

    [CmdletBinding()]
    param()

    # Use repository root/logs directory
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        $logPath = Join-Path $repoRoot "logs"
    }
    else {
        # Fallback to current directory
        $logPath = Join-Path (Get-Location) "logs"
    }

    return $logPath
}

function Rotate-Logs {
    <#
    .SYNOPSIS
    Rotates log files to prevent excessive disk usage.

    .DESCRIPTION
    Implements log rotation strategy:
    - Keeps last 30 days of logs
    - Compresses logs older than 7 days
    - Deletes logs older than 30 days
    - Maximum 100MB total log size

    .PARAMETER LogDirectory
    Directory containing log files (default: Get-LogPath).

    .PARAMETER MaxAgeInDays
    Maximum age of logs to keep (default: 30).

    .PARAMETER CompressionAgeInDays
    Age at which logs are compressed (default: 7).

    .PARAMETER MaxTotalSizeMB
    Maximum total size of all logs in MB (default: 100).

    .EXAMPLE
    Rotate-Logs
    # Use defaults

    .EXAMPLE
    Rotate-Logs -MaxAgeInDays 60 -CompressionAgeInDays 14
    # Custom retention policy
    #>

    [CmdletBinding()]
    param(
        [string]$LogDirectory = (Get-LogPath),
        [int]$MaxAgeInDays = 30,
        [int]$CompressionAgeInDays = 7,
        [int]$MaxTotalSizeMB = 100
    )

    try {
        if (-not (Test-Path $LogDirectory)) {
            return
        }

        $now = Get-Date
        $compressionThreshold = $now.AddDays(-$CompressionAgeInDays)
        $deletionThreshold = $now.AddDays(-$MaxAgeInDays)
        $maxTotalSize = $MaxTotalSizeMB * 1MB

        # Get all log files
        $logFiles = Get-ChildItem -Path $LogDirectory -Filter "sync-*.log" -File
        $compressedLogs = Get-ChildItem -Path $LogDirectory -Filter "sync-*.log.gz" -File
        $allLogs = $logFiles + $compressedLogs

        # Delete old logs
        $deletedCount = 0
        foreach ($log in $allLogs) {
            if ($log.LastWriteTime -lt $deletionThreshold) {
                Remove-Item $log.FullName -Force
                $deletedCount++
                Write-Verbose "Deleted old log: $($log.Name)"
            }
        }

        # Compress old uncompressed logs
        $compressedCount = 0
        foreach ($log in $logFiles) {
            if ($log.LastWriteTime -lt $compressionThreshold) {
                $compressedPath = "$($log.FullName).gz"

                # Simple compression (requires PowerShell 5.0+)
                if ($PSVersionTable.PSVersion.Major -ge 5) {
                    Compress-Archive -Path $log.FullName -DestinationPath $compressedPath -Force
                    Remove-Item $log.FullName -Force
                    $compressedCount++
                    Write-Verbose "Compressed log: $($log.Name)"
                }
            }
        }

        # Check total size and delete oldest if exceeding limit
        $totalSize = ($allLogs | Where-Object { Test-Path $_.FullName } | Measure-Object -Property Length -Sum).Sum
        if ($totalSize -gt $maxTotalSize) {
            $oldestLogs = $allLogs |
                Where-Object { Test-Path $_.FullName } |
                Sort-Object LastWriteTime |
                Select-Object -First 5

            foreach ($log in $oldestLogs) {
                Remove-Item $log.FullName -Force
                $deletedCount++
                Write-Verbose "Deleted log to reduce size: $($log.Name)"

                # Recalculate total size
                $totalSize = (Get-ChildItem -Path $LogDirectory -File | Measure-Object -Property Length -Sum).Sum
                if ($totalSize -le $maxTotalSize) {
                    break
                }
            }
        }

        Write-Verbose "Log rotation complete: $deletedCount deleted, $compressedCount compressed"
    }
    catch {
        Write-Warning "Error during log rotation: $($_.Exception.Message)"
    }
}

function Test-LogRotationNeeded {
    <#
    .SYNOPSIS
    Tests if log rotation is needed for a specific log file.

    .DESCRIPTION
    Checks if the log file exceeds size threshold (10MB by default).

    .PARAMETER LogPath
    Path to the log file to check.

    .PARAMETER MaxSizeMB
    Maximum log file size in MB (default: 10).

    .EXAMPLE
    $needsRotation = Test-LogRotationNeeded -LogPath "logs/sync-2025-10-02.log"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [int]$MaxSizeMB = 10
    )

    try {
        if (-not (Test-Path $LogPath)) {
            return $false
        }

        $file = Get-Item $LogPath
        $maxSize = $MaxSizeMB * 1MB

        return $file.Length -ge $maxSize
    }
    catch {
        return $false
    }
}

function Get-SyncLogs {
    <#
    .SYNOPSIS
    Retrieves sync log entries with optional filtering.

    .DESCRIPTION
    Reads and parses sync log files with filtering options:
    - Date range
    - Log level
    - Category
    - Message pattern

    .PARAMETER StartDate
    Filter logs from this date onward.

    .PARAMETER EndDate
    Filter logs up to this date.

    .PARAMETER Level
    Filter by log level (Info, Warning, Error, Debug).

    .PARAMETER Category
    Filter by operation category.

    .PARAMETER Pattern
    Filter by message content (regex pattern).

    .PARAMETER Last
    Return only the last N entries.

    .EXAMPLE
    Get-SyncLogs -Last 50
    # Get 50 most recent log entries

    .EXAMPLE
    Get-SyncLogs -Level Error -StartDate (Get-Date).AddDays(-7)
    # Get errors from last 7 days

    .EXAMPLE
    Get-SyncLogs -Category Validation -Pattern "failed"
    # Get validation failures

    .OUTPUTS
    Array of log entry objects.
    #>

    [CmdletBinding()]
    param(
        [datetime]$StartDate,
        [datetime]$EndDate,

        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level,

        [ValidateSet("Pull", "Commit", "Push", "Validation", "Conflict", "Status", "System")]
        [string]$Category,

        [string]$Pattern,
        [int]$Last
    )

    try {
        $logDirectory = Get-LogPath
        if (-not (Test-Path $logDirectory)) {
            return @()
        }

        # Get all log files
        $logFiles = Get-ChildItem -Path $logDirectory -Filter "sync-*.log" -File |
            Sort-Object LastWriteTime -Descending

        $allEntries = @()

        foreach ($logFile in $logFiles) {
            # Parse log file (JSON lines format)
            $lines = Get-Content $logFile.FullName
            foreach ($line in $lines) {
                try {
                    $entry = $line | ConvertFrom-Json

                    # Apply filters
                    if ($StartDate -and [datetime]$entry.Timestamp -lt $StartDate) { continue }
                    if ($EndDate -and [datetime]$entry.Timestamp -gt $EndDate) { continue }
                    if ($Level -and $entry.Level -ne $Level) { continue }
                    if ($Category -and $entry.Category -ne $Category) { continue }
                    if ($Pattern -and $entry.Message -notmatch $Pattern) { continue }

                    $allEntries += $entry
                }
                catch {
                    Write-Warning "Failed to parse log line: $line"
                }
            }
        }

        # Sort by timestamp descending
        $allEntries = $allEntries | Sort-Object { [datetime]$_.Timestamp } -Descending

        # Apply Last filter
        if ($Last -gt 0) {
            $allEntries = $allEntries | Select-Object -First $Last
        }

        return $allEntries
    }
    catch {
        Write-Warning "Error reading sync logs: $($_.Exception.Message)"
        return @()
    }
}

function Format-LogOutput {
    <#
    .SYNOPSIS
    Formats log entries for human-readable display.

    .DESCRIPTION
    Formats log entries with colored output and aligned columns.

    .PARAMETER LogEntries
    Array of log entry objects to format.

    .EXAMPLE
    Get-SyncLogs -Last 20 | Format-LogOutput
    #>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$LogEntries
    )

    begin {
        Write-Host ""
        Write-Host "Sync Logs" -ForegroundColor Cyan
        Write-Host "=========" -ForegroundColor Cyan
        Write-Host ""
    }

    process {
        foreach ($entry in $LogEntries) {
            # Choose color based on level
            $levelColor = switch ($entry.Level) {
                "Info" { "Gray" }
                "Warning" { "Yellow" }
                "Error" { "Red" }
                "Debug" { "DarkGray" }
                default { "White" }
            }

            # Format timestamp
            $timestamp = ([datetime]$entry.Timestamp).ToString("yyyy-MM-dd HH:mm:ss")

            # Format output
            Write-Host "$timestamp | " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($entry.Level.PadRight(7))" -NoNewline -ForegroundColor $levelColor
            Write-Host " | " -NoNewline
            Write-Host "$($entry.Category.PadRight(10))" -NoNewline -ForegroundColor Cyan
            Write-Host " | " -NoNewline
            Write-Host $entry.Message -ForegroundColor White

            # Show metadata if present
            if ($entry.Metadata -and $entry.Metadata.PSObject.Properties.Count -gt 0) {
                foreach ($prop in $entry.Metadata.PSObject.Properties) {
                    Write-Host "  ↳ $($prop.Name): $($prop.Value)" -ForegroundColor DarkGray
                }
            }
        }
    }

    end {
        Write-Host ""
    }
}

# Export functions
Export-ModuleMember -Function Write-SyncLog, Get-LogPath, Rotate-Logs, Get-SyncLogs, Format-LogOutput, Test-LogRotationNeeded
