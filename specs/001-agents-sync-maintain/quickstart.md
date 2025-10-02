# Quickstart: Agent Synchronization System

## Prerequisites
- PowerShell 7.0+ installed
- Git 2.30+ installed and configured
- GitHub account with repository access
- GitHub CLI (`gh`) authenticated (optional but recommended)

## Initial Setup

### 1. Clone the Repository (New Machine)
```powershell
# Clone the claude-agents repository
git clone https://github.com/AlmightyTopher/claude-agents.git
cd claude-agents

# Verify sync tools are available
Get-Command Sync-Agents, Get-SyncStatus, Resolve-SyncConflict
```

### 2. Verify Configuration
```powershell
# Check Git identity
git config user.name
git config user.email

# If not set, configure them
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Verify GitHub authentication
gh auth status  # If using GitHub CLI
```

### 3. Check Sync Status
```powershell
# Get current sync status
Get-SyncStatus

# Expected output:
# Sync Status
# ===========
# Last Pull:        Never (first time)
# Pending Changes:  0 files
# Local Commits:    0 (in sync)
# Remote Commits:   0 (in sync)
# Conflicts:        None
# Health:           ✓ Healthy
```

---

## Daily Workflow

### Scenario 1: Start Work (Pull Latest Changes)
```powershell
# Pull latest changes from remote
Sync-Agents

# This automatically:
# 1. Pulls latest commits from GitHub
# 2. Validates local agent files
# 3. If you have changes, commits and pushes them
```

**Expected Output (No Local Changes)**:
```
Status         : Success
FilesPulled    : 3
FilesModified  : 0
FilesDeleted   : 0
CommitHash     :
PushStatus     : NotNeeded
Duration       : 00:00:02.1
```

---

### Scenario 2: Create New Agent
```powershell
# Create a new agent file
New-Item -Path "agents/my-new-agent.md" -ItemType File

# Edit the file with agent specification
code agents/my-new-agent.md

# Check what will be synced
Sync-Agents -DryRun

# Sync the new agent
Sync-Agents

# Expected output:
# Status         : Success
# FilesPulled    : 0
# FilesModified  : 1
# FilesDeleted   : 0
# CommitHash     : abc123def456...
# PushStatus     : Success
# Duration       : 00:00:03.5
```

---

### Scenario 3: Modify Existing Agent
```powershell
# Edit an existing agent
code agents/existing-agent.md

# Make your changes, save

# Sync the changes
Sync-Agents

# The system automatically:
# 1. Detects the modification
# 2. Validates the file
# 3. Commits with message: "sync: update 1 agent file - existing-agent.md (modified)"
# 4. Pushes to remote
```

**Expected Output**:
```
Status         : Success
FilesPulled    : 0
FilesModified  : 1
FilesDeleted   : 0
CommitHash     : def789abc012...
PushStatus     : Success
Duration       : 00:00:02.8
```

---

### Scenario 4: Delete Agent File
```powershell
# Delete an agent file
Remove-Item agents/old-agent.md

# Sync (will prompt for confirmation)
Sync-Agents

# Prompt:
# Confirm
# Are you sure you want to delete old-agent.md?
# [Y] Yes [N] No [?] Help (default is "N"):

# Type Y to confirm

# Or skip confirmation with -Force
Sync-Agents -Force
```

---

### Scenario 5: Check Status Anytime
```powershell
# Quick status check
Get-SyncStatus

# Detailed status with file list
Get-SyncStatus -Detailed

# JSON output for scripts
Get-SyncStatus -Json | ConvertFrom-Json
```

---

## Conflict Resolution

### Scenario 6: Handle Merge Conflict
```powershell
# Attempt to sync when remote has conflicting changes
Sync-Agents

# Output:
# Status            : Conflict
# ConflictingFiles  : @("agent1.md")
# Message           : Merge conflicts detected. Run Resolve-SyncConflict for guidance.
# SuggestedAction   : git pull --rebase or git pull --no-rebase

# Get conflict resolution guidance
Resolve-SyncConflict

# Output:
# Merge Conflicts Detected
# ========================
# 1 file has conflicts:
#
# agent1.md
#   Local:  Added new capabilities
#   Remote: Updated examples
#   ⚠ Cannot auto-resolve
#
# Run: Resolve-SyncConflict -FilePath agent1.md -Strategy Manual

# Manually resolve the conflict
Resolve-SyncConflict -FilePath agent1.md -Strategy Manual

# Follow the on-screen instructions:
# 1. Open agent1.md
# 2. Find <<<<<<< HEAD markers
# 3. Edit to resolve conflict
# 4. Remove markers
# 5. Save file
# 6. Run: git add agent1.md

git add agent1.md

# Complete the sync
Sync-Agents

# Conflict resolved!
```

---

### Scenario 7: Auto-Resolve Simple Conflicts
```powershell
# If conflict is simple (e.g., whitespace only)
Resolve-SyncConflict

# Output might suggest:
# agent2.md
#   Local:  Fixed typo
#   Remote: Reformatted whitespace
#   ✓ Can auto-resolve using KeepLocal strategy

# Auto-resolve using KeepLocal
Resolve-SyncConflict -FilePath agent2.md -Strategy KeepLocal -AutoResolve

# Output:
# Status     : Resolved
# FilePath   : agent2.md
# Strategy   : KeepLocal
# NextAction : Run Sync-Agents to commit resolution

# Complete the sync
Sync-Agents
```

---

## Offline Work

### Scenario 8: Work Without Internet
```powershell
# Attempt to sync without network
Sync-Agents

# Output:
# Status               : NetworkError
# Message              : Cannot reach remote repository.
# LocalChangesPreserved: True
# SuggestedAction      : Work offline. Changes will sync when connection restored.

# Continue working locally
code agents/my-agent.md
# Make changes...

# Later, when network is restored
Sync-Agents

# All local changes will be committed and pushed
```

---

## Validation Errors

### Scenario 9: Fix Validation Errors
```powershell
# Create an invalid agent file (missing required fields)
"invalid content" > agents/bad-agent.md

# Attempt to sync
Sync-Agents

# Output:
# Status          : ValidationFailed
# InvalidFiles    : @{File=bad-agent.md; Errors=Missing required field: name}
# Message         : Fix validation errors before committing

# Fix the file
code agents/bad-agent.md
# Add required fields...

# Retry sync
Sync-Agents

# Now succeeds
```

---

## Advanced Usage

### Custom Commit Messages
```powershell
# Use custom commit message instead of auto-generated
Sync-Agents -Message "feat: add support for new agent capabilities"
```

### Sync Specific Files Only
```powershell
# Sync only a specific file or directory
Sync-Agents -Path agents/specific-agent.md
```

### Review Before Syncing
```powershell
# See what would be synced without making changes
Sync-Agents -DryRun

# Output:
# [DRY RUN] Would pull from remote
# [DRY RUN] Would commit 2 files:
#   - agent1.md (modified)
#   - agent2.md (added)
# [DRY RUN] Would push to remote
# No changes made.
```

---

## Troubleshooting

### Problem: "Not a git repository"
```powershell
# Solution: Initialize the repository
git init
git remote add origin https://github.com/AlmightyTopher/claude-agents.git
git pull origin master
```

### Problem: "Authentication failed"
```powershell
# Solution: Authenticate with GitHub
gh auth login

# Or configure Git credentials
git config credential.helper store
git pull  # Will prompt for credentials
```

### Problem: "Validation always fails"
```powershell
# Check what's being validated
Get-SyncStatus -Detailed

# Review validation errors
# Fix agent files to match required format
```

### Problem: "Sync is slow"
```powershell
# Check network connectivity
Test-NetConnection github.com -Port 443

# Verify Git performance
git status  # Should be <1 second

# If slow, try garbage collection
git gc --aggressive
```

---

## Verification Tests

### Test 1: Roundtrip Sync (Machine A → GitHub → Machine B)
```powershell
# On Machine A:
echo "test content" > agents/test-agent.md
Sync-Agents

# On Machine B:
Sync-Agents
cat agents/test-agent.md  # Should show "test content"

# Cleanup:
Remove-Item agents/test-agent.md
Sync-Agents -Force
```

### Test 2: Conflict Detection
```powershell
# On Machine A:
echo "version A" > agents/conflict-test.md
Sync-Agents

# On Machine B (without pulling first):
echo "version B" > agents/conflict-test.md
Sync-Agents

# Should detect conflict and guide resolution
```

### Test 3: Validation Enforcement
```powershell
# Create invalid file
"{invalid json" > agents/invalid.md
Sync-Agents

# Should fail validation before committing
# Fix and retry
```

---

## Next Steps

After completing the quickstart:
1. Review the [Data Model](./data-model.md) to understand internal structure
2. Read [Contract Documentation](./contracts/) for detailed command reference
3. Check [Tasks](./tasks.md) for implementation roadmap
4. Contribute improvements via pull requests following the constitution

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `Sync-Agents` | Pull, validate, commit, and push agent files |
| `Sync-Agents -DryRun` | Preview sync without making changes |
| `Get-SyncStatus` | Check current sync status |
| `Get-SyncStatus -Detailed` | Show detailed file-level status |
| `Resolve-SyncConflict` | List and resolve merge conflicts |
| `Resolve-SyncConflict -FilePath <file> -Strategy Manual` | Get manual resolution guidance |
| `Resolve-SyncConflict -FilePath <file> -Strategy KeepLocal -AutoResolve` | Auto-resolve using local version |
