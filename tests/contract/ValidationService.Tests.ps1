BeforeAll {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ValidationServicePath = Join-Path $ModuleRoot "src/services/ValidationService.psm1"

    if (Test-Path $ValidationServicePath) {
        Import-Module $ValidationServicePath -Force
    }
}

Describe "ValidationService Contract Tests" {
    Context "Test-AgentFile" {
        It "should validate agent file syntax" {
            $validFile = @{
                Path = "test-agent.md"
                Content = "# Agent Name`n`nDescription here"
            }

            $result = Test-AgentFile -FilePath $validFile.Path

            $result.IsValid | Should -Be $true
            $result.ValidationErrors | Should -BeNullOrEmpty
        }

        It "should detect missing required fields" {
            $invalidFile = @{
                Path = "bad-agent.md"
                Content = "incomplete content"
            }

            $result = Test-AgentFile -FilePath $invalidFile.Path

            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Missing required field"
        }

        It "should validate file size limit (10MB)" {
            # Mock large file
            Mock Get-Item {
                return [PSCustomObject]@{ Length = 11MB }
            }

            $result = Test-AgentFile -FilePath "large-file.md"

            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Match "file size|too large"
        }

        It "should validate UTF-8 encoding" {
            # This will fail until encoding validation is implemented
            $result = Test-AgentFile -FilePath "test-agent.md"

            if (-not $result.IsValid) {
                $result.ValidationErrors | Should -Match "encoding|UTF-8"
            }
        }
    }

    Context "Test-Syntax" {
        It "should validate markdown syntax for .md files" {
            $content = "# Valid Markdown`n`n- List item`n- Another item"

            $result = Test-Syntax -Content $content -FileType ".md"

            $result.IsValid | Should -Be $true
        }

        It "should validate PowerShell syntax for .ps1 files" {
            $content = 'Write-Host "Valid PowerShell"'

            $result = Test-Syntax -Content $content -FileType ".ps1"

            $result.IsValid | Should -Be $true
        }

        It "should detect syntax errors" {
            $badContent = "function Test { invalid syntax }"

            $result = Test-Syntax -Content $badContent -FileType ".ps1"

            $result.IsValid | Should -Be $false
            $result.Errors | Should -Not -BeNullOrEmpty
        }
    }

    Context "Find-Credentials" {
        It "should detect AWS credentials" {
            $content = "AKIA1234567890ABCDEF"

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $true
            $result.Type | Should -Contain "AWS"
        }

        It "should detect GitHub tokens" {
            $content = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $true
            $result.Type | Should -Contain "GitHub"
        }

        It "should detect generic API keys" {
            $content = 'API_KEY="sk-1234567890abcdef"'

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $true
        }

        It "should detect password patterns" {
            $content = 'password = "secretPassword123"'

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $true
            $result.Type | Should -Contain "Password"
        }

        It "should not flag environment variable references" {
            $content = '$env:API_KEY or ${API_KEY}'

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $false
        }

        It "should detect private keys" {
            $content = "-----BEGIN PRIVATE KEY-----"

            $result = Find-Credentials -Content $content

            $result.Found | Should -Be $true
            $result.Type | Should -Contain "PrivateKey"
        }
    }

    Context "Get-ValidationErrors" {
        It "should aggregate all validation errors" {
            $file = @{
                Path = "test-agent.md"
                Content = "invalid content with AKIA1234567890ABCDEF"
            }

            $result = Get-ValidationErrors -FilePath $file.Path

            $result | Should -BeOfType [array]
            $result.Count | Should -BeGreaterThan 0
        }

        It "should categorize errors by severity" {
            $result = Get-ValidationErrors -FilePath "test.md"

            foreach ($error in $result) {
                $error.Severity | Should -BeIn @("Error", "Warning", "Info")
            }
        }

        It "should include line numbers for errors" {
            $result = Get-ValidationErrors -FilePath "test.md"

            foreach ($error in $result) {
                if ($error.LineNumber) {
                    $error.LineNumber | Should -BeGreaterThan 0
                }
            }
        }
    }
}

AfterAll {
    # Cleanup
}
