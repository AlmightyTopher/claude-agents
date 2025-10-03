@{
    # Script module or binary module file associated with this manifest
    RootModule = 'AgentSync.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = '8f4a1b3c-9d2e-4f5a-8b1c-6d7e8f9a0b1c'

    # Author of this module
    Author = 'AlmightyTopher'

    # Company or vendor of this module
    CompanyName = 'Claude Agents Project'

    # Copyright statement for this module
    Copyright = '(c) 2025 AlmightyTopher. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Agent Synchronization System - Git-based sync for Claude Code agent files across multiple machines'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # Note: Pester is only required for running tests, not for using the module
    RequiredModules = @()

    # Functions to export from this module
    FunctionsToExport = @(
        'Sync-Agents',
        'Get-SyncStatus',
        'Resolve-SyncConflict'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for online galleries
            Tags = @('Git', 'Sync', 'Agent', 'Claude', 'Version-Control')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/AlmightyTopher/claude-agents/blob/master/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/AlmightyTopher/claude-agents'

            # ReleaseNotes of this module
            ReleaseNotes = @'
## Version 1.0.0
- Initial release
- Git-based synchronization for agent files
- Pull-before-modify workflow
- Conflict detection and resolution
- Validation and credential scanning
- Cross-platform support (Windows, Linux, macOS)
'@
        }
    }
}
