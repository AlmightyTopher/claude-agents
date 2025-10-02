# ValidationService
# File validation, syntax checking, credential scanning

using module ../models/AgentFile.psm1

function Test-AgentFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $result = @{
        IsValid = $false
        ValidationErrors = @()
    }

    try {
        # Create AgentFile object (performs basic validation)
        $agentFile = [AgentFile]::new($FilePath)
        $agentFile.Validate()

        # Perform syntax validation
        $extension = [System.IO.Path]::GetExtension($FilePath)
        $content = Get-Content $FilePath -Raw -Encoding UTF8

        $syntaxResult = Test-Syntax -Content $content -FileType $extension
        if (-not $syntaxResult.IsValid) {
            $result.ValidationErrors += $syntaxResult.Errors
        }

        # Scan for credentials
        $credScanResult = Find-Credentials -Content $content
        if ($credScanResult.Found) {
            $result.ValidationErrors += "Security: Credentials detected ($($credScanResult.Type -join ', '))"
        }

        # Combine validation errors
        $result.ValidationErrors += $agentFile.ValidationErrors

        $result.IsValid = ($result.ValidationErrors.Count -eq 0)
    }
    catch {
        $result.ValidationErrors += "Validation error: $($_.Exception.Message)"
    }

    return $result
}

function Test-Syntax {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$FileType
    )

    $result = @{
        IsValid = $true
        Errors = @()
    }

    try {
        switch ($FileType) {
            ".ps1" {
                # PowerShell syntax validation
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$errors)

                if ($errors) {
                    foreach ($error in $errors) {
                        $result.Errors += "Line $($error.Token.StartLine): $($error.Message)"
                    }
                    $result.IsValid = $false
                }
            }
            ".psm1" {
                # PowerShell module syntax (same as .ps1)
                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($Content, [ref]$errors)

                if ($errors) {
                    foreach ($error in $errors) {
                        $result.Errors += "Line $($error.Token.StartLine): $($error.Message)"
                    }
                    $result.IsValid = $false
                }
            }
            ".md" {
                # Basic markdown validation
                # Check for common issues
                if ($Content -match '^\s*$') {
                    $result.Errors += "File is empty"
                    $result.IsValid = $false
                }

                # Check for unmatched code blocks
                $backtickCount = ($Content | Select-String -Pattern '```' -AllMatches).Matches.Count
                if ($backtickCount % 2 -ne 0) {
                    $result.Errors += "Unmatched code block markers (```)"
                    $result.IsValid = $false
                }
            }
            ".json" {
                # JSON syntax validation
                try {
                    $null = $Content | ConvertFrom-Json -ErrorAction Stop
                }
                catch {
                    $result.Errors += "Invalid JSON: $($_.Exception.Message)"
                    $result.IsValid = $false
                }
            }
            default {
                # Unknown file type - skip syntax validation
            }
        }
    }
    catch {
        $result.Errors += "Syntax check error: $($_.Exception.Message)"
        $result.IsValid = $false
    }

    return $result
}

function Find-Credentials {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $result = @{
        Found = $false
        Type = @()
        Matches = @()
    }

    # Credential patterns
    $patterns = @{
        'AWS' = 'AKIA[0-9A-Z]{16}'
        'GitHub' = 'ghp_[a-zA-Z0-9]{36}'
        'PrivateKey' = '-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----'
        'GenericAPIKey' = '(?i)(api[_-]?key|apikey)\s*[=:]\s*[''"]([a-zA-Z0-9_\-]{20,})[''"]'
        'Password' = '(?i)(password|passwd|pwd)\s*[=:]\s*[''"]([^''"]{8,})[''"]'
        'Token' = '(?i)(token|auth[_-]?token)\s*[=:]\s*[''"]([a-zA-Z0-9_\-\.]{20,})[''"]'
    }

    # Environment variable patterns to EXCLUDE (these are safe)
    $safePatterns = @(
        '\$env:[A-Z_]+',
        '\$\{[A-Z_]+\}',
        'process\.env\.[A-Z_]+',
        '%[A-Z_]+%'
    )

    foreach ($patternName in $patterns.Keys) {
        $pattern = $patterns[$patternName]
        $matches = [regex]::Matches($Content, $pattern)

        if ($matches.Count -gt 0) {
            # Check if matches are environment variable references (safe)
            $realMatches = @()
            foreach ($match in $matches) {
                $isSafe = $false
                foreach ($safePattern in $safePatterns) {
                    if ($match.Value -match $safePattern) {
                        $isSafe = $true
                        break
                    }
                }

                if (-not $isSafe) {
                    $realMatches += $match.Value
                }
            }

            if ($realMatches.Count -gt 0) {
                $result.Found = $true
                $result.Type += $patternName
                $result.Matches += $realMatches
            }
        }
    }

    return $result
}

function Get-ValidationErrors {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $errors = @()

    try {
        # Run comprehensive validation
        $validationResult = Test-AgentFile -FilePath $FilePath

        foreach ($error in $validationResult.ValidationErrors) {
            # Categorize errors by severity
            $severity = "Error"
            if ($error -match "warning|deprecated") {
                $severity = "Warning"
            }
            elseif ($error -match "info|suggestion") {
                $severity = "Info"
            }

            $errors += @{
                FilePath = $FilePath
                Message = $error
                Severity = $severity
                LineNumber = $null  # Could be enhanced to track line numbers
            }
        }
    }
    catch {
        $errors += @{
            FilePath = $FilePath
            Message = "Validation failed: $($_.Exception.Message)"
            Severity = "Error"
            LineNumber = $null
        }
    }

    return $errors
}

# Export functions
Export-ModuleMember -Function Test-AgentFile, Test-Syntax, Find-Credentials, Get-ValidationErrors
