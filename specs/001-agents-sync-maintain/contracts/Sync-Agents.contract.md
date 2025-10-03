# Contract: Sync-Agents Command

**Command**: `Sync-Agents`
**Purpose**: Main synchronization command that pulls latest changes, validates local agent files, commits changes, and pushes to remote.

## Inputs

**Parameters**:
- `-Force` (switch, optional): Skip confirmation prompts for destructive operations
- `-DryRun` (switch, optional): Show what would be synced without making changes
- `-Message` (string, optional): Custom commit message (overrides auto-generated)
- `-Path` (string, optional): Specific file or directory to sync (default: all agent files)

**Preconditions**:
- Git repository must be initialized
- Remote origin must be configured
- User must have Git credentials configured (gh auth or git credentials)

## Outputs

**Success Response** (Exit Code 0):
```powershell
[PSCustomObject]@{
    Status = "Success"
    Operation = "Sync"
    FilesPulled = 3
    FilesModified = 2
    FilesDeleted = 0
    CommitHash = "abc123def456..."
    PushStatus = "Success"
    Duration = [TimeSpan]::FromSeconds(3.5)
}
```

**Conflict Response** (Exit Code 1):
```powershell
[PSCustomObject]@{
    Status = "Conflict"
    ConflictingFiles = @("agent1.md", "agent2.md")
    Message = "Merge conflicts detected. Run Resolve-SyncConflict for guidance."
    SuggestedAction = "git pull --rebase or git pull --no-rebase"
}
```

**Validation Failure** (Exit Code 2):
```powershell
[PSCustomObject]@{
    Status = "ValidationFailed"
    InvalidFiles = @(
        @{ File = "bad-agent.md"; Errors = @("Missing required field: name", "Invalid JSON syntax") }
    )
    Message = "Fix validation errors before committing"
}
```

**Network Failure** (Exit Code 3):
```powershell
[PSCustomObject]@{
    Status = "NetworkError"
    Message = "Cannot reach remote repository. Check internet connection."
    LocalChangesPreserved = $true
    SuggestedAction = "Work offline. Changes will sync when connection restored."
}
```

## Behavior

**Pre-Sync (Pull Phase)**:
1. Check for network connectivity to remote
2. Execute `git pull origin master`
3. If conflicts detected, return Conflict response
4. If pull fails due to network, continue with local validation

**Validation Phase**:
1. Scan for modified/untracked agent files
2. Validate each file (syntax, required fields)
3. Scan for sensitive data (API keys, tokens)
4. If validation fails, return ValidationFailed response

**Commit Phase**:
1. If no changes detected, skip commit
2. Generate commit message: "sync: update N agent files\n\n- file1.md (modified)\n- file2.md (added)"
3. Stage all valid files
4. If deletions detected and not `-Force`, prompt for confirmation
5. Create commit

**Push Phase**:
1. Execute `git push origin master`
2. If push rejected (behind remote), return Conflict response
3. If network unavailable, warn user but preserve local commit

**Logging**:
- All operations logged to `logs/sync-YYYY-MM-DD.json`
- Failed operations include full error details

## Error Handling

| Error Condition | Exit Code | User Action |
|-----------------|-----------|-------------|
| Merge conflict | 1 | Run `Resolve-SyncConflict` |
| Validation failure | 2 | Fix agent files, re-run sync |
| Network error | 3 | Work offline, retry later |
| Git auth failure | 4 | Run `gh auth login` |
| Repository corrupted | 5 | Contact support, restore from remote |

## Examples

**Example 1: Successful sync**
```powershell
PS> Sync-Agents

Status         : Success
FilesPulled    : 0
FilesModified  : 2
FilesDeleted   : 0
CommitHash     : abc123def
PushStatus     : Success
Duration       : 00:00:03.5
```

**Example 2: Dry run**
```powershell
PS> Sync-Agents -DryRun

[DRY RUN] Would pull from remote
[DRY RUN] Would commit 3 files:
  - agent-new.md (added)
  - agent-updated.md (modified)
  - agent-old.md (deleted)
[DRY RUN] Would push to remote
No changes made.
```

**Example 3: Validation failure**
```powershell
PS> Sync-Agents

Status          : ValidationFailed
InvalidFiles    : @{File=bad-agent.md; Errors=Missing required field: name}
Message         : Fix validation errors before committing

ERROR: Cannot sync. Fix errors and retry.
```
