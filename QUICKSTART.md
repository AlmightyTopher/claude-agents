# Agent Sync Quickstart Guide

Complete guide to getting started with Agent Synchronization System.

## Installation

### Prerequisites
- PowerShell 7.0 or higher
- Git 2.x or higher
- GitHub CLI (`gh`) for authentication
- Active GitHub repository for agent storage

### Install Module

```powershell
# Clone the repository
git clone https://github.com/YOUR_USERNAME/claude-agents.git
cd claude-agents

# Import the module
Import-Module ./AgentSync.psd1

# Verify installation
Get-Command -Module AgentSync
```

### Configure GitHub Authentication

```powershell
# Authenticate with GitHub
gh auth login

# Verify authentication
gh auth status
```

## Quick Start Scenarios

### Scenario 1: Start Work - Pull Latest

**When to use:** Beginning your work session

```powershell
# Pull latest changes from remote
Sync-Agents
```

**Expected output:**
```
✓ Sync successful!
  Files pulled: 3
  Files modified: 0
  Files deleted: 0
  Duration: 1.2s

Successfully synced. All up to date.
```

---

### Scenario 2: Create New Agent

**When to use:** Adding a new agent specification

```powershell
# Create new agent file
@"
# My New Agent

**Version:** 1.0.0
**Purpose:** Data analysis automation

## Description
This agent helps with data analysis tasks.

## Capabilities
- Data cleaning
- Statistical analysis
- Visualization generation
"@ | Set-Content agents/data-analyst.md

# Check status
Get-SyncStatus

# Sync to remote
Sync-Agents -Message "feat: add data analyst agent"
```

**Expected output:**
```
✓ Sync successful!
  Files pulled: 0
  Files modified: 1
  Files deleted: 0
  Commit: a1b2c3d
  Duration: 2.5s

Successfully synced 1 file(s)
```

---

### Scenario 3: Modify Existing Agent

**When to use:** Updating an agent specification

```powershell
# Edit the file (use your preferred editor)
code agents/data-analyst.md

# After making changes, sync
Sync-Agents -Message "docs: update data analyst capabilities"
```

---

### Scenario 4: Delete Agent File

**When to use:** Removing an obsolete agent

```powershell
# Delete the file
Remove-Item agents/old-agent.md

# Sync deletion (will prompt for confirmation)
Sync-Agents

# Or force without prompt
Sync-Agents -Force
```

**Expected output:**
```
The following files will be deleted:
  - agents/old-agent.md
Are you sure you want to delete these files? [Y/N]
Y

✓ Sync successful!
  Files pulled: 0
  Files modified: 0
  Files deleted: 1
  Duration: 1.8s
```

---

### Scenario 5: Check Status

**When to use:** Checking sync state before/after work

```powershell
# Quick status
Get-SyncStatus

# Detailed status with file list
Get-SyncStatus -Detailed

# JSON output for scripting
Get-SyncStatus -Json
```

**Expected output:**
```
Sync Status
===========

Last Pull:        2 hours ago
Pending Changes:  2 files (1 modified, 1 added)
Local Commits:    0 (in sync)
Remote Commits:   0 (in sync)
Conflicts:        None
Health:           ✓ Healthy

Next Action: Run Sync-Agents to commit and push changes
```

---

### Scenario 6: Handle Merge Conflict

**When to use:** Two people edited the same agent file

```powershell
# Pull changes - conflict detected
Sync-Agents

# Check conflicting files
Resolve-SyncConflict

# Get resolution guidance for specific file
Resolve-SyncConflict -FilePath agents/conflicted-agent.md -Strategy Manual

# Auto-resolve by keeping your changes
Resolve-SyncConflict -FilePath agents/conflicted-agent.md -Strategy KeepLocal -AutoResolve

# Or accept remote changes
Resolve-SyncConflict -FilePath agents/conflicted-agent.md -Strategy KeepRemote -AutoResolve

# After resolving, complete the sync
Sync-Agents
```

**Conflict output:**
```
Merge Conflicts Detected
========================

The following files have conflicts:
  ⚠ agents/conflicted-agent.md

Resolution Options:
  1. Resolve specific file:
     Resolve-SyncConflict -FilePath <file> -Strategy <strategy>
```

---

### Scenario 7: Auto-Resolve Simple Conflicts

**When to use:** Conflict is whitespace or non-overlapping changes

```powershell
# Check if auto-resolvable
Resolve-SyncConflict

# If marked as auto-resolvable (⚡ symbol):
Resolve-SyncConflict -FilePath agents/simple-conflict.md -Strategy KeepLocal -AutoResolve
```

---

### Scenario 8: Work Offline

**When to use:** No internet connection

```powershell
# Make changes offline
code agents/my-agent.md

# Check local status (works offline)
Get-SyncStatus

# Try to sync - will detect network error
Sync-Agents
```

**Expected output:**
```
⚠ Network error!
  Cannot reach remote repository. Check internet connection.

Local changes have been preserved.
Retry sync when connection is restored.
```

---

### Scenario 9: Fix Validation Errors

**When to use:** File has syntax errors or credentials

```powershell
# Attempt sync with invalid file
Sync-Agents

# If validation fails, fix the errors
code agents/problematic-agent.md

# Retry sync
Sync-Agents
```

**Validation error output:**
```
✗ Validation errors detected!
  Invalid files:
    - agents/problematic-agent.md
      • File contains hardcoded AWS credentials
      • File size exceeds 10MB limit

Fix validation errors and retry sync.
```

---

## Advanced Usage

### Dry Run Mode

Preview changes without committing:

```powershell
Sync-Agents -DryRun
```

### Custom Commit Messages

```powershell
Sync-Agents -Message "feat: add ML agent for recommendations"
```

### Sync Specific Path

```powershell
Sync-Agents -Path agents/specific-folder/
```

### Watch for Changes (Auto-Sync)

```powershell
# Start file watcher with auto-sync
Start-FileWatcher -Path "agents" -AutoSync

# Check active watchers
Get-FileWatchers

# Stop watching
Stop-FileWatcher -WatcherId <id>
```

### View Logs

```powershell
# Last 20 log entries
Get-SyncLogs -Last 20

# Errors from last 7 days
Get-SyncLogs -Level Error -StartDate (Get-Date).AddDays(-7)

# Format for display
Get-SyncLogs -Last 50 | Format-LogOutput
```

---

## Troubleshooting

### "Permission denied (publickey)"

**Solution:** Configure GitHub authentication

```powershell
gh auth login
# Or configure SSH keys manually
```

### "Validation failed" - Credentials detected

**Solution:** Remove hardcoded credentials, use environment variables

```powershell
# BAD - hardcoded
$apiKey = "ghp_1234567890abcdef..."

# GOOD - environment variable
$apiKey = $env:GITHUB_API_KEY
```

### "Merge conflict detected"

**Solution:** Use conflict resolution commands

```powershell
Resolve-SyncConflict
Resolve-SyncConflict -FilePath <file> -Strategy Manual
```

### "Cannot reach remote repository"

**Solution:** Check internet connection and GitHub status

```powershell
# Test connectivity
Test-NetConnection github.com -Port 443

# Check GitHub status
gh api https://www.githubstatus.com/api/v2/status.json
```

### Logs growing too large

**Solution:** Log rotation runs automatically, or trigger manually

```powershell
Rotate-Logs -MaxAgeInDays 30
```

---

## Performance Tips

1. **Use caching:** Git status is cached for 5 seconds automatically
2. **Limit file scanning:** Use `-Path` parameter to sync specific directories
3. **Batch changes:** Make multiple edits before syncing
4. **Monitor logs:** Check `Get-SyncLogs` for slow operations

---

## Best Practices

### ✅ DO

- Pull before starting work (`Sync-Agents` at start of day)
- Write descriptive commit messages
- Use `-DryRun` for large changes
- Monitor sync status regularly
- Keep agent files under 10MB
- Use UTF-8 encoding for all files
- Store credentials in environment variables

### ❌ DON'T

- Hardcode credentials in agent files
- Skip pulling before modifications
- Ignore validation errors
- Force push to main branch
- Commit binary files or large media
- Edit files during active sync operation

---

## Command Reference

| Command | Purpose |
|---------|---------|
| `Sync-Agents` | Main sync operation: pull → commit → push |
| `Get-SyncStatus` | Check sync state and pending changes |
| `Resolve-SyncConflict` | Handle merge conflicts |
| `Start-FileWatcher` | Auto-sync on file changes |
| `Get-SyncLogs` | View operation history |
| `Rotate-Logs` | Manage log file size |

---

## Getting Help

```powershell
# Command help
Get-Help Sync-Agents -Full
Get-Help Get-SyncStatus -Examples
Get-Help Resolve-SyncConflict -Detailed

# Module information
Get-Module AgentSync | Format-List

# List all commands
Get-Command -Module AgentSync
```

---

## Next Steps

1. **Read the Constitution:** See `constitution.md` for governance principles
2. **Review Examples:** Check `specs/001-agents-sync-maintain/quickstart.md`
3. **Run Tests:** Execute `Invoke-Pester` to verify installation
4. **Configure Automation:** Set up file watcher for continuous sync

---

## Support

- **Issues:** Report bugs at repository issues page
- **Logs:** Check `logs/` directory for troubleshooting
- **Status:** Run `Get-SyncStatus -Detailed` for diagnostic info

**Version:** 1.0.0
**Last Updated:** 2025-10-02
