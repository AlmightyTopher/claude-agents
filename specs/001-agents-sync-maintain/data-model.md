# Data Model: Agent Synchronization System

## Entity: AgentFile

**Description**: Represents a single agent specification file in the repository.

**Fields**:
- `FilePath` (string): Absolute path to the agent file
- `FileName` (string): Name of the file (e.g., "my-agent.md")
- `LastModified` (datetime): Timestamp of last modification
- `GitStatus` (enum): Current Git status [Untracked, Modified, Staged, Committed, Deleted]
- `ContentHash` (string): SHA-256 hash of file contents for change detection
- `IsValid` (boolean): Whether file passes validation
- `ValidationErrors` (string[]): Array of validation error messages

**Relationships**:
- One AgentFile can have many SyncOperations (1:N)
- AgentFile referenced by Conflicts when merge conflicts occur

**Validation Rules**:
- `FilePath` must exist and be readable
- `FileName` must follow pattern `*.md`, `*.ps1`, `*.psm1`, or `*.json`
- File size must be < 10MB (prevents accidentally committing large files)
- Content must be valid UTF-8 text

**State Transitions**:
```
Untracked → Staged (git add)
Modified → Staged (git add)
Staged → Committed (git commit)
Committed → Modified (file edited)
Modified → Deleted (file removed)
```

---

## Entity: SyncOperation

**Description**: Represents a single synchronization action (pull, commit, push).

**Fields**:
- `OperationId` (guid): Unique identifier for this operation
- `OperationType` (enum): Type of operation [Pull, Commit, Push, Status]
- `Timestamp` (datetime): When the operation started
- `Status` (enum): Result of operation [Success, Failed, Skipped, InProgress]
- `AffectedFiles` (string[]): List of file paths affected by this operation
- `CommitMessage` (string): Generated commit message (for Commit operations)
- `CommitHash` (string): Git commit SHA (for successful commits)
- `ErrorMessage` (string): Error details if Status = Failed
- `Duration` (timespan): How long the operation took

**Relationships**:
- SyncOperation references multiple AgentFiles (N:M via AffectedFiles)
- SyncOperation logged to SyncLog

**Validation Rules**:
- `OperationType` must be valid enum value
- `CommitMessage` required when OperationType = Commit
- `CommitMessage` must be 10-500 characters
- `CommitHash` must match pattern `[0-9a-f]{40}` (SHA-1)

**State Transitions**:
```
InProgress → Success (operation completes)
InProgress → Failed (error occurs)
InProgress → Skipped (pre-condition not met, e.g., nothing to commit)
```

---

## Entity: Conflict

**Description**: Represents a Git merge conflict that requires user resolution.

**Fields**:
- `ConflictId` (guid): Unique identifier
- `FilePath` (string): Path to conflicting file
- `DetectedAt` (datetime): When conflict was detected
- `LocalChanges` (string): Summary of local modifications
- `RemoteChanges` (string): Summary of remote modifications
- `ResolutionStatus` (enum): Current status [Unresolved, Resolved, Abandoned]
- `ResolutionStrategy` (enum): How user chose to resolve [Merge, Rebase, KeepLocal, KeepRemote, Manual]
- `ResolvedAt` (datetime): When user resolved the conflict

**Relationships**:
- Conflict references one AgentFile
- Multiple Conflicts can exist for same file (historical)

**Validation Rules**:
- `FilePath` must reference an existing AgentFile
- `ResolutionStrategy` required when ResolutionStatus = Resolved
- `ResolvedAt` must be after `DetectedAt`

**State Transitions**:
```
Unresolved → Resolved (user resolves conflict)
Unresolved → Abandoned (user reverts changes)
Resolved → Unresolved (resolution fails, conflict reoccurs)
```

---

## Entity: SyncLog

**Description**: Chronological record of all sync operations for auditing and troubleshooting.

**Fields**:
- `LogId` (guid): Unique identifier
- `Operations` (SyncOperation[]): Array of sync operations in chronological order
- `SessionStart` (datetime): When sync session began
- `SessionEnd` (datetime): When sync session completed
- `TotalFiles` (int): Number of files processed
- `SuccessCount` (int): Number of successful operations
- `FailureCount` (int): Number of failed operations
- `ConflictCount` (int): Number of conflicts detected

**Relationships**:
- SyncLog contains multiple SyncOperations (1:N)
- One SyncLog per sync session

**Validation Rules**:
- `SessionEnd` must be after `SessionStart`
- `SuccessCount + FailureCount` should equal count of Operations
- Log file size should not exceed 10MB (rotate when exceeded)

**Persistence**:
- Stored as JSON file in `logs/sync-YYYY-MM-DD.json`
- Rotated daily
- Excluded from Git via .gitignore

---

## Derived Data / Computed Properties

### SyncStatus (computed from current repository state)
- `LastPullTime` (datetime): Most recent successful pull operation
- `PendingChanges` (int): Count of modified/untracked files
- `LocalCommits` (int): Commits ahead of remote
- `RemoteCommits` (int): Commits behind remote
- `HasConflicts` (boolean): Whether unresolved conflicts exist
- `IsHealthy` (boolean): True if no conflicts and synchronized with remote

---

## Data Flow

```
1. File Change Detected
   → Create/Update AgentFile entity
   → Validate file (populate ValidationErrors)

2. Sync Operation Triggered
   → Create SyncOperation (Status = InProgress)
   → Execute Git command
   → Update SyncOperation (Status = Success/Failed)
   → Append to SyncLog

3. Conflict Detected
   → Create Conflict entity
   → Block push operation
   → Provide resolution guidance

4. User Resolves Conflict
   → Update Conflict (ResolutionStatus = Resolved)
   → Retry sync operation

5. Query Sync Status
   → Read latest SyncLog
   → Compute derived SyncStatus properties
   → Display to user
```

---

## Indexing Strategy (for JSON logs)

Primary access patterns:
- Retrieve operations by date range (SessionStart)
- Find failed operations (Status = Failed)
- List conflicts for specific file (FilePath)
- Count operations by type (OperationType)

JSON structure optimized for sequential read:
```json
{
  "logId": "guid",
  "sessionStart": "2025-10-02T10:00:00Z",
  "sessionEnd": "2025-10-02T10:00:05Z",
  "operations": [
    { "operationType": "Pull", "status": "Success", ... },
    { "operationType": "Commit", "status": "Success", ... }
  ]
}
```

Indexing not needed for < 10,000 operations (linear search acceptable).
