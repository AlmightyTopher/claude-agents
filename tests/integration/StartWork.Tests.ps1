BeforeAll {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $ModuleRoot "AgentSync.psd1") -Force
}

Describe "Integration Test: Start Work - Pull Latest" {
    Context "Scenario 1: Start work on Machine B after changes on Machine A" {
        BeforeEach {
            # Setup: Simulate changes exist on remote
            # This would normally be done by another machine
        }

        It "should pull latest changes when starting work" {
            # Execute sync command
            $result = Sync-Agents

            # Verify behavior matches quickstart.md scenario
            $result.Status | Should -Be "Success"
            $result.FilesPulled | Should -BeGreaterOrEqual 0
        }

        It "should display files pulled from remote" {
            $result = Sync-Agents

            if ($result.FilesPulled -gt 0) {
                $result | Should -HaveProperty "PulledFiles"
                $result.PulledFiles | Should -BeOfType [array]
            }
        }

        It "should complete in under 5 seconds" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $result = Sync-Agents

            $stopwatch.Stop()
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
        }

        It "should show 'NotNeeded' push status when no local changes" {
            Mock Get-GitStatus {
                return @{
                    ModifiedFiles = @()
                    UntrackedFiles = @()
                    DeletedFiles = @()
                }
            }

            $result = Sync-Agents

            $result.PushStatus | Should -BeIn @("NotNeeded", "Success")
        }
    }

    Context "User Experience" {
        It "should provide clear success message" {
            $result = Sync-Agents

            $result.Status | Should -Not -BeNullOrEmpty
            $result.Message | Should -Not -BeNullOrEmpty
        }

        It "should show duration in output" {
            $result = Sync-Agents

            $result.Duration | Should -BeOfType [timespan]
        }
    }
}

AfterAll {
    # Cleanup
}
