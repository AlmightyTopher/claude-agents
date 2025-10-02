# Agent Sync - Claude Code Agent Synchronization System

Git-based synchronization system for Claude Code agent files across multiple machines.

## Features

- **Automatic Synchronization**: Pull, validate, commit, and push agent files with a single command
- **Conflict Detection**: Detects and helps resolve merge conflicts with clear guidance
- **Validation**: Scans agent files for syntax errors and credentials before committing
- **Cross-Platform**: Works on Windows, Linux, and macOS via PowerShell 7.0+
- **Offline Support**: Gracefully handles network failures, allows local work
- **Comprehensive Logging**: All sync operations logged for troubleshooting

## Prerequisites

- **PowerShell 7.0+**: [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **Git 2.30+**: [Install Git](https://git-scm.com/downloads)
- **GitHub CLI** (optional): [Install gh](https://cli.github.com/)
- **Pester 5.0+**: Install via `Install-Module -Name Pester -MinimumVersion 5.0.0 -Force`

## Installation

### 1. Clone the Repository

```powershell
git clone https://github.com/AlmightyTopher/claude-agents.git
cd claude-agents
```

### 2. Import the Module

```powershell
Import-Module ./AgentSync.psd1
```

### 3. Configure Git

```powershell
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### 4. Authenticate with GitHub

```powershell
gh auth login  # If using GitHub CLI
# OR configure Git credentials
```

## Usage

### Daily Workflow

#### Sync Changes (Pull + Commit + Push)

```powershell
# Sync all agent files
Sync-Agents

# Dry run (preview without changes)
Sync-Agents -DryRun

# Sync specific file or directory
Sync-Agents -Path agents/my-agent.md

# Skip confirmation prompts
Sync-Agents -Force
```

#### Check Sync Status

```powershell
# Quick status
Get-SyncStatus

# Detailed status with file list
Get-SyncStatus -Detailed

# JSON output for scripts
Get-SyncStatus -Json
```

#### Resolve Conflicts

```powershell
# List all conflicts
Resolve-SyncConflict

# Get resolution guidance
Resolve-SyncConflict -FilePath agent1.md -Strategy Manual

# Auto-resolve simple conflicts
Resolve-SyncConflict -FilePath agent2.md -Strategy KeepLocal -AutoResolve
```

## Commands

### Sync-Agents

Main synchronization command that performs:
1. Pull latest changes from remote
2. Validate modified agent files
3. Commit changes with descriptive message
4. Push to remote repository

**Parameters**:
- `-Force`: Skip confirmation prompts
- `-DryRun`: Preview changes without executing
- `-Message <string>`: Custom commit message
- `-Path <string>`: Specific file or directory to sync

**Exit Codes**:
- `0`: Success
- `1`: Merge conflict detected
- `2`: Validation failed
- `3`: Network error
- `4`: Authentication failed

### Get-SyncStatus

Display current synchronization status.

**Parameters**:
- `-Detailed`: Show verbose status with file list
- `-Json`: Output in JSON format

**Returns**:
- Last pull time
- Pending changes count
- Local/remote commit differences
- Conflict status
- Health indicator

### Resolve-SyncConflict

Provides conflict resolution guidance and tools.

**Parameters**:
- `-FilePath <string>`: Specific file to resolve
- `-Strategy <enum>`: Resolution strategy (Merge, Rebase, KeepLocal, KeepRemote, Manual)
- `-AutoResolve`: Attempt automatic resolution

**Strategies**:
- **Manual**: Edit file to resolve (recommended for complex conflicts)
- **KeepLocal**: Discard remote changes, keep local version
- **KeepRemote**: Discard local changes, accept remote version
- **Merge**: Attempt to combine both changes
- **Rebase**: Replay local commits on top of remote

## Architecture

```
AgentSync/
├── src/
│   ├── models/         # Data entities (AgentFile, SyncOperation, Conflict, SyncLog)
│   ├── services/       # Business logic (Git, Validation, Conflict, Sync)
│   ├── cli/            # User commands (Sync-Agents, Get-SyncStatus, Resolve-SyncConflict)
│   └── lib/            # Utilities (Logger, FileWatcher)
├── tests/
│   ├── contract/       # Service contract tests
│   ├── integration/    # End-to-end scenario tests
│   └── unit/           # Component unit tests
└── logs/               # Sync operation logs (not committed)
```

## Testing

Run all tests:

```powershell
Import-Module ./PesterConfiguration.ps1
Invoke-Pester -Configuration $PesterConfig
```

Run specific test suite:

```powershell
Invoke-Pester tests/integration/
```

## Configuration

### .gitignore Patterns

The system automatically maintains `.gitignore` to exclude:
- `logs/` - Sync operation logs
- `.env*` - Environment variables
- `credentials.json`, `*.key` - Sensitive files

### Logging

Logs are stored in `logs/sync-YYYY-MM-DD.json` with:
- All sync operations (pull, commit, push)
- Validation results
- Conflict detections
- Error details

Logs rotate daily and are excluded from Git.

## Troubleshooting

### "Not a git repository"

```powershell
git init
git remote add origin https://github.com/AlmightyTopher/claude-agents.git
git pull origin master
```

### "Authentication failed"

```powershell
gh auth login
# OR
git config credential.helper store
git pull  # Will prompt for credentials
```

### "Validation always fails"

Check validation errors:

```powershell
Get-SyncStatus -Detailed
```

Fix agent files to match required format.

### Performance Issues

```powershell
# Optimize Git repository
git gc --aggressive

# Check network connectivity
Test-NetConnection github.com -Port 443
```

## Contributing

1. Follow the project [constitution](.specify/memory/constitution.md)
2. Write tests before implementation (TDD)
3. Ensure all tests pass: `Invoke-Pester`
4. Validate no secrets committed: Run security audit
5. Submit pull requests to `master` branch

## License

See [LICENSE](LICENSE)

## Support

- **Issues**: https://github.com/AlmightyTopher/claude-agents/issues
- **Documentation**: [Quickstart Guide](specs/001-agents-sync-maintain/quickstart.md)
- **Specification**: [Feature Spec](specs/001-agents-sync-maintain/spec.md)

## Version History

### 1.0.0 (2025-10-02)
- Initial release
- Core synchronization workflow
- Conflict detection and resolution
- Validation and credential scanning
- Cross-platform support
