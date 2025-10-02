# AgentFile Model
# Represents a single agent specification file in the repository

class AgentFile {
    [string]$FilePath
    [string]$FileName
    [datetime]$LastModified
    [GitStatus]$GitStatus
    [string]$ContentHash
    [bool]$IsValid
    [string[]]$ValidationErrors

    # Constructor
    AgentFile([string]$path) {
        if (-not (Test-Path $path)) {
            throw "File not found: $path"
        }

        $this.FilePath = $path
        $this.FileName = Split-Path $path -Leaf
        $this.LastModified = (Get-Item $path).LastWriteTime
        $this.GitStatus = [GitStatus]::Unknown
        $this.ContentHash = $this.ComputeHash()
        $this.IsValid = $false
        $this.ValidationErrors = @()
    }

    # Compute SHA-256 hash of file contents
    [string] ComputeHash() {
        $content = Get-Content $this.FilePath -Raw -Encoding UTF8
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        return [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    }

    # Check if file has been modified since last hash
    [bool] HasChanged() {
        $currentHash = $this.ComputeHash()
        return $currentHash -ne $this.ContentHash
    }

    # Update hash after changes
    [void] UpdateHash() {
        $this.ContentHash = $this.ComputeHash()
        $this.LastModified = (Get-Item $this.FilePath).LastWriteTime
    }

    # Validate file meets requirements
    [void] Validate() {
        $this.ValidationErrors = @()

        # Check file size (<10MB)
        $fileInfo = Get-Item $this.FilePath
        if ($fileInfo.Length -gt 10MB) {
            $this.ValidationErrors += "File size exceeds 10MB limit"
        }

        # Check file extension
        $extension = [System.IO.Path]::GetExtension($this.FileName)
        $validExtensions = @('.md', '.ps1', '.psm1', '.json')
        if ($extension -notin $validExtensions) {
            $this.ValidationErrors += "Invalid file extension. Must be .md, .ps1, .psm1, or .json"
        }

        # Check UTF-8 encoding
        try {
            $content = Get-Content $this.FilePath -Raw -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            $this.ValidationErrors += "File must be UTF-8 encoded"
        }

        # Check if file is readable
        if (-not (Test-Path $this.FilePath -PathType Leaf)) {
            $this.ValidationErrors += "File path is not a valid file"
        }

        $this.IsValid = ($this.ValidationErrors.Count -eq 0)
    }

    # Get Git status for this file
    [void] UpdateGitStatus([string]$statusOutput) {
        if ($statusOutput -match "^\?\? ") {
            $this.GitStatus = [GitStatus]::Untracked
        }
        elseif ($statusOutput -match "^M ") {
            $this.GitStatus = [GitStatus]::Modified
        }
        elseif ($statusOutput -match "^A ") {
            $this.GitStatus = [GitStatus]::Staged
        }
        elseif ($statusOutput -match "^D ") {
            $this.GitStatus = [GitStatus]::Deleted
        }
        else {
            $this.GitStatus = [GitStatus]::Committed
        }
    }

    # Convert to hashtable for serialization
    [hashtable] ToHashtable() {
        return @{
            FilePath = $this.FilePath
            FileName = $this.FileName
            LastModified = $this.LastModified
            GitStatus = $this.GitStatus.ToString()
            ContentHash = $this.ContentHash
            IsValid = $this.IsValid
            ValidationErrors = $this.ValidationErrors
        }
    }
}

# GitStatus enum
enum GitStatus {
    Unknown
    Untracked
    Modified
    Staged
    Committed
    Deleted
}

# Export the class and enum
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
