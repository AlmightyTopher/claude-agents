# Contract: Resolve-SyncConflict Command

**Command**: `Resolve-SyncConflict`
**Purpose**: Provides guidance and tools for resolving Git merge conflicts in agent files.

## Inputs

**Parameters**:
- `-FilePath` (string, optional): Specific file to resolve (if omitted, shows all conflicts)
- `-Strategy` (enum, optional): Resolution strategy [Merge, Rebase, KeepLocal, KeepRemote, Manual]
- `-AutoResolve` (switch, optional): Attempt automatic resolution using specified strategy

**Preconditions**:
- Git repository must have active merge conflicts
- User must have permissions to modify conflicting files

## Outputs

**Conflict List** (when no strategy specified):
```powershell
[PSCustomObject]@{
    ConflictCount = 2
    Conflicts = @(
        @{
            FilePath = "agent1.md"
            LocalChanges = "Added new capabilities section"
            RemoteChanges = "Updated examples section"
            CanAutoResolve = $false
            SuggestedStrategy = "Manual"
        },
        @{
            FilePath = "agent2.md"
            LocalChanges = "Fixed typo in description"
            RemoteChanges = "Reformatted whitespace"
            CanAutoResolve = $true
            SuggestedStrategy = "KeepLocal"
        }
    )
    NextSteps = "Review conflicts and choose resolution strategy"
}
```

**Resolution Guidance**:
```powershell
[PSCustomObject]@{
    FilePath = "agent1.md"
    Strategy = "Manual"
    Instructions = @(
        "1. Open agent1.md in your editor"
        "2. Look for conflict markers: <<<<<<< HEAD"
        "3. Choose which version to keep or combine both"
        "4. Remove conflict markers"
        "5. Save the file"
        "6. Run: git add agent1.md"
        "7. Run: Sync-Agents to complete resolution"
    )
    ConflictMarkers = @{
        Start = "<<<<<<< HEAD"
        Divider = "======="
        End = ">>>>>>> origin/master"
    }
}
```

**Auto-Resolution Success** (Exit Code 0):
```powershell
[PSCustomObject]@{
    Status = "Resolved"
    FilePath = "agent2.md"
    Strategy = "KeepLocal"
    Message = "Conflict resolved automatically using KeepLocal strategy"
    NextAction = "Run Sync-Agents to commit resolution"
}
```

**Auto-Resolution Failed** (Exit Code 1):
```powershell
[PSCustomObject]@{
    Status = "Failed"
    FilePath = "agent1.md"
    Strategy = "Merge"
    Message = "Cannot auto-resolve. Manual intervention required."
    Reason = "Overlapping changes in same section"
    FallbackStrategy = "Manual"
}
```

## Behavior

**Conflict Detection**:
1. Execute `git diff --name-only --diff-filter=U` to find conflicting files
2. For each conflict, parse `git diff` to extract local vs remote changes
3. Analyze changes to determine if auto-resolution possible

**Strategy Evaluation**:
- **Merge**: Combine both changes if non-overlapping
- **Rebase**: Replay local commits on top of remote (preserves local as final)
- **KeepLocal**: Discard remote changes, keep local version
- **KeepRemote**: Discard local changes, accept remote version
- **Manual**: User must edit file to resolve

**Auto-Resolution Logic**:
```
If Strategy = KeepLocal:
  git checkout --ours <file>
  git add <file>

If Strategy = KeepRemote:
  git checkout --theirs <file>
  git add <file>

If Strategy = Merge AND changes non-overlapping:
  Attempt 3-way merge
  If successful: git add <file>
  If failed: Fall back to Manual

If Strategy = Rebase:
  git rebase --continue
  (requires prior git pull --rebase)
```

**Conflict Analysis**:
```
CanAutoResolve = true if:
  - Changes are in different sections (no line overlap)
  - One side only has whitespace changes
  - Changes are append-only (no deletions)

CanAutoResolve = false if:
  - Same lines modified by both sides
  - Structural changes (reordering, reformatting)
  - Deletions conflict with modifications
```

## Display Format

**Conflict Summary**:
```
Merge Conflicts Detected
========================
2 files have conflicts that need resolution:

1. agent1.md
   Local:  Added new capabilities section (lines 45-60)
   Remote: Updated examples section (lines 50-55)
   ⚠ Cannot auto-resolve - overlapping changes

2. agent2.md
   Local:  Fixed typo in description (line 12)
   Remote: Reformatted whitespace (lines 10-15)
   ✓ Can auto-resolve using KeepLocal strategy

Resolution Options:
  - Manual:      Edit files to resolve conflicts
  - KeepLocal:   Discard remote changes (use your version)
  - KeepRemote:  Discard local changes (use their version)
  - Merge:       Attempt to combine both changes

Run: Resolve-SyncConflict -FilePath <file> -Strategy <strategy>
```

**Interactive Resolution Prompt** (when `-AutoResolve` not specified):
```
Resolve agent1.md conflict using which strategy?
  [M] Manual (recommended for complex conflicts)
  [L] Keep Local (discard remote changes)
  [R] Keep Remote (discard local changes)
  [S] Skip (resolve later)
  [?] Show diff

Choice:
```

## Error Handling

| Error Condition | Exit Code | Behavior |
|-----------------|-----------|----------|
| No conflicts found | 0 | Display "No conflicts to resolve" |
| File not in conflict | 1 | Error: "File does not have conflicts" |
| Invalid strategy | 1 | Error: "Unknown strategy. Use Merge, Rebase, KeepLocal, KeepRemote, or Manual" |
| Auto-resolve fails | 1 | Fall back to manual guidance |

## Examples

**Example 1: List all conflicts**
```powershell
PS> Resolve-SyncConflict

Merge Conflicts Detected
========================
1 file has conflicts:

agent-sync.md
  Local:  Updated sync logic
  Remote: Added error handling
  ⚠ Cannot auto-resolve

Run: Resolve-SyncConflict -FilePath agent-sync.md -Strategy Manual
```

**Example 2: Auto-resolve with KeepLocal**
```powershell
PS> Resolve-SyncConflict -FilePath agent2.md -Strategy KeepLocal -AutoResolve

Status     : Resolved
FilePath   : agent2.md
Strategy   : KeepLocal
Message    : Conflict resolved using KeepLocal strategy
NextAction : Run Sync-Agents to commit resolution
```

**Example 3: Manual resolution guidance**
```powershell
PS> Resolve-SyncConflict -FilePath agent1.md -Strategy Manual

Manual Resolution Steps
=======================
File: agent1.md

1. Open agent1.md in your editor
2. Find conflict markers:
   <<<<<<< HEAD (your changes)
   ...your code...
   =======
   ...their code...
   >>>>>>> origin/master (remote changes)

3. Edit the file to resolve the conflict:
   - Keep your version, or
   - Keep their version, or
   - Combine both changes

4. Remove ALL conflict markers

5. Save the file

6. Run: git add agent1.md

7. Run: Sync-Agents to complete

Need help? View the diff:
git diff agent1.md
```
