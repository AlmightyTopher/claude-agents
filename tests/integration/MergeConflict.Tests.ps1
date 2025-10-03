BeforeAll {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    Import-Module (Join-Path $ModuleRoot "AgentSync.psd1") -Force
}

Describe "Integration Test: Handle Merge Conflict" {
    Context "Scenario 6: Conflicting changes on two machines" {
        BeforeEach {
            # Setup: Create scenario where local and remote have conflicting changes
            # Machine A modified agent1.md
            # Machine B (local) also modified agent1.md without pulling first
        }

        It "should detect merge conflict during sync" {
            # Simulate conflict scenario
            Mock Invoke-GitPull {
                return @{
                    Success = $false
                    HasConflicts = $true
                    ConflictingFiles = @("agents/agent1.md")
                }
            }

            $result = Sync-Agents

            $result.Status | Should -Be "Conflict"
            $result.ConflictingFiles | Should -Contain "agents/agent1.md"
        }

        It "should block push operation when conflicts exist" {
            Mock Invoke-GitPull {
                return @{
                    Success = $false
                    HasConflicts = $true
                    ConflictingFiles = @("agents/agent1.md")
                }
            }

            $result = Sync-Agents

            $result.PushStatus | Should -BeNullOrEmpty
            $result.Message | Should -Match "conflict|resolve"
        }

        It "should provide guidance message" {
            Mock Invoke-GitPull {
                return @{
                    Success = $false
                    HasConflicts = $true
                    ConflictingFiles = @("agents/agent1.md")
                }
            }

            $result = Sync-Agents

            $result.Message | Should -Match "Resolve-SyncConflict"
            $result.SuggestedAction | Should -Not -BeNullOrEmpty
        }
    }

    Context "Resolve-SyncConflict Command" {
        BeforeEach {
            # Setup conflict scenario
            Mock Get-Conflicts {
                return @(
                    @{
                        FilePath = "agents/agent1.md"
                        LocalChanges = "Added new capabilities section"
                        RemoteChanges = "Updated examples section"
                        CanAutoResolve = $false
                    }
                )
            }
        }

        It "should list all conflicts" {
            $result = Resolve-SyncConflict

            $result.ConflictCount | Should -BeGreaterThan 0
            $result.Conflicts | Should -Not -BeNullOrEmpty
        }

        It "should provide manual resolution guidance" {
            $result = Resolve-SyncConflict -FilePath "agents/agent1.md" -Strategy Manual

            $result.Instructions | Should -Not -BeNullOrEmpty
            $result.Instructions[0] | Should -Match "Open.*editor"
        }

        It "should show conflict markers in guidance" {
            $result = Resolve-SyncConflict -FilePath "agents/agent1.md" -Strategy Manual

            $result.ConflictMarkers.Start | Should -Be "<<<<<<< HEAD"
            $result.ConflictMarkers.Divider | Should -Be "======="
            $result.ConflictMarkers.End | Should -Be ">>>>>>> origin/master"
        }

        It "should suggest strategy based on conflict type" {
            $result = Resolve-SyncConflict

            foreach ($conflict in $result.Conflicts) {
                $conflict.SuggestedStrategy | Should -BeIn @("Manual", "KeepLocal", "KeepRemote", "Merge", "Rebase")
            }
        }
    }

    Context "Auto-Resolution" {
        It "should auto-resolve when strategy is KeepLocal" {
            Mock Get-Conflicts {
                return @(
                    @{
                        FilePath = "agents/agent2.md"
                        CanAutoResolve = $true
                    }
                )
            }

            $result = Resolve-SyncConflict -FilePath "agents/agent2.md" -Strategy KeepLocal -AutoResolve

            $result.Status | Should -Be "Resolved"
            $result.Strategy | Should -Be "KeepLocal"
        }

        It "should fall back to Manual when auto-resolve fails" {
            Mock Get-Conflicts {
                return @(
                    @{
                        FilePath = "agents/agent1.md"
                        CanAutoResolve = $false
                    }
                )
            }

            $result = Resolve-SyncConflict -FilePath "agents/agent1.md" -Strategy Merge -AutoResolve

            $result.Status | Should -Be "Failed"
            $result.FallbackStrategy | Should -Be "Manual"
        }
    }

    Context "Complete Resolution Workflow" {
        It "should allow sync after conflict resolution" {
            # Step 1: Detect conflict
            Mock Invoke-GitPull {
                return @{
                    Success = $false
                    HasConflicts = $true
                    ConflictingFiles = @("agents/agent1.md")
                }
            }

            $syncResult = Sync-Agents
            $syncResult.Status | Should -Be "Conflict"

            # Step 2: Resolve conflict
            Mock Resolve-ConflictAuto { return @{ Success = $true } }

            Resolve-SyncConflict -FilePath "agents/agent1.md" -Strategy KeepLocal -AutoResolve

            # Step 3: Retry sync
            Mock Invoke-GitPull { return @{ Success = $true; HasConflicts = $false } }

            $retrySyncResult = Sync-Agents
            $retrySyncResult.Status | Should -Be "Success"
        }
    }
}

AfterAll {
    # Cleanup
}
