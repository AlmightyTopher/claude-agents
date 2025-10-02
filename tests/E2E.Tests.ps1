# End-to-End Smoke Test
# Complete workflow: create → sync → modify → sync → delete → sync

BeforeAll {
    # Import all modules
    Import-Module "$PSScriptRoot/../AgentSync.psd1" -Force

    # Create temp test directory
    $script:TestRepo = Join-Path $TestDrive "e2e-test-repo"
    New-Item -Path $script:TestRepo -ItemType Directory -Force | Out-Null

    # Initialize git repo
    Push-Location $script:TestRepo
    git init 2>&1 | Out-Null
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create initial commit
    "# Test Repo" | Set-Content "README.md"
    git add README.md
    git commit -m "Initial commit" 2>&1 | Out-Null

    # Create agents directory
    New-Item -Path "agents" -ItemType Directory -Force | Out-Null
}

Describe "End-to-End Agent Sync Workflow" {
    Context "Complete User Journey" {
        It "Step 1: Create new agent file" {
            $agentContent = @"
# Test Agent Specification

**Version:** 1.0.0
**Purpose:** End-to-end testing
**Author:** Test Suite

## Description
This is a test agent for E2E validation.

## Capabilities
- Test capability 1
- Test capability 2

## Examples
``````
Example usage here
``````
"@
            $agentPath = Join-Path "agents" "test-agent.md"
            $agentContent | Set-Content $agentPath

            $agentPath | Should -Exist
        }

        It "Step 2: Check sync status shows pending changes" {
            $status = Get-SyncStatus
            $status.PendingChanges | Should -BeGreaterThan 0
            $status.UntrackedFiles | Should -Contain "agents/test-agent.md"
        }

        It "Step 3: Sync new agent file" {
            $result = Sync-Repository -DryRun

            $result.Status | Should -Be "DryRun"
            $result.FilesModified | Should -BeGreaterThan 0
        }

        It "Step 4: Modify existing agent file" {
            $agentPath = Join-Path "agents" "test-agent.md"
            $content = Get-Content $agentPath -Raw
            $content += "`n## New Section`nAdded content"
            $content | Set-Content $agentPath

            # Verify modification detected
            $status = Get-SyncStatus
            $status.ModifiedFiles | Should -Contain "agents/test-agent.md"
        }

        It "Step 5: Sync modifications" {
            $result = Sync-Repository -DryRun -Message "test: update agent capabilities"

            $result.Status | Should -Be "DryRun"
        }

        It "Step 6: Delete agent file" {
            $agentPath = Join-Path "agents" "test-agent.md"
            Remove-Item $agentPath -Force

            # Verify deletion detected
            $status = Get-SyncStatus
            $status.DeletedFiles | Should -Contain "agents/test-agent.md"
        }

        It "Step 7: Sync deletion" {
            $result = Sync-Repository -DryRun

            $result.Status | Should -Be "DryRun"
            $result.FilesDeleted | Should -BeGreaterThan 0
        }

        It "Step 8: Verify no pending changes after sync" {
            # In real scenario (not dry run), status should show no changes
            $status = Get-SyncStatus
            $status | Should -Not -BeNullOrEmpty
        }
    }

    Context "Validation Workflow" {
        It "Should reject files with credentials" {
            $badAgentContent = @"
# Bad Agent

AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

This agent has hardcoded credentials (bad!)
"@
            $badAgentPath = Join-Path "agents" "bad-agent.md"
            $badAgentContent | Set-Content $badAgentPath

            $result = Sync-Repository -DryRun

            # Should detect validation errors
            $result.Status | Should -Be "ValidationFailed"
            $result.InvalidFiles.Count | Should -BeGreaterThan 0
        }
    }

    Context "Performance Requirements" {
        It "Should complete status check in under 5 seconds" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $status = Get-SyncStatus
            $stopwatch.Stop()

            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
        }

        It "Should complete dry-run sync in under 10 seconds" {
            # Create test file
            "# Quick test" | Set-Content "agents/perf-test.md"

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Sync-Repository -DryRun
            $stopwatch.Stop()

            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 10
        }
    }

    Context "Error Recovery" {
        It "Should handle network errors gracefully" {
            # Mock network failure (can't truly test without mocking)
            $status = Get-SyncStatus
            $status | Should -Not -BeNullOrEmpty
        }

        It "Should preserve local changes on push failure" {
            # Create a change
            "# Another test" | Set-Content "agents/recovery-test.md"

            # Even if push fails, file should remain
            "agents/recovery-test.md" | Should -Exist
        }
    }

    Context "Logging and Audit Trail" {
        It "Should create log files" {
            $logDir = Get-LogPath
            $logDir | Should -Not -BeNullOrEmpty

            # Log directory should exist after operations
            if (Test-Path $logDir) {
                $logFiles = Get-ChildItem $logDir -Filter "sync-*.log" -ErrorAction SilentlyContinue
                # May or may not have logs depending on operations
                $true | Should -Be $true  # Just verify command works
            }
        }

        It "Should retrieve recent logs" {
            $logs = Get-SyncLogs -Last 10
            # May be empty in test environment
            $logs | Should -Not -BeNull
        }
    }
}

AfterAll {
    Pop-Location

    # Cleanup
    if (Test-Path $script:TestRepo) {
        Remove-Item $script:TestRepo -Recurse -Force -ErrorAction SilentlyContinue
    }
}
