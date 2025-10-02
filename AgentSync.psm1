# AgentSync Module - Agent Synchronization System
# Main module file that loads all components

$ErrorActionPreference = 'Stop'

# Get the module root path
$ModuleRoot = $PSScriptRoot

# Import models
Get-ChildItem -Path "$ModuleRoot/src/models/*.psm1" -ErrorAction SilentlyContinue | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Import services
Get-ChildItem -Path "$ModuleRoot/src/services/*.psm1" -ErrorAction SilentlyContinue | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Import libraries
Get-ChildItem -Path "$ModuleRoot/src/lib/*.psm1" -ErrorAction SilentlyContinue | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Dot-source CLI commands
Get-ChildItem -Path "$ModuleRoot/src/cli/*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    . $_.FullName
}

# Export public functions
Export-ModuleMember -Function @(
    'Sync-Agents',
    'Get-SyncStatus',
    'Resolve-SyncConflict'
)
