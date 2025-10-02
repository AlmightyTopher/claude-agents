BeforeAll {
    $ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $LoggerPath = Join-Path $ModuleRoot "src/lib/Logger.psm1"

    if (Test-Path $LoggerPath) {
        Import-Module $LoggerPath -Force
    }
}

Describe "Logger Module Unit Tests" {
    Context "Write-SyncLog" {
        BeforeEach {
            $testLogDir = Join-Path $TestDrive "logs"
            New-Item -Path $testLogDir -ItemType Directory -Force | Out-Null
        }

        It "should create log file with correct format" {
            $operation = @{
                OperationType = "Pull"
                Status = "Success"
                Timestamp = Get-Date
                Duration = [timespan]::FromSeconds(2)
            }

            Write-SyncLog -Operation $operation -LogDirectory $testLogDir

            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $logFile | Should -Not -BeNullOrEmpty
        }

        It "should format log as valid JSON" {
            $operation = @{
                OperationType = "Commit"
                Status = "Success"
                Timestamp = Get-Date
            }

            Write-SyncLog -Operation $operation -LogDirectory $testLogDir

            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $content = Get-Content $logFile.FullName -Raw

            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It "should append operations to same-day log file" {
            $op1 = @{ OperationType = "Pull"; Status = "Success"; Timestamp = Get-Date }
            $op2 = @{ OperationType = "Commit"; Status = "Success"; Timestamp = Get-Date }

            Write-SyncLog -Operation $op1 -LogDirectory $testLogDir
            Write-SyncLog -Operation $op2 -LogDirectory $testLogDir

            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $log = Get-Content $logFile.FullName | ConvertFrom-Json

            $log.Operations.Count | Should -Be 2
        }

        It "should include session metadata" {
            $operation = @{ OperationType = "Push"; Status = "Success"; Timestamp = Get-Date }

            Write-SyncLog -Operation $operation -LogDirectory $testLogDir

            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $log = Get-Content $logFile.FullName | ConvertFrom-Json

            $log.LogId | Should -Not -BeNullOrEmpty
            $log.SessionStart | Should -Not -BeNullOrEmpty
            $log.Operations | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-LogPath" {
        It "should return path with current date" {
            $result = Get-LogPath

            $result | Should -Match "sync-\d{4}-\d{2}-\d{2}\.json"
        }

        It "should use logs directory by default" {
            $result = Get-LogPath

            $result | Should -Match "logs[/\\]sync-"
        }

        It "should accept custom directory" {
            $customDir = "C:\custom\logs"

            $result = Get-LogPath -LogDirectory $customDir

            $result | Should -Match "custom[/\\]logs[/\\]sync-"
        }
    }

    Context "Rotate-Logs" {
        BeforeEach {
            $testLogDir = Join-Path $TestDrive "logs"
            New-Item -Path $testLogDir -ItemType Directory -Force | Out-Null

            # Create old log files
            for ($i = 1; $i -le 40; $i++) {
                $date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
                $logPath = Join-Path $testLogDir "sync-$date.json"
                '{"LogId":"test","Operations":[]}' | Out-File -FilePath $logPath
            }
        }

        It "should delete logs older than 30 days by default" {
            Rotate-Logs -LogDirectory $testLogDir

            $remainingLogs = Get-ChildItem $testLogDir -Filter "sync-*.json"
            $remainingLogs.Count | Should -BeLessOrEqual 30
        }

        It "should keep logs within retention period" {
            Rotate-Logs -LogDirectory $testLogDir -RetentionDays 30

            $remainingLogs = Get-ChildItem $testLogDir -Filter "sync-*.json"
            foreach ($log in $remainingLogs) {
                $logDate = [datetime]::ParseExact($log.BaseName.Replace("sync-", ""), "yyyy-MM-dd", $null)
                $age = (Get-Date) - $logDate
                $age.Days | Should -BeLessOrEqual 30
            }
        }

        It "should return count of deleted logs" {
            $result = Rotate-Logs -LogDirectory $testLogDir -RetentionDays 30

            $result.DeletedCount | Should -BeGreaterThan 0
            $result.DeletedCount | Should -BeGreaterOrEqual 10
        }

        It "should accept custom retention period" {
            $result = Rotate-Logs -LogDirectory $testLogDir -RetentionDays 7

            $remainingLogs = Get-ChildItem $testLogDir -Filter "sync-*.json"
            $remainingLogs.Count | Should -BeLessOrEqual 7
        }
    }

    Context "Log Filtering and Querying" {
        BeforeEach {
            $testLogDir = Join-Path $TestDrive "logs"
            New-Item -Path $testLogDir -ItemType Directory -Force | Out-Null

            # Create log with mixed operations
            $operations = @(
                @{ OperationType = "Pull"; Status = "Success"; Timestamp = Get-Date }
                @{ OperationType = "Commit"; Status = "Failed"; Timestamp = Get-Date }
                @{ OperationType = "Push"; Status = "Success"; Timestamp = Get-Date }
            )

            foreach ($op in $operations) {
                Write-SyncLog -Operation $op -LogDirectory $testLogDir
            }
        }

        It "should filter operations by type" {
            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $log = Get-Content $logFile.FullName | ConvertFrom-Json

            $pullOps = $log.Operations | Where-Object { $_.OperationType -eq "Pull" }
            $pullOps.Count | Should -Be 1
        }

        It "should filter operations by status" {
            $logFile = Get-ChildItem $testLogDir -Filter "sync-*.json" | Select-Object -First 1
            $log = Get-Content $logFile.FullName | ConvertFrom-Json

            $failedOps = $log.Operations | Where-Object { $_.Status -eq "Failed" }
            $failedOps.Count | Should -BeGreaterOrEqual 1
        }
    }
}

AfterAll {
    # Cleanup test logs
}
