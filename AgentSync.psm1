# AgentSync Module - Agent Synchronization System
# Main module file that loads all components

$ErrorActionPreference = 'Stop'

# Get the module root path
$ModuleRoot = $PSScriptRoot

# Import in dependency order to handle 'using module' statements
try {
    # 1. Import models first (no dependencies)
    $modelFiles = @(
        "$ModuleRoot/src/models/AgentFile.psm1",
        "$ModuleRoot/src/models/SyncOperation.psm1",
        "$ModuleRoot/src/models/Conflict.psm1",
        "$ModuleRoot/src/models/SyncLog.psm1"
    )
    foreach ($file in $modelFiles) {
        if (Test-Path $file) {
            Import-Module $file -Force -Global
        }
    }

    # 2. Import libraries (may depend on models)
    $libFiles = @(
        "$ModuleRoot/src/lib/Logger.psm1",
        "$ModuleRoot/src/lib/ErrorHandler.psm1",
        "$ModuleRoot/src/lib/FileWatcher.psm1"
    )
    foreach ($file in $libFiles) {
        if (Test-Path $file) {
            Import-Module $file -Force -Global
        }
    }

    # 3. Import services (depend on models and libraries)
    $serviceFiles = @(
        "$ModuleRoot/src/services/GitService.psm1",
        "$ModuleRoot/src/services/ValidationService.psm1",
        "$ModuleRoot/src/services/ConflictService.psm1",
        "$ModuleRoot/src/services/SyncService.psm1"
    )
    foreach ($file in $serviceFiles) {
        if (Test-Path $file) {
            Import-Module $file -Force -Global
        }
    }

    # 4. Dot-source CLI commands (depend on everything)
    $cliFiles = @(
        "$ModuleRoot/src/cli/Sync-Agents.ps1",
        "$ModuleRoot/src/cli/Get-SyncStatus.ps1",
        "$ModuleRoot/src/cli/Resolve-SyncConflict.ps1"
    )
    foreach ($file in $cliFiles) {
        if (Test-Path $file) {
            . $file
        }
    }

    # Export public functions
    Export-ModuleMember -Function @(
        'Sync-Agents',
        'Get-SyncStatus',
        'Resolve-SyncConflict',
        'Start-FileWatcher',
        'Stop-FileWatcher',
        'Get-FileWatchers',
        'Get-SyncLogs',
        'Rotate-Logs'
    )
}
catch {
    Write-Error "Failed to load AgentSync module: $($_.Exception.Message)"
    throw
}
