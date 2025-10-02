# Tasks: Agent Synchronization System

**Input**: Design documents from `specs/001-agents-sync-maintain/`
**Prerequisites**: plan.md, research.md, data-model.md, contracts/, quickstart.md

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → SUCCESS: Tech stack: PowerShell 7.0+, Git, Pester
2. Load optional design documents:
   → data-model.md: 4 entities (AgentFile, SyncOperation, Conflict, SyncLog)
   → contracts/: 3 CLI commands (Sync-Agents, Get-SyncStatus, Resolve-SyncConflict)
   → research.md: PowerShell module architecture, TDD workflow
   → quickstart.md: 9 user scenarios for integration tests
3. Generate tasks by category:
   → Setup: 5 tasks (project structure, dependencies, testing framework)
   → Tests: 15 tasks (3 contract + 9 integration + 3 unit)
   → Core: 11 tasks (4 models + 4 services + 3 CLI)
   → Integration: 4 tasks (logging, file watcher, .gitignore, error handling)
   → Polish: 6 tasks (unit tests, performance, quickstart validation, docs)
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T041)
6. Generate dependency graph
7. Create parallel execution examples
8. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Single project**: `src/`, `tests/` at repository root
- Paths assume single project structure per plan.md

---

## Phase 3.1: Setup
- [ ] **T001** Create project directory structure (src/models/, src/services/, src/cli/, src/lib/, tests/contract/, tests/integration/, tests/unit/, logs/)
- [ ] **T002** Initialize PowerShell module manifest (AgentSync.psd1) with dependencies on Pester 5.0+
- [ ] **T003** [P] Create .gitignore file with patterns for logs/, *.log, .env, credentials.json, *.key
- [ ] **T004** [P] Configure Pester test framework (PesterConfiguration.ps1) with output formatting and code coverage
- [ ] **T005** [P] Create README.md in repository root documenting installation, usage, and dependencies

---

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests [P]
- [ ] **T006** [P] Contract test for GitService in tests/contract/GitService.Tests.ps1 - Test git pull, commit, push, status operations
- [ ] **T007** [P] Contract test for ValidationService in tests/contract/ValidationService.Tests.ps1 - Test file validation, syntax checking, credential scanning
- [ ] **T008** [P] Contract test for SyncService in tests/contract/SyncService.Tests.ps1 - Test complete sync workflow (pull → validate → commit → push)

### Integration Tests [P]
- [ ] **T009** [P] Integration test Scenario 1 (Start Work - Pull Latest) in tests/integration/StartWork.Tests.ps1
- [ ] **T010** [P] Integration test Scenario 2 (Create New Agent) in tests/integration/CreateAgent.Tests.ps1
- [ ] **T011** [P] Integration test Scenario 3 (Modify Existing Agent) in tests/integration/ModifyAgent.Tests.ps1
- [ ] **T012** [P] Integration test Scenario 4 (Delete Agent File) in tests/integration/DeleteAgent.Tests.ps1
- [ ] **T013** [P] Integration test Scenario 5 (Check Status) in tests/integration/CheckStatus.Tests.ps1
- [ ] **T014** [P] Integration test Scenario 6 (Handle Merge Conflict) in tests/integration/MergeConflict.Tests.ps1
- [ ] **T015** [P] Integration test Scenario 7 (Auto-Resolve Conflict) in tests/integration/AutoResolve.Tests.ps1
- [ ] **T016** [P] Integration test Scenario 8 (Work Offline) in tests/integration/OfflineWork.Tests.ps1
- [ ] **T017** [P] Integration test Scenario 9 (Fix Validation Errors) in tests/integration/ValidationErrors.Tests.ps1

### Unit Tests [P]
- [ ] **T018** [P] Unit tests for Logger module in tests/unit/Logger.Tests.ps1 - Test log formatting, rotation, filtering
- [ ] **T019** [P] Unit tests for FileWatcher module in tests/unit/FileWatcher.Tests.ps1 - Test file change detection, event handling
- [ ] **T020** [P] Unit tests for AgentFile model in tests/unit/AgentFile.Tests.ps1 - Test validation rules, state transitions

---

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Models [P]
- [ ] **T021** [P] AgentFile model class in src/models/AgentFile.psm1 - Properties: FilePath, FileName, LastModified, GitStatus, ContentHash, IsValid, ValidationErrors
- [ ] **T022** [P] SyncOperation model class in src/models/SyncOperation.psm1 - Properties: OperationId, OperationType, Timestamp, Status, AffectedFiles, CommitMessage, CommitHash, ErrorMessage, Duration
- [ ] **T023** [P] Conflict model class in src/models/Conflict.psm1 - Properties: ConflictId, FilePath, DetectedAt, LocalChanges, RemoteChanges, ResolutionStatus, ResolutionStrategy, ResolvedAt
- [ ] **T024** [P] SyncLog model class in src/models/SyncLog.psm1 - Properties: LogId, Operations, SessionStart, SessionEnd, TotalFiles, SuccessCount, FailureCount, ConflictCount

### Services (Sequential - Dependencies)
- [ ] **T025** GitService in src/services/GitService.psm1 - Functions: Invoke-GitPull, Invoke-GitCommit, Invoke-GitPush, Get-GitStatus, Test-NetworkConnectivity
- [ ] **T026** ValidationService in src/services/ValidationService.psm1 - Functions: Test-AgentFile, Test-Syntax, Find-Credentials, Get-ValidationErrors (depends on AgentFile model)
- [ ] **T027** ConflictService in src/services/ConflictService.psm1 - Functions: Get-Conflicts, Resolve-ConflictAuto, Get-ResolutionGuidance (depends on Conflict model, GitService)
- [ ] **T028** SyncService in src/services/SyncService.psm1 - Main orchestration: Sync-Repository, Get-SyncStatus, Write-SyncLog (depends on all models and services)

### CLI Commands (Sequential - Depends on Services)
- [ ] **T029** Sync-Agents command in src/cli/Sync-Agents.ps1 - Parameters: -Force, -DryRun, -Message, -Path; Calls SyncService
- [ ] **T030** Get-SyncStatus command in src/cli/Get-SyncStatus.ps1 - Parameters: -Detailed, -Json; Calls SyncService.Get-SyncStatus
- [ ] **T031** Resolve-SyncConflict command in src/cli/Resolve-SyncConflict.ps1 - Parameters: -FilePath, -Strategy, -AutoResolve; Calls ConflictService

---

## Phase 3.4: Integration
- [ ] **T032** Logger utility in src/lib/Logger.psm1 - Functions: Write-SyncLog, Get-LogPath, Rotate-Logs; Integrate with all services
- [ ] **T033** FileWatcher utility in src/lib/FileWatcher.psm1 - Functions: Start-FileWatcher, Stop-FileWatcher, Register-ChangeHandler; Integrate with Sync-Agents
- [ ] **T034** Error handling middleware - Add Try-Catch blocks to all services, return structured error objects with exit codes
- [ ] **T035** Update .gitignore patterns - Add logs/, *.log, .env, credentials.json, .claude/settings.local.json based on FR-013

---

## Phase 3.5: Polish
- [ ] **T036** [P] Performance optimization - Add caching for git status (5 second TTL), optimize file scanning for agent directories only
- [ ] **T037** [P] Quickstart validation - Run all 9 scenarios from quickstart.md manually, verify outputs match expected
- [ ] **T038** [P] Documentation - Create inline help comments for all public functions using PowerShell comment-based help format
- [ ] **T039** [P] Security audit - Run Find-Credentials against all source files to ensure no hardcoded secrets
- [ ] **T040** Unit test coverage - Ensure all models, services, and utilities have >80% code coverage via Pester
- [ ] **T041** End-to-end smoke test - Create tests/E2E.Tests.ps1 that runs complete workflow: create agent → sync → modify → sync → delete → sync

---

## Dependencies

### Setup Dependencies
- T001 (directory structure) blocks all other tasks

### Test Dependencies (TDD - All tests before implementation)
- T006-T020 (all tests) must complete and FAIL before T021-T031 (implementation)
- Tests are independent of each other [P]

### Implementation Dependencies
```
Models (T021-T024) [P]
  ↓
GitService (T025)
  ↓
ValidationService (T026) + ConflictService (T027) [can run in parallel if models done]
  ↓
SyncService (T028) - depends on all above services
  ↓
CLI Commands (T029-T031) [sequential, all depend on SyncService]
  ↓
Integration (T032-T035) - logging, file watcher, error handling
```

### Polish Dependencies
- T036-T041 all depend on completed implementation (T021-T035)
- Can run in parallel [P] once implementation done

---

## Parallel Execution Examples

### Example 1: Setup Phase (After T001 completes)
```powershell
# Launch T002-T005 in parallel
Task: "Initialize PowerShell module manifest AgentSync.psd1"
Task: "Create .gitignore file with log and credential patterns"
Task: "Configure Pester test framework PesterConfiguration.ps1"
Task: "Create README.md with installation and usage docs"
```

### Example 2: Contract Tests (TDD Phase)
```powershell
# Launch T006-T008 together
Task: "Write contract test for GitService in tests/contract/GitService.Tests.ps1"
Task: "Write contract test for ValidationService in tests/contract/ValidationService.Tests.ps1"
Task: "Write contract test for SyncService in tests/contract/SyncService.Tests.ps1"
```

### Example 3: Integration Tests (TDD Phase)
```powershell
# Launch T009-T017 together (9 scenarios)
Task: "Write integration test for Start Work scenario in tests/integration/StartWork.Tests.ps1"
Task: "Write integration test for Create New Agent in tests/integration/CreateAgent.Tests.ps1"
Task: "Write integration test for Modify Agent in tests/integration/ModifyAgent.Tests.ps1"
Task: "Write integration test for Delete Agent in tests/integration/DeleteAgent.Tests.ps1"
Task: "Write integration test for Check Status in tests/integration/CheckStatus.Tests.ps1"
Task: "Write integration test for Merge Conflict in tests/integration/MergeConflict.Tests.ps1"
Task: "Write integration test for Auto-Resolve Conflict in tests/integration/AutoResolve.Tests.ps1"
Task: "Write integration test for Offline Work in tests/integration/OfflineWork.Tests.ps1"
Task: "Write integration test for Validation Errors in tests/integration/ValidationErrors.Tests.ps1"
```

### Example 4: Model Creation (After tests written)
```powershell
# Launch T021-T024 together
Task: "Create AgentFile model class in src/models/AgentFile.psm1 with validation rules"
Task: "Create SyncOperation model class in src/models/SyncOperation.psm1"
Task: "Create Conflict model class in src/models/Conflict.psm1"
Task: "Create SyncLog model class in src/models/SyncLog.psm1"
```

### Example 5: Polish Phase
```powershell
# Launch T036-T041 together (after implementation complete)
Task: "Add performance optimizations - caching and scoped file scanning"
Task: "Run all quickstart.md scenarios and verify outputs"
Task: "Add inline help comments to all public functions"
Task: "Run security audit for hardcoded credentials"
Task: "Measure and improve unit test coverage to >80%"
Task: "Create end-to-end smoke test in tests/E2E.Tests.ps1"
```

---

## Notes

### TDD Workflow (CRITICAL)
1. Write tests T006-T020 first
2. Run tests - they MUST fail (no implementation yet)
3. Implement T021-T031 to make tests pass
4. Run tests again - they should pass
5. Refactor if needed, tests still pass

### Parallel Execution Rules
- **[P] tasks** = different files, no dependencies
- Tasks without [P] = same file or sequential dependency
- Always check dependencies before launching parallel tasks

### Commit Strategy
- Commit after each task completes
- Use descriptive commit messages: `feat(task-ID): brief description`
- Run tests before committing implementation tasks

### Task Specificity
Each task includes:
- Exact file path
- Key functions or properties to implement
- Dependencies on other tasks
- Reference to contract/data-model for requirements

---

## Validation Checklist

**Before considering tasks complete**:
- [x] All contracts have corresponding tests (T006-T008)
- [x] All entities have model tasks (T021-T024)
- [x] All user scenarios have integration tests (T009-T017)
- [x] All tests come before implementation (T006-T020 before T021-T031)
- [x] Parallel tasks truly independent (checked against data model)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task
- [x] Dependencies clearly documented

---

## Task Count Summary
- **Setup**: 5 tasks (T001-T005)
- **Tests First**: 15 tasks (T006-T020) - 3 contract + 9 integration + 3 unit
- **Core Implementation**: 11 tasks (T021-T031) - 4 models + 4 services + 3 CLI
- **Integration**: 4 tasks (T032-T035)
- **Polish**: 6 tasks (T036-T041)
- **TOTAL**: 41 tasks

**Parallel Opportunities**:
- Setup: 4 tasks [P] (T002-T005)
- Tests: 15 tasks [P] (T006-T020)
- Models: 4 tasks [P] (T021-T024)
- Polish: 6 tasks [P] (T036-T041)
- **Total [P]**: 29 tasks can run in parallel (71% of all tasks)

---

## Ready for Execution

This task list is complete and ready for implementation. Each task:
- ✅ Has specific file path
- ✅ References design documents for requirements
- ✅ Includes clear success criteria
- ✅ Follows TDD workflow (tests first)
- ✅ Marks parallelizable tasks with [P]
- ✅ Documents dependencies

**Next Step**: Begin with T001 (directory structure), then launch T002-T005 in parallel.
