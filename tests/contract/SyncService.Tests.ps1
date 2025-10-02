BeforeAll {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $SyncServicePath = Join-Path $ModuleRoot "src/services/SyncService.psm1"

    if (Test-Path $SyncServicePath) {
        Import-Module $SyncServicePath -Force
    }
}

Describe "SyncService Contract Tests" {
    Context "Sync-Repository" {
        It "should execute complete sync workflow (pull → validate → commit → push)" {
            $result = Sync-Repository

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -BeIn @("Success", "Conflict", "ValidationFailed", "NetworkError")
        }

        It "should pull latest changes first" {
            Mock Invoke-GitPull { return @{ Success = $true; FilesPulled = 2 } }

            $result = Sync-Repository

            # Verify pull was called
            Should -Invoke Invoke-GitPull -Times 1
        }

        It "should validate files before committing" {
            Mock Test-AgentFile { return @{ IsValid = $false; ValidationErrors = @("Error") } }

            $result = Sync-Repository

            $result.Status | Should -Be "ValidationFailed"
            $result.InvalidFiles | Should -Not -BeNullOrEmpty
        }

        It "should skip commit if no changes detected" {
            Mock Get-GitStatus { return @{ ModifiedFiles = @(); UntrackedFiles = @() } }

            $result = Sync-Repository

            $result.Status | Should -Be "Success"
            $result.CommitHash | Should -BeNullOrEmpty
            $result.Message | Should -Match "no changes"
        }

        It "should generate descriptive commit message" {
            Mock Get-GitStatus {
                return @{
                    ModifiedFiles = @("agent1.md", "agent2.md")
                    UntrackedFiles = @("agent3.md")
                }
            }

            $result = Sync-Repository

            $result.CommitMessage | Should -Match "sync:"
            $result.CommitMessage | Should -Match "\d+ (agent )?files?"
        }

        It "should handle merge conflicts" {
            Mock Invoke-GitPull {
                return @{
                    Success = $false
                    HasConflicts = $true
                    ConflictingFiles = @("agent1.md")
                }
            }

            $result = Sync-Repository

            $result.Status | Should -Be "Conflict"
            $result.ConflictingFiles | Should -Contain "agent1.md"
        }

        It "should handle network failures gracefully" {
            Mock Test-NetworkConnectivity { return $false }

            $result = Sync-Repository

            $result.Status | Should -Be "NetworkError"
            $result.LocalChangesPreserved | Should -Be $true
        }
    }

    Context "Get-SyncStatus" {
        It "should return current sync status" {
            $result = Get-SyncStatus

            $result | Should -Not -BeNullOrEmpty
            $result.LastPullTime | Should -BeOfType [datetime]
            $result.PendingChanges | Should -BeGreaterOrEqual 0
            $result.IsHealthy | Should -BeOfType [bool]
        }

        It "should calculate pending changes count" {
            Mock Get-GitStatus {
                return @{
                    ModifiedFiles = @("file1.md", "file2.md")
                    UntrackedFiles = @("file3.md")
                }
            }

            $result = Get-SyncStatus

            $result.PendingChanges | Should -Be 3
        }

        It "should determine repository health" {
            Mock Get-GitStatus {
                return @{
                    HasConflicts = $false
                    RemoteCommits = 0
                    LocalCommits = 0
                }
            }

            $result = Get-SyncStatus

            $result.IsHealthy | Should -Be $true
        }

        It "should flag unhealthy when conflicts exist" {
            Mock Get-Conflicts {
                return @(
                    @{ FilePath = "agent1.md"; ResolutionStatus = "Unresolved" }
                )
            }

            $result = Get-SyncStatus

            $result.IsHealthy | Should -Be $false
            $result.HasConflicts | Should -Be $true
        }

        It "should warn when behind remote by many commits" {
            Mock Get-GitStatus {
                return @{ RemoteCommits = 15 }
            }

            $result = Get-SyncStatus

            $result.IsHealthy | Should -Be $false
            $result.NextAction | Should -Match "pull|sync"
        }
    }

    Context "Write-SyncLog" {
        It "should log sync operation to JSON file" {
            $operation = @{
                OperationType = "Pull"
                Status = "Success"
                Timestamp = Get-Date
                FilesPulled = 3
            }

            { Write-SyncLog -Operation $operation } | Should -Not -Throw
        }

        It "should create log file if not exists" {
            $logPath = Join-Path $ModuleRoot "logs/sync-$(Get-Date -Format 'yyyy-MM-dd').json"

            Write-SyncLog -Operation @{ OperationType = "Test"; Status = "Success" }

            Test-Path $logPath | Should -Be $true
        }

        It "should append to existing log file" {
            Write-SyncLog -Operation @{ OperationType = "Op1"; Status = "Success" }
            Write-SyncLog -Operation @{ OperationType = "Op2"; Status = "Success" }

            $logPath = Join-Path $ModuleRoot "logs/sync-$(Get-Date -Format 'yyyy-MM-dd').json"
            $logContent = Get-Content $logPath | ConvertFrom-Json

            $logContent.Operations.Count | Should -BeGreaterOrEqual 2
        }

        It "should include session metadata" {
            Write-SyncLog -Operation @{ OperationType = "Test"; Status = "Success" }

            $logPath = Join-Path $ModuleRoot "logs/sync-$(Get-Date -Format 'yyyy-MM-dd').json"
            $logContent = Get-Content $logPath | ConvertFrom-Json

            $logContent.SessionStart | Should -Not -BeNullOrEmpty
            $logContent.LogId | Should -Match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }
    }
}

AfterAll {
    # Cleanup test logs
    $logDir = Join-Path $ModuleRoot "logs"
    if (Test-Path $logDir) {
        Remove-Item "$logDir/sync-*.json" -Force -ErrorAction SilentlyContinue
    }
}
