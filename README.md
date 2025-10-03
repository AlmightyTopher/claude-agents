# AgentSync - Claude Code Agent Synchronization System

> **PowerShell module for Git-based synchronization of Claude Code agent specifications across machines and teams.**

Keep your Claude Code agent files in sync across multiple machines, prevent conflicts, and maintain a single source of truth in GitHub. Built with PowerShell 7+ for cross-platform compatibility.

[![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)](https://github.com/PowerShell/PowerShell)

---

## Why AgentSync?

Working with Claude Code agents across multiple machines or team members? AgentSync solves common problems:

- ✅ **No More Conflicts**: Pull-before-modify workflow prevents merge conflicts
- ✅ **Security First**: Automatically scans for hardcoded credentials before commits
- ✅ **One Command Sync**: `Sync-Agents` handles pull → validate → commit → push
- ✅ **Works Offline**: Gracefully handles network failures, queues changes locally
- ✅ **Cross-Platform**: Windows, macOS, and Linux support via PowerShell 7+
- ✅ **Audit Trail**: Complete logging of all sync operations

## Quick Start

```powershell
# Install globally
Install-Module AgentSync -Scope CurrentUser

# In your agent repository
Import-Module AgentSync

# Check status
Get-SyncStatus

# Sync all changes
Sync-Agents
```

## Features

### 🔄 Automatic Synchronization
Pull, validate, commit, and push agent files with a single command. No manual Git commands needed.

### ⚠️ Conflict Detection & Resolution
Detects merge conflicts automatically and provides clear resolution strategies:
- Keep local changes
- Accept remote changes
- Manual merge guidance
- Auto-resolve simple conflicts

### 🔒 Security Validation
Scans agent files before committing for:
- AWS credentials (`AKIA...`)
- GitHub tokens (`ghp_...`)
- API keys and passwords
- Private keys (`.pem`, `.key`)
- Generic secrets

### 📊 Real-Time Status
See at a glance:
- Pending changes
- Files modified/added/deleted
- Commits ahead/behind remote
- Conflict status
- Repository health

### 📝 Comprehensive Logging
All sync operations logged with:
- Timestamps and durations
- Files affected
- Success/failure status
- Error details
- Automatic log rotation

## Installation

### Prerequisites

- **PowerShell 7.0+**: [Install PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **Git 2.30+**: [Install Git](https://git-scm.com/downloads)
- **GitHub account** with agent repository

### Option 1: Install from PowerShell Gallery (Recommended)

```powershell
Install-Module -Name AgentSync -Scope CurrentUser
```

### Option 2: Install from Source

```powershell
# Clone repository
git clone https://github.com/AlmightyTopher/claude-agents.git

# Copy to PowerShell modules directory
$modulePath = "$HOME\Documents\PowerShell\Modules\AgentSync"
Copy-Item -Path ".\claude-agents\agents" -Destination $modulePath -Recurse

# Verify installation
Get-Module -ListAvailable AgentSync
```

### Option 3: Use Directly (No Installation)

```powershell
# Navigate to your agent repository
cd C:\path\to\your\agents

# Import module from local path
Import-Module C:\path\to\AgentSync\AgentSync.psd1
```

### Initial Setup

```powershell
# In your agent repository directory
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Authenticate with GitHub (choose one)
gh auth login                    # GitHub CLI (recommended)
git config credential.helper store  # OR use credential helper
```

## Usage

### Typical Workflow

```powershell
# 1. Start your day - pull latest changes
cd C:\Users\YourName\.claude\agents
Import-Module AgentSync
Sync-Agents

# 2. Edit your agent files
code tech-lead-reviewer.md

# 3. Check what changed
Get-SyncStatus

# 4. Sync changes back
Sync-Agents -Message "feat: improve tech lead review criteria"
```

### Common Commands

#### 📤 Sync Changes (Pull + Commit + Push)

```powershell
Sync-Agents                              # Sync all changes
Sync-Agents -DryRun                      # Preview without executing
Sync-Agents -Message "Custom message"    # Use custom commit message
Sync-Agents -Path agents/specific-agent.md  # Sync specific file
Sync-Agents -Force                       # Skip deletion confirmations
```

#### 📊 Check Sync Status

```powershell
Get-SyncStatus                # Quick status overview
Get-SyncStatus -Detailed      # Show modified file list
Get-SyncStatus -Json          # Machine-readable output
```

**Example output:**
```
Sync Status
===========

Last Pull:        2 hours ago
Pending Changes:  3 files (2 modified, 1 added)
Local Commits:    0 (in sync)
Remote Commits:   1 (behind remote)
Conflicts:        None
Health:           ✓ Healthy

Next Action: Run Sync-Agents to pull latest changes
```

#### ⚠️ Resolve Conflicts

```powershell
Resolve-SyncConflict                    # List all conflicts
Resolve-SyncConflict -FilePath agent.md -Strategy Manual  # Get guidance
Resolve-SyncConflict -FilePath agent.md -Strategy KeepLocal -AutoResolve
Resolve-SyncConflict -FilePath agent.md -Strategy KeepRemote -AutoResolve
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

## Use Cases

### Solo Developer
Sync Claude Code agents between work laptop, home desktop, and cloud dev environment:
```powershell
# On each machine
Import-Module AgentSync
Sync-Agents  # Automatically stays in sync
```

### Team Collaboration
Multiple developers working on shared agent specifications:
- Pull-before-modify prevents conflicts
- Credential scanning prevents security leaks
- Audit logs track who changed what

### CI/CD Integration
Automated agent validation in pipelines:
```powershell
Get-SyncStatus -Json | ConvertFrom-Json | ForEach-Object {
    if ($_.HasConflicts) { exit 1 }
}
```

## Performance

- **Git status caching**: 5-second TTL reduces redundant Git calls
- **Scoped file scanning**: Only scans agent directories
- **Sub-5 second status checks**: Fast feedback loop
- **Efficient logging**: JSON-based with automatic rotation

## Version History

### 1.0.0 (2025-10-02)
- ✅ Core synchronization workflow (pull → validate → commit → push)
- ✅ Conflict detection and resolution strategies
- ✅ Security validation (6 credential patterns)
- ✅ Cross-platform support (Windows, macOS, Linux)
- ✅ Comprehensive logging with rotation
- ✅ Git status caching for performance
- ⚠️ File watcher auto-sync (planned for v2.0)
