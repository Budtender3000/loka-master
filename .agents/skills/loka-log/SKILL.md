---
name: loka-log
description: Use this skill when the USER explicitly requests session logging, session end, status capture, handover, or a query of past session logs. Writes factual session logs to .agents/memories/sessions/. Delegated handover and query modes are documented under references/.
type: skill
version: 0.2.7
owner: USER
---

# LOKA-LOG

Role: ARCHIVIST

Goal: Preserve session continuity through an immutable factual session ledger.

---

## Scope

Workspace skill. Write target depends strictly on the current execution context and explicit USER intent:

- Project Context (Default): When operating inside a project repository, the target is always `<workspace>/.agents/memories/`.
- Global Context: The target `~/.agents/memories/` is used ONLY if operating outside a repo entirely, or if explicitly requested by the USER.

Determine target path (`<workspace>`) before any write action.

---

## Ground Rules

- **MAINTAIN** neutral tone: facts only, no persona, no opinions, no emojis.
- **ACTIVATE** this skill only on explicit session logging, session-end, handover, or log-query signals from the USER.
- **DO NOT** create commits, tags, pushes, reverts, or stashes.
- **WRITE** only to the context-resolved `memories/sessions/` (or `memories/handovers/` for delegated handovers).
- **DO NOT** write to parent repos or other projects.
- **FOLLOW** `./AGENTS.md` and active rules before any write action in this repo.

---

## MODE A: SESSION END

Trigger: only when the USER explicitly requests session logging, status capture, or session end.

### Protocol

#### Step 0 - Reality Check

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && { git status --short --branch; git rev-parse --short HEAD 2>/dev/null || echo "initial_commit"; } || echo "No git repository"
```

- **RECORD** actual Git state.
- **DO NOT** proceed on assumption.

#### Step 1 - Context Check

- **TARGET** `<workspace>/.agents/memories` by default inside a project repository.
- **TARGET** `~/.agents/memories` if operating outside a repo entirely or if explicitly requested by USER.
- **STOP** and ask USER if context remains ambiguous.

#### Step 2 - Directory Check & Initialization

- **EXECUTE** `mkdir -p <workspace>/.agents/memories/sessions` if target is local (`<workspace>/.agents/memories`) and missing.
- **STOP** without creating directories if target is global (`~/.agents/memories`) and missing, then inform USER and wait.

#### Step 3 - Extract Facts & State Derivation

- **REVIEW** the complete session history.
- **STRIP** chatter, opinions, and style commentary.
- **EXTRACT** intent, scope, executed actions (including validation commands and outcomes), changed files, binding decisions, explicit approvals, observed workspace state, risks or errors for `risks_or_errors`, and confirmed remaining work for `followups`.
- **RECORD** only files actually read, commands actually run, and Git states actually observed.
- **KEEP** unknown or unverified values explicit; never convert assumptions or plans into facts.
- **DERIVE** `session_id`: match the filename stem exactly (`YYYY-MM-DD_HH-MM-sessionlog`).
- **DERIVE** `conversation_id`: populated from the active conversation UUID provided in the environment.
- **DERIVE** `agent`: populated with the active agent identifier or model name.
- **DERIVE** `governance_audit`: populated with `{ "violations": [] }` or actual observed rule/contract violations.
- **DERIVE** `last_task`:
  - `id`: task identifier or short label.
  - `status`:
    - `closed`: Task was successfully completed and verified in this session.
    - `ongoing`: Work on the task is currently active or in progress.
    - `open`: Task was requested, planned, or blocked without completion.
  - `description`: concise summary of the last task.
- **DERIVE** structured `workspace_state`:
  - If inside a Git repository:
    - `branch`: current Git branch name.
    - `commit`: current short commit hash (or `"initial_commit"` if repository has no commits).
    - `working_tree`: `clean`, `dirty`, or `X files modified`.
    - `git_status`: observed git status summary string.
  - If Git is unavailable (`No git repository`):
    - `branch`: `null`.
    - `commit`: `null`.
    - `working_tree`: `"no_git"`.
    - `git_status`: `"No git repository"`.

#### Step 4 - Write JSON Log

- **READ** template from `templates/sessionlog-template.json` (relative to skill root).
- **RESOLVE** all top-level metadata placeholders (`session_id`, `conversation_id`, `agent`, `governance_audit`) dynamically before writing.
- **WRITE** output to `<workspace>/.agents/memories/sessions/YYYY-MM-DD_HH-MM-sessionlog.json` (or `~/.agents/memories/sessions/...` if global).
- **USE** local time (`Europe/Berlin`) for timestamps and filename.
- **HANDLE** filename collisions by appending a unique seconds suffix or counter.
- **SET** `"template": false` in every written log.
- **PRESERVE** empty arrays and objects according to template schema without omitting keys.
- **RECORD** actual relative file paths in `artifacts.created`, `artifacts.modified`, and `artifacts.removed`, never placeholder strings.

#### Step 5 - Confirm Neutrally

- **REPORT** status neutrally:

```text
[LOKA-LOG]
Session Log saved -> <workspace>/.agents/memories/sessions/YYYY-MM-DD_HH-MM-sessionlog.json

## Last Task
- `[TASK-ID]` [closed | open | ongoing]
  [Short Description]

## Repository State
- Branch: `[BRANCH_NAME | none]`
- Commit: `[COMMIT_HASH | none]`
- Working Tree: `[clean | dirty | X files modified | no_git]`

## Open Points / Blockers
- [Current blocker or unresolved point]
```

---

## DELEGATED MODES

### Mode B: Log Query

- **READ** `references/log-query.md` only when USER explicitly requests to search, review, or trace session logs.

### Mode C: Session Handover

- **READ** `references/session-handover.md` only when USER explicitly requests a session handover, context export, or handover capture.

---

## Constraints

- **ENSURE** Mode A is strictly factual: never disguise interpretation as a decision.
- **TREAT** session JSON files as immutable evidence ledgers.
- **AVOID** hallucinations: record only actual session history, Git status, and files read.
- **MAINTAIN** structure fidelity against `templates/sessionlog-template.json`.
- **NEVER** edit existing logs after creation; logs are append-only.
- **PREVENT** overwriting existing logs on filename collision.
- **KEEP** document paths relative inside skill outputs and instructions.
- **DO NOT** commit or revert dirty patches unless explicitly requested by USER.
