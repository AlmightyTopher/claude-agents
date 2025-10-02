# SyncOperation Model
# Represents a single synchronization action (pull, commit, push)

class SyncOperation {
    [guid]$OperationId
    [OperationType]$OperationType
    [datetime]$Timestamp
    [OperationStatus]$Status
    [string[]]$AffectedFiles
    [string]$CommitMessage
    [string]$CommitHash
    [string]$ErrorMessage
    [timespan]$Duration

    # Constructor
    SyncOperation([OperationType]$type) {
        $this.OperationId = [guid]::NewGuid()
        $this.OperationType = $type
        $this.Timestamp = Get-Date
        $this.Status = [OperationStatus]::InProgress
        $this.AffectedFiles = @()
        $this.CommitMessage = ""
        $this.CommitHash = ""
        $this.ErrorMessage = ""
        $this.Duration = [timespan]::Zero
    }

    # Start the operation timer
    [System.Diagnostics.Stopwatch] Start() {
        $this.Timestamp = Get-Date
        $this.Status = [OperationStatus]::InProgress
        return [System.Diagnostics.Stopwatch]::StartNew()
    }

    # Complete the operation successfully
    [void] Complete([System.Diagnostics.Stopwatch]$stopwatch) {
        $stopwatch.Stop()
        $this.Duration = $stopwatch.Elapsed
        $this.Status = [OperationStatus]::Success
    }

    # Mark operation as failed
    [void] Fail([string]$errorMessage, [System.Diagnostics.Stopwatch]$stopwatch) {
        if ($stopwatch) {
            $stopwatch.Stop()
            $this.Duration = $stopwatch.Elapsed
        }
        $this.Status = [OperationStatus]::Failed
        $this.ErrorMessage = $errorMessage
    }

    # Skip the operation
    [void] Skip([string]$reason) {
        $this.Status = [OperationStatus]::Skipped
        $this.ErrorMessage = $reason
    }

    # Validate commit message
    [bool] ValidateCommitMessage() {
        if ([string]::IsNullOrWhiteSpace($this.CommitMessage)) {
            return $false
        }

        $length = $this.CommitMessage.Length
        if ($length -lt 10 -or $length -gt 500) {
            return $false
        }

        return $true
    }

    # Validate commit hash format
    [bool] ValidateCommitHash() {
        if ([string]::IsNullOrWhiteSpace($this.CommitHash)) {
            return $true  # Empty hash is valid (not yet committed)
        }

        # SHA-1 hash is 40 hexadecimal characters
        return $this.CommitHash -match '^[0-9a-f]{40}$'
    }

    # Add affected file
    [void] AddAffectedFile([string]$filePath) {
        if ($filePath -notin $this.AffectedFiles) {
            $this.AffectedFiles += $filePath
        }
    }

    # Set commit information
    [void] SetCommitInfo([string]$message, [string]$hash) {
        $this.CommitMessage = $message
        $this.CommitHash = $hash

        if (-not $this.ValidateCommitMessage()) {
            throw "Invalid commit message: must be 10-500 characters"
        }

        if (-not $this.ValidateCommitHash()) {
            throw "Invalid commit hash format: must be 40-character SHA-1 hash"
        }
    }

    # Convert to hashtable for serialization
    [hashtable] ToHashtable() {
        return @{
            OperationId = $this.OperationId.ToString()
            OperationType = $this.OperationType.ToString()
            Timestamp = $this.Timestamp.ToString('o')  # ISO 8601 format
            Status = $this.Status.ToString()
            AffectedFiles = $this.AffectedFiles
            CommitMessage = $this.CommitMessage
            CommitHash = $this.CommitHash
            ErrorMessage = $this.ErrorMessage
            Duration = $this.Duration.ToString()
        }
    }

    # Create from hashtable (deserialization)
    static [SyncOperation] FromHashtable([hashtable]$data) {
        $operation = [SyncOperation]::new([OperationType]$data.OperationType)
        $operation.OperationId = [guid]$data.OperationId
        $operation.Timestamp = [datetime]::Parse($data.Timestamp)
        $operation.Status = [OperationStatus]$data.Status
        $operation.AffectedFiles = $data.AffectedFiles
        $operation.CommitMessage = $data.CommitMessage
        $operation.CommitHash = $data.CommitHash
        $operation.ErrorMessage = $data.ErrorMessage
        $operation.Duration = [timespan]::Parse($data.Duration)
        return $operation
    }
}

# OperationType enum
enum OperationType {
    Pull
    Commit
    Push
    Status
}

# OperationStatus enum
enum OperationStatus {
    InProgress
    Success
    Failed
    Skipped
}

# Export the class and enums
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
