<!--
SYNC IMPACT REPORT
==================
Version Change: N/A (initial version) → 1.0.0
Modified Principles: N/A (initial constitution)
Added Sections:
  - Purpose & Version Control Rationale
  - Collaboration Through Git
  - Autonomy & Boundaries
  - Reliability & Sync Integrity
  - Security & Secrets Management
  - Evolution & Amendment Process
Templates Requiring Updates:
  ✅ plan-template.md - Constitution Check section will reference these principles
  ✅ spec-template.md - No changes required (implementation-agnostic)
  ✅ tasks-template.md - No changes required (task structure aligns with principles)
Follow-up TODOs: None
-->

# Claude Agents Project Constitution

## Core Principles

### I. Purpose & Version Control Rationale
**Claude Code agents are specialized AI assistants that enhance development workflows.** This project maintains a centralized GitHub repository (`claude-agents`) as the single source of truth for all agent specifications, ensuring:
- **Consistency**: All machines access identical agent definitions
- **Traceability**: Complete change history through Git commits
- **Portability**: Any authorized machine can clone, sync, and contribute
- **Collaboration**: Multiple developers can propose and review agent improvements

**Rationale**: Without version control, agents diverge across machines, causing unpredictable behavior and preventing collaborative improvement. Git provides proven conflict resolution and change tracking mechanisms.

### II. Collaboration Through Git
**All agent changes MUST flow through the GitHub repository using standard Git workflows:**
- **MUST** pull latest changes before modifying any agent file (`git pull origin master`)
- **MUST** commit changes with descriptive messages explaining modifications to agent behavior
- **MUST** push changes to remote repository after local commits (`git push origin master`)
- **SHOULD** create feature branches for experimental agents or major revisions
- **MUST** resolve merge conflicts following Git best practices (manual review, preserve intent)

**Rationale**: Git enforces discipline around change management. Skipping pulls causes merge conflicts; unclear commit messages hinder troubleshooting; unpushed changes isolate improvements from other machines.

### III. Autonomy & Boundaries
**Each agent MUST be self-contained and non-interfering:**
- **MUST** maintain one specification file per agent (separate concerns)
- **MUST NOT** modify other agents' files without explicit cross-agent coordination
- **MUST** declare dependencies on shared utilities or templates explicitly
- **MUST** use unique, descriptive agent names to prevent namespace collisions
- **SHOULD** document agent purpose, capabilities, and usage examples in specification

**Rationale**: Agents that interfere with each other create debugging nightmares. Clear boundaries enable parallel development and prevent cascading failures when one agent is updated.

### IV. Reliability & Sync Integrity
**The repository MUST remain functional and synchronized across all machines:**
- **MUST** validate agent files before committing (syntax, required fields, no malformed configs)
- **MUST NOT** push commits that break core synchronization workflows (e.g., corrupted Git metadata)
- **MUST** test agents locally before pushing to prevent breaking other machines
- **MUST** provide clear error messages when sync operations fail (network, auth, conflicts)
- **SHOULD** maintain a CHANGELOG.md documenting major agent additions/removals

**Rationale**: A broken repository halts all machines. Pre-commit validation and testing prevent propagation of defects. Graceful error handling guides users toward resolution rather than leaving them stuck.

### V. Security & Secrets Management
**Sensitive data MUST NEVER be committed to the repository:**
- **MUST NOT** include API tokens, keys, passwords, or credentials in agent files
- **MUST** use environment variables for secrets (referenced in agent specs, loaded at runtime)
- **MUST** add sensitive file patterns to `.gitignore` (e.g., `.env`, `credentials.json`, `*.key`)
- **SHOULD** provide `.env.example` templates showing required variables without actual values
- **MUST** revoke and rotate any credentials accidentally committed to history

**Rationale**: Git history is permanent and public repositories expose secrets to the internet. Environment variables separate configuration from code, enabling safe sharing while protecting credentials.

### VI. Evolution & Amendment Process
**This constitution governs all project development and can only be amended through explicit user approval:**
- **MUST** document proposed constitutional changes in a pull request or commit message
- **MUST** obtain explicit user/maintainer approval before merging constitutional amendments
- **MUST** increment constitution version following semantic versioning (MAJOR.MINOR.PATCH)
- **MUST** update dependent templates (plan, spec, tasks) when principles change
- **SHOULD** provide migration guidance when amendments affect existing agents

**Rationale**: The constitution is the project's legal framework. Unilateral changes by AI or individual contributors could violate core principles. Versioning tracks governance evolution and enables rollback if amendments prove problematic.

## Governance

**This constitution supersedes all ad-hoc practices and undocumented conventions.**

**Amendment Procedure**:
1. Propose change via commit/PR with justification
2. Review impact on existing agents and workflows
3. Obtain explicit user approval
4. Update constitution version and sync impact report
5. Update dependent templates and documentation
6. Communicate changes to all repository users

**Compliance Verification**:
- All commits MUST be reviewed against constitutional principles during PR review
- Complexity that violates principles MUST be justified in plan.md Complexity Tracking section
- Agents violating security principles MUST be rejected or remediated immediately

**Runtime Development Guidance**: Consult agent-specific files (e.g., `CLAUDE.md`, `.github/copilot-instructions.md`) for implementation patterns that comply with these principles.

**Version**: 1.0.0 | **Ratified**: 2025-10-02 | **Last Amended**: 2025-10-02
