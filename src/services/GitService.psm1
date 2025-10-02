# GitService
# Git operations: pull, commit, push, status, network connectivity

using module ../models/SyncOperation.psm1

function Invoke-GitPull {
    [CmdletBinding()]
    param(
        [string]$Branch = "master",
        [string]$Remote = "origin"
    )

    $result = @{
        Success = $false
        FilesPulled = 0
        HasConflicts = $false
        ConflictingFiles = @()
        ErrorMessage = ""
    }

    try {
        # Check network connectivity first
        if (-not (Test-NetworkConnectivity -Host "github.com" -Port 443)) {
            $result.ErrorMessage = "Cannot reach remote repository. Check internet connection."
            return $result
        }

        # Execute git pull
        $output = git pull $Remote $Branch 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            # Parse output for files pulled
            $filesChanged = $output | Select-String "(\d+) file.*changed"
            if ($filesChanged) {
                $result.FilesPulled = [int]($filesChanged.Matches.Groups[1].Value)
            }

            $result.Success = $true
        }
        else {
            # Check for merge conflicts
            if ($output -match "CONFLICT|Merge conflict") {
                $result.HasConflicts = $true

                # Get conflicting files
                $conflictFiles = git diff --name-only --diff-filter=U
                $result.ConflictingFiles = $conflictFiles -split "`n" | Where-Object { $_ }

                $result.ErrorMessage = "Merge conflicts detected in $($result.ConflictingFiles.Count) file(s)"
            }
            else {
                $result.ErrorMessage = $output -join "`n"
            }
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
    }

    return $result
}

function Invoke-GitCommit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateLength(10, 500)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string[]]$Files
    )

    $result = @{
        Success = $false
        CommitHash = ""
        CommitMessage = $Message
        ErrorMessage = ""
    }

    try {
        if ($Files.Count -eq 0) {
            $result.ErrorMessage = "No files to commit"
            return $result
        }

        # Stage files
        foreach ($file in $Files) {
            git add $file 2>&1 | Out-Null
        }

        # Check if anything is staged
        $status = git status --porcelain
        if (-not $status) {
            $result.ErrorMessage = "No changes to commit"
            return $result
        }

        # Create commit
        $output = git commit -m $Message 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            # Get commit hash
            $result.CommitHash = git rev-parse HEAD
            $result.Success = $true
        }
        else {
            $result.ErrorMessage = $output -join "`n"
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
    }

    return $result
}

function Invoke-GitPush {
    [CmdletBinding()]
    param(
        [string]$Branch = "master",
        [string]$Remote = "origin"
    )

    $result = @{
        Success = $false
        CommitsPushed = 0
        ErrorMessage = ""
        ErrorCode = 0
    }

    try {
        # Check if branch is behind remote
        $status = Get-GitStatus
        if ($status.RemoteCommits -gt 0) {
            $result.ErrorMessage = "Local branch is behind remote. Pull first before pushing."
            $result.ErrorCode = 1
            return $result
        }

        # Check network connectivity
        if (-not (Test-NetworkConnectivity -Host "github.com" -Port 443)) {
            $result.ErrorMessage = "Cannot reach remote repository. Check internet connection."
            $result.ErrorCode = 3
            return $result
        }

        # Check authentication
        if (-not (Test-GitAuthentication)) {
            $result.ErrorMessage = "Git authentication failed. Run 'gh auth login' or configure credentials."
            $result.ErrorCode = 4
            return $result
        }

        # Execute git push
        $output = git push $Remote $Branch 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            # Count commits pushed
            $result.CommitsPushed = $status.LocalCommits
            $result.Success = $true
        }
        else {
            $result.ErrorMessage = $output -join "`n"
            $result.ErrorCode = $exitCode
        }
    }
    catch {
        $result.ErrorMessage = $_.Exception.Message
        $result.ErrorCode = 5
    }

    return $result
}

function Get-GitStatus {
    [CmdletBinding()]
    param()

    $result = @{
        ModifiedFiles = @()
        UntrackedFiles = @()
        DeletedFiles = @()
        StagedFiles = @()
        LocalCommits = 0
        RemoteCommits = 0
        BehindRemote = $false
    }

    try {
        # Get porcelain status (machine-readable)
        $statusOutput = git status --porcelain

        if ($statusOutput) {
            foreach ($line in $statusOutput -split "`n") {
                if ($line -match '^\?\? (.+)$') {
                    $result.UntrackedFiles += $matches[1]
                }
                elseif ($line -match '^\s*M (.+)$') {
                    $result.ModifiedFiles += $matches[1]
                }
                elseif ($line -match '^\s*D (.+)$') {
                    $result.DeletedFiles += $matches[1]
                }
                elseif ($line -match '^[MA] (.+)$') {
                    $result.StagedFiles += $matches[1]
                }
            }
        }

        # Get commits ahead/behind
        try {
            git fetch origin --quiet 2>&1 | Out-Null

            $ahead = git rev-list --count origin/master..HEAD 2>$null
            $behind = git rev-list --count HEAD..origin/master 2>$null

            if ($ahead) { $result.LocalCommits = [int]$ahead }
            if ($behind) {
                $result.RemoteCommits = [int]$behind
                $result.BehindRemote = $result.RemoteCommits -gt 0
            }
        }
        catch {
            # Fetch might fail if offline, that's okay
        }
    }
    catch {
        Write-Warning "Error getting Git status: $($_.Exception.Message)"
    }

    return $result
}

function Test-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Host,

        [Parameter(Mandatory)]
        [int]$Port,

        [int]$TimeoutSeconds = 5
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($Host, $Port, $null, $null)
        $waitHandle = $asyncResult.AsyncWaitHandle

        if ($waitHandle.WaitOne($TimeoutSeconds * 1000, $false)) {
            $tcpClient.EndConnect($asyncResult) | Out-Null
            $tcpClient.Close()
            return $true
        }
        else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

function Test-GitAuthentication {
    [CmdletBinding()]
    param()

    try {
        # Try to fetch (doesn't download, just checks connection)
        $output = git ls-remote --heads origin 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Invoke-GitPull, Invoke-GitCommit, Invoke-GitPush, Get-GitStatus, Test-NetworkConnectivity, Test-GitAuthentication
