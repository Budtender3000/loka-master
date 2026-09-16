# SESSION HANDOVER PROTOCOL

Role: ARCHIVIST (Handover Mode)

## Trigger

- **ACTIVATE** only when the USER explicitly requests a session handover, context export, or handover capture.

## Protocol

### Step 0 - Reality Check

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && { git status --short --branch; git rev-parse --short HEAD 2>/dev/null || echo "initial_commit"; } || echo "No git repository"
```

- **RECORD** actual Git state (`branch`, `commit`, `working_tree`).
- **DO NOT** proceed on assumption.

### Step 1 - Context Check

- **TARGET** `<workspace>/.agents/memories/handovers` by default inside a project repository.
- **TARGET** `~/.agents/memories/handovers` if operating outside a project repo or if explicitly instructed by USER.
- **STOP** and ask USER if context remains ambiguous.

### Step 2 - Directory Check & Initialization

- **RUN** `mkdir -p <workspace>/.agents/memories/handovers` when target is local and missing.
- **STOP** and inform USER when global target (`~/.agents/memories/handovers`) is missing without creating it autonomously.

### Step 3 - Extract Focus & Facts

- **REVIEW** session history and extract verified facts into the designated sections:
  - `What was the task`: Initial request, intent, and objective.
  - `What was analyzed`: Inspected code, documentation, architecture, or environment state.
  - `What was changed`: Exact files created, modified, or removed.
  - `Key decisions`: Binding decisions, approvals, and trade-offs.
  - `Test results`: Executed verification checks, syntax tests, or test runners.
  - `Current state`: Operational readiness and functional status at session boundary.
  - `Repository State`:
    - If inside a Git repository: grounded `branch`, short `commit` hash (or `"initial_commit"`), and `working_tree` (`clean` | `dirty` | `X files modified`) from Step 0.
    - If Git is unavailable (`No git repository`): `branch`: `"none"`, `commit`: `"none"`, `working_tree`: `"no_git"`.
  - `Open items`: Remaining followups, open blockers, or deferred items.
  - `Context for next session`: Practical orientation and resumption pointers for the next session.
- **EXCLUDE** conversational impressions, speculation, or unverified assumptions.

### Step 4 - Write Handover Document

- **USE** the following schema-pure template structure:

````markdown
---
id: YYYY-MM-DD_HH-MM-session-handover
name: SESSION HANDOVER — [Session Topic]
type: session-handover
status: active
description: [Concise single-line description of session scope and outcome]
created: YYYY-MM-DD
owner: [OWNER]
---

# SESSION HANDOVER — [Session Topic]

- **Project:** `[PROJECT_NAME]`
- **Conversation ID:** `[CONVERSATION_ID]`
- **Agent / Model:** `[AGENT_OR_MODEL]`

## What was the task

- [Description of initial request, scope, or goal]

## What was analyzed

- [Findings from code reading, documentation, architecture, or environment inspection]

## What was changed

- [Concrete file modifications, additions, or removals]

## Key decisions

- [Binding architectural, structural, or scope decisions]

## Test results

- [Executed verification commands, syntax checks, test runners, or smoke tests]

## Current state

- [Operational readiness, working functionality, or verified state at session end]

## Repository State

- **Branch:** `[BRANCH_NAME | none]`
- **Commit:** `[COMMIT_HASH | none]`
- **Working Tree:** `[clean | dirty | X files modified | no_git]`

## Open items

- [Remaining work, followups, or blocked points]

## Context for next session

- [Essential orientation, starting pointers, and context for the resuming session]

== END OF HANDOVER ==
````

- **RESOLVE** all template placeholders dynamically before writing:
  - `id`: must match the filename stem exactly without `.md`.
  - `name`: must match the level-1 heading verbatim (`SESSION HANDOVER — <Session Topic>`).
  - `description`: concise single-line description of session scope.
  - `created`: current date formatted `YYYY-MM-DD`.
  - `owner`: current workspace owner or pseudonym placeholder, never hardcoding private user handles.
  - `project`: current repository or workspace name.
  - `conversation_id`: active conversation UUID.
  - `agent / model`: active agent or model name.
- **WRITE** output to `<workspace>/.agents/memories/handovers/YYYY-MM-DD_HH-MM-session-handover.md` (or `~/.agents/memories/handovers/...` if global).
- **USE** local time (`Europe/Berlin`) for timestamps and filename.
- **HANDLE** filename collisions by appending a unique counter or seconds suffix.

### Step 5 - Confirm Neutrally

- **REPORT** status neutrally:

```text
[LOKA-LOG HANDOVER]
Session Handover saved -> <workspace>/.agents/memories/handovers/YYYY-MM-DD_HH-MM-session-handover.md
```
