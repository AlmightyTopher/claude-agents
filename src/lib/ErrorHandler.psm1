# ErrorHandler Module
# Centralized error handling and reporting

using module ./Logger.psm1

enum ErrorSeverity {
    Low
    Medium
    High
    Critical
}

enum ErrorCategory {
    Network
    Git
    Validation
    FileSystem
    Configuration
    Authentication
    Conflict
    Unknown
}

class AgentSyncError {
    [string]$ErrorId
    [datetime]$Timestamp
    [ErrorCategory]$Category
    [ErrorSeverity]$Severity
    [string]$Message
    [string]$DetailedMessage
    [hashtable]$Context
    [string]$StackTrace
    [string]$Resolution
    [int]$ExitCode

    AgentSyncError([ErrorCategory]$category, [ErrorSeverity]$severity, [string]$message) {
        $this.ErrorId = [guid]::NewGuid().ToString()
        $this.Timestamp = Get-Date
        $this.Category = $category
        $this.Severity = $severity
        $this.Message = $message
        $this.Context = @{}
        $this.ExitCode = $this.DetermineExitCode()
    }

    [int] DetermineExitCode() {
        switch ($this.Category) {
            ([ErrorCategory]::Conflict) { return 1 }
            ([ErrorCategory]::Validation) { return 2 }
            ([ErrorCategory]::Network) { return 3 }
            ([ErrorCategory]::Authentication) { return 4 }
            ([ErrorCategory]::Git) { return 6 }
            ([ErrorCategory]::FileSystem) { return 7 }
            ([ErrorCategory]::Configuration) { return 8 }
            default { return 5 }
        }
    }

    [void] SetContext([hashtable]$context) {
        $this.Context = $context
    }

    [void] SetStackTrace([string]$stackTrace) {
        $this.StackTrace = $stackTrace
    }

    [void] SetResolution([string]$resolution) {
        $this.Resolution = $resolution
    }

    [void] SetDetailedMessage([string]$detailedMessage) {
        $this.DetailedMessage = $detailedMessage
    }

    [hashtable] ToHashtable() {
        return @{
            ErrorId = $this.ErrorId
            Timestamp = $this.Timestamp.ToString('o')
            Category = $this.Category.ToString()
            Severity = $this.Severity.ToString()
            Message = $this.Message
            DetailedMessage = $this.DetailedMessage
            Context = $this.Context
            StackTrace = $this.StackTrace
            Resolution = $this.Resolution
            ExitCode = $this.ExitCode
        }
    }
}

function New-AgentSyncError {
    <#
    .SYNOPSIS
    Creates a new AgentSyncError object.

    .DESCRIPTION
    Creates a structured error object with categorization, severity, and context.

    .PARAMETER Category
    Error category (Network, Git, Validation, etc.).

    .PARAMETER Severity
    Error severity (Low, Medium, High, Critical).

    .PARAMETER Message
    Short error message.

    .PARAMETER DetailedMessage
    Detailed error explanation.

    .PARAMETER Context
    Additional context information (hashtable).

    .PARAMETER Exception
    Original exception object (for stack trace).

    .PARAMETER Resolution
    Suggested resolution steps.

    .EXAMPLE
    $error = New-AgentSyncError -Category Network -Severity High `
                                 -Message "Failed to connect to GitHub" `
                                 -Resolution "Check internet connection and try again"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ErrorCategory]$Category,

        [Parameter(Mandatory)]
        [ErrorSeverity]$Severity,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$DetailedMessage,
        [hashtable]$Context = @{},
        [System.Management.Automation.ErrorRecord]$Exception,
        [string]$Resolution
    )

    $error = [AgentSyncError]::new($Category, $Severity, $Message)

    if ($DetailedMessage) {
        $error.SetDetailedMessage($DetailedMessage)
    }

    if ($Context.Count -gt 0) {
        $error.SetContext($Context)
    }

    if ($Exception) {
        $error.SetStackTrace($Exception.ScriptStackTrace)
        if (-not $DetailedMessage) {
            $error.SetDetailedMessage($Exception.Exception.Message)
        }
    }

    if ($Resolution) {
        $error.SetResolution($Resolution)
    }

    return $error
}

function Invoke-WithErrorHandling {
    <#
    .SYNOPSIS
    Executes a scriptblock with comprehensive error handling.

    .DESCRIPTION
    Wraps code execution with try-catch and structured error reporting.
    Automatically logs errors and returns structured results.

    .PARAMETER ScriptBlock
    Code to execute.

    .PARAMETER ErrorCategory
    Category for any errors that occur.

    .PARAMETER ErrorSeverity
    Severity for any errors that occur.

    .PARAMETER Context
    Context information to include in errors.

    .PARAMETER ContinueOnError
    Continue execution even if error occurs (default: false).

    .EXAMPLE
    $result = Invoke-WithErrorHandling -ScriptBlock {
        Invoke-GitPull
    } -ErrorCategory Git -ErrorSeverity High -Context @{ Operation = "Pull" }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [ErrorCategory]$ErrorCategory = [ErrorCategory]::Unknown,
        [ErrorSeverity]$ErrorSeverity = [ErrorSeverity]::Medium,
        [hashtable]$Context = @{},
        [switch]$ContinueOnError
    )

    try {
        $result = & $ScriptBlock

        return @{
            Success = $true
            Result = $result
            Error = $null
        }
    }
    catch {
        $error = New-AgentSyncError -Category $ErrorCategory `
                                     -Severity $ErrorSeverity `
                                     -Message "Operation failed" `
                                     -Exception $_ `
                                     -Context $Context

        # Log error
        Write-SyncLog -Message $error.Message `
                      -Level Error `
                      -Category $error.Category.ToString() `
                      -Metadata $error.Context

        # Display error to user
        Show-ErrorMessage -Error $error

        if (-not $ContinueOnError) {
            exit $error.ExitCode
        }

        return @{
            Success = $false
            Result = $null
            Error = $error
        }
    }
}

function Show-ErrorMessage {
    <#
    .SYNOPSIS
    Displays a formatted error message to the user.

    .DESCRIPTION
    Shows error information with color-coding and resolution guidance.

    .PARAMETER Error
    AgentSyncError object to display.

    .EXAMPLE
    Show-ErrorMessage -Error $error
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AgentSyncError]$Error
    )

    # Choose color based on severity
    $severityColor = switch ($Error.Severity) {
        ([ErrorSeverity]::Low) { "Yellow" }
        ([ErrorSeverity]::Medium) { "Yellow" }
        ([ErrorSeverity]::High) { "Red" }
        ([ErrorSeverity]::Critical) { "Red" }
    }

    $severitySymbol = switch ($Error.Severity) {
        ([ErrorSeverity]::Low) { "⚠" }
        ([ErrorSeverity]::Medium) { "⚠" }
        ([ErrorSeverity]::High) { "✗" }
        ([ErrorSeverity]::Critical) { "✗✗" }
    }

    Write-Host ""
    Write-Host "$severitySymbol Error: $($Error.Message)" -ForegroundColor $severityColor
    Write-Host "  Category: $($Error.Category)" -ForegroundColor Gray
    Write-Host "  Severity: $($Error.Severity)" -ForegroundColor Gray

    if ($Error.DetailedMessage) {
        Write-Host "  Details: $($Error.DetailedMessage)" -ForegroundColor Gray
    }

    if ($Error.Context.Count -gt 0) {
        Write-Host "  Context:" -ForegroundColor Gray
        foreach ($key in $Error.Context.Keys) {
            Write-Host "    - $key: $($Error.Context[$key])" -ForegroundColor DarkGray
        }
    }

    if ($Error.Resolution) {
        Write-Host ""
        Write-Host "Resolution:" -ForegroundColor Cyan
        Write-Host "  $($Error.Resolution)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Error ID: $($Error.ErrorId)" -ForegroundColor DarkGray
    Write-Host "Exit Code: $($Error.ExitCode)" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-CommonResolution {
    <#
    .SYNOPSIS
    Gets common resolution steps for error categories.

    .DESCRIPTION
    Returns suggested resolution steps based on error category.

    .PARAMETER Category
    Error category.

    .EXAMPLE
    $resolution = Get-CommonResolution -Category Network
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ErrorCategory]$Category
    )

    $resolutions = @{
        Network = "Check your internet connection. Verify GitHub (github.com) is accessible. Check firewall settings."
        Git = "Ensure Git is installed and configured. Check repository status with 'git status'. Verify remote is configured correctly."
        Validation = "Review file content for syntax errors. Check for hardcoded credentials. Ensure file encoding is UTF-8."
        FileSystem = "Verify file and directory permissions. Check disk space. Ensure paths are correct."
        Configuration = "Review AgentSync configuration. Check .env file for required variables. Verify module dependencies are installed."
        Authentication = "Check GitHub authentication credentials. Verify SSH keys or personal access token. Try re-authenticating with 'gh auth login'."
        Conflict = "Run 'Resolve-SyncConflict' for guidance. Review conflicting changes. Choose appropriate resolution strategy."
        Unknown = "Check logs for details. Run 'Get-SyncLogs -Last 20' to review recent operations. Contact support if issue persists."
    }

    return $resolutions[$Category.ToString()]
}

function Test-ErrorRecoverable {
    <#
    .SYNOPSIS
    Tests if an error is recoverable through retry.

    .DESCRIPTION
    Determines if the error condition might resolve with a retry attempt.

    .PARAMETER Error
    AgentSyncError object to test.

    .EXAMPLE
    if (Test-ErrorRecoverable -Error $error) {
        # Retry logic
    }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AgentSyncError]$Error
    )

    # Network errors are typically transient
    if ($Error.Category -eq [ErrorCategory]::Network) {
        return $true
    }

    # Some Git errors can be retried (not conflicts or validation)
    if ($Error.Category -eq [ErrorCategory]::Git -and
        $Error.Message -notmatch "conflict|merge") {
        return $true
    }

    # Authentication issues might resolve after re-auth
    if ($Error.Category -eq [ErrorCategory]::Authentication) {
        return $true
    }

    return $false
}

function Write-ErrorReport {
    <#
    .SYNOPSIS
    Writes a detailed error report to file.

    .DESCRIPTION
    Creates a JSON error report file for diagnostics and support.

    .PARAMETER Error
    AgentSyncError object to report.

    .PARAMETER OutputPath
    Directory for error reports (default: logs/errors/).

    .EXAMPLE
    Write-ErrorReport -Error $error
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AgentSyncError]$Error,

        [string]$OutputPath = "logs/errors"
    )

    try {
        # Ensure directory exists
        if (-not (Test-Path $OutputPath)) {
            New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        }

        # Generate report filename
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $reportFile = Join-Path $OutputPath "error-$timestamp-$($Error.ErrorId.Substring(0,8)).json"

        # Write report
        $Error.ToHashtable() | ConvertTo-Json -Depth 10 | Set-Content $reportFile -Encoding UTF8

        Write-Verbose "Error report written: $reportFile"
    }
    catch {
        Write-Warning "Failed to write error report: $($_.Exception.Message)"
    }
}

# Export functions
Export-ModuleMember -Function New-AgentSyncError, Invoke-WithErrorHandling, Show-ErrorMessage, `
                              Get-CommonResolution, Test-ErrorRecoverable, Write-ErrorReport
