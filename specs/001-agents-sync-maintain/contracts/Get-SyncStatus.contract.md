# Contract: Get-SyncStatus Command

**Command**: `Get-SyncStatus`
**Purpose**: Display current synchronization status showing last pull time, pending changes, and repository health.

## Inputs

**Parameters**:
- `-Detailed` (switch, optional): Show verbose status including individual file changes
- `-Json` (switch, optional): Output in JSON format for programmatic use

**Preconditions**:
- Git repository must be initialized
- Logs directory exists (or will be created)

## Outputs

**Standard Output** (Exit Code 0):
```powershell
[PSCustomObject]@{
    LastPullTime = [DateTime]::Now.AddHours(-2)
    PendingChanges = 3
    LocalCommits = 1
    RemoteCommits = 0
    HasConflicts = $false
    IsHealthy = $true
    ModifiedFiles = @("agent1.md", "agent2.md")
    UntrackedFiles = @("agent3.md")
    DeletedFiles = @()
    NextAction = "Run Sync-Agents to push changes"
}
```

**Conflict Status** (Exit Code 1):
```powershell
[PSCustomObject]@{
    LastPullTime = [DateTime]::Now.AddHours(-1)
    PendingChanges = 2
    LocalCommits = 0
    RemoteCommits = 3
    HasConflicts = $true
    IsHealthy = $false
    ConflictingFiles = @("agent1.md")
    NextAction = "Run Resolve-SyncConflict to fix conflicts"
}
```

**Behind Remote** (Exit Code 0 with warning):
```powershell
[PSCustomObject]@{
    LastPullTime = [DateTime]::Now.AddHours(-24)
    PendingChanges = 0
    LocalCommits = 0
    RemoteCommits = 5
    HasConflicts = $false
    IsHealthy = $true
    NextAction = "Run Sync-Agents to pull latest changes"
}
```

## Behavior

**Status Calculation**:
1. Execute `git fetch origin` (if network available)
2. Parse `git status --porcelain` for local changes
3. Compare `git rev-list --count origin/master..HEAD` (local commits ahead)
4. Compare `git rev-list --count HEAD..origin/master` (remote commits ahead)
5. Check for merge conflicts in `git status`
6. Read latest sync log for `LastPullTime`

**Health Determination**:
```
IsHealthy = true if:
  - No unresolved conflicts
  - Not more than 10 commits behind remote
  - Sync logs show no repeated failures
```

**Display Format (default)**:
```
Sync Status
===========
Last Pull:        2 hours ago
Pending Changes:  3 files (2 modified, 1 added)
Local Commits:    1 (ahead of remote)
Remote Commits:   0 (in sync)
Conflicts:        None
Health:           ✓ Healthy

Next Action: Run Sync-Agents to push changes
```

**Display Format (-Detailed)**:
```
Sync Status (Detailed)
======================
Last Pull:        2025-10-02 10:00:00
Pending Changes:  3 files
  Modified:
    - agent1.md (last modified: 5 min ago)
    - agent2.md (last modified: 10 min ago)
  Added:
    - agent3.md
  Deleted:
    (none)

Local Commits:    1 commit ahead
  abc123d - "sync: update 2 agent files"

Remote Commits:   0 (in sync)
Conflicts:        None
Health:           ✓ Healthy

Last 5 Sync Operations:
  2025-10-02 09:55:00 | Pull   | Success | 0 files
  2025-10-02 09:45:00 | Commit | Success | 2 files
  2025-10-02 09:30:00 | Push   | Success | 1 commit

Next Action: Run Sync-Agents to push changes
```

**JSON Output (-Json)**:
```json
{
  "lastPullTime": "2025-10-02T08:00:00Z",
  "pendingChanges": 3,
  "localCommits": 1,
  "remoteCommits": 0,
  "hasConflicts": false,
  "isHealthy": true,
  "modifiedFiles": ["agent1.md", "agent2.md"],
  "untrackedFiles": ["agent3.md"],
  "deletedFiles": [],
  "nextAction": "Run Sync-Agents to push changes"
}
```

## Error Handling

| Error Condition | Exit Code | Behavior |
|-----------------|-----------|----------|
| No Git repository | 1 | Display error, suggest initializing repo |
| Network timeout (fetch) | 0 | Continue with local status, show warning |
| Corrupted log files | 0 | Show status without historical data, log warning |

## Examples

**Example 1: Clean status**
```powershell
PS> Get-SyncStatus

Sync Status
===========
Last Pull:        5 minutes ago
Pending Changes:  0 files
Local Commits:    0 (in sync)
Remote Commits:   0 (in sync)
Conflicts:        None
Health:           ✓ Healthy

Next Action: All up to date!
```

**Example 2: Pending changes**
```powershell
PS> Get-SyncStatus

Sync Status
===========
Last Pull:        1 hour ago
Pending Changes:  5 files (3 modified, 2 added)
Local Commits:    0
Remote Commits:   0
Conflicts:        None
Health:           ✓ Healthy

Next Action: Run Sync-Agents to commit and push changes
```

**Example 3: Behind remote (needs pull)**
```powershell
PS> Get-SyncStatus

Sync Status
===========
Last Pull:        24 hours ago
Pending Changes:  0 files
Local Commits:    0
Remote Commits:   10 (behind remote)
Conflicts:        None
Health:           ⚠ Out of sync

WARNING: You are 10 commits behind remote
Next Action: Run Sync-Agents to pull latest changes
```
