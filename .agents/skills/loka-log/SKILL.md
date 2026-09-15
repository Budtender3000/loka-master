---
name: loka-log
description: Use this skill when the USER explicitly requests session logging, session end, status/context capture, or a query of past session logs, or when a session has exceeded ~40 exchanges or reached a clear task boundary (feature complete, review done, deployment finished) and saving state should be offered. If unsure whether a milestone has been reached, do not activate proactively — wait for an explicit USER signal. Writes factual session logs and active context to .agents/memories/.
type: skill
version: 2.5.0
owner: USER
---

# LOKA-LOG

Role: ARCHIVIST

Goal: Preserve session continuity through a concise current-state summary and an immutable factual session ledger.

---

## Scope

Workspace skill. Write target depends strictly on the current execution context and explicit USER intent:

- **Project Context (Default):** When operating inside a project repository, the target is always `<workspace>/.agents/memories/`.
- **Global Context:** The target `~/.agents/memories/` is used ONLY if operating outside a repo entirely, or if explicitly requested by the USER.

Determine target path (`<workspace>`) before any write action.

---

## Ground Rules

- Archivist Mode is neutral: facts only, no persona, no opinions, no emojis.
- Activate this skill only on explicit logging, session-end, or log-query signals.
- It does not create commits, tags, pushes, reverts, or stashes.
- It writes only to the context-resolved `memories/active_context.md` and `memories/sessions/`.
- Do not write to parent repos or other projects.
- Follow `./AGENTS.md` and the active rules before any write action in this repo.

---

## MODE A: SESSION END

Trigger: only when the user explicitly requests logging, status capture, or session end.

### Protocol

**Step 0 - Reality Check**

```bash
git status --short --branch || echo "No git repository"
```

Record actual Git state. Do not proceed on assumption.

**Step 1 - Context Check**

- If USER explicitly requests global logging, or if operating outside a project repo: target directory is `~/.agents/memories`.
- Otherwise (Default): target directory is `<workspace>/.agents/memories` (checks local workspace or active sub-repository).
- Global fallback (`~/.agents/memories`) is used ONLY when operating outside any workspace or project context.
- If context remains ambiguous: **STOP** - ask USER, do not assume.

**Step 2 - Directory Check & Initialization**

- If target is local (`./.agents/memories`) and missing: Automatically create it via `mkdir -p ./.agents/memories/sessions`. Proceed silently.
- If target is global (`~/.agents/memories`) and missing: **STOP** - do not create, do not proceed. Inform USER and wait.

**Step 3 - Extract facts**

- Review the complete session history.
- Remove chatter, opinions, and style commentary.
- Extract intent, scope, executed actions, changed files, binding decisions, explicit approvals, validation, observed workspace state, risks or errors for `risks_or_errors`, and confirmed remaining work for `followups`.
- Record only files actually read, commands actually run, and Git states actually observed.
- Keep unknown or unverified values explicit; never convert assumptions or plans into facts.

**Step 4 - Write JSON log**

- Structure: Read template from `loka-log/templates/session_log.json` (path relative to the skill root, i.e. the directory containing this `SKILL.md`)
- Target file: `./.agents/memories/sessions/session_YYYY-MM-DD__HH-MM.json` (or `~/.agents/memories/sessions/...` if global)
- Time rule: filename and log timestamps use local time (`Europe/Berlin`), including daylight-saving or winter time.
- On filename collision, create a unique new file with a seconds suffix or counter.
- Format: ISO8601 with timezone offset.
- Set `"template": false` in every written log - never carry over the template marker.
- Treat the JSON as a dry evidence ledger: concise structured facts, no handover prose, narrative, or dramatization.
- Preserve empty arrays and objects according to the template schema instead of omitting their keys.
- Keep array fields as `[]` when they have no entries. Keep `artifacts` and `governance_audit` as objects with their nested arrays present; record actual relative file paths in `artifacts.created`, `artifacts.modified`, and `artifacts.removed`, never placeholder strings.

**Step 5 - Update active_context.md**

- Structure: Read template from `loka-log/templates/active_context.md` (path relative to the skill root, i.e. the directory containing this `SKILL.md`)
- File: `<workspace>/.agents/memories/active_context.md` (or `~/.agents/memories/active_context.md` if global)
- Frontmatter resolution: Dynamically resolve all template placeholders. `project` must be derived from the current repo/workspace name (or workspace path if not a repository). `conversation_id` must be taken from the current session's system-provided conversation ID. Neither field may be left as literal placeholder text.
- Rewrite it from the final evidenced session state, never from conversational impressions, intentions, or unverified assumptions.
- Include only confirmed current status, currently binding decisions, meaningful recent changes, known open points or blockers, real next steps, active constraints, and observed repo state with timestamp.
- Keep it concise and start-ready: maximum one screen, no archive or session narrative.
- Format: Markdown with YAML frontmatter as defined in template, ends with `== END OF CONTEXT ==`.

**Step 6 - Confirm neutrally**

Report status neutrally:

```text
[LOKA-LOG] Session saved -> <workspace>/.agents/memories/sessions/session_YYYY-MM-DD__HH-MM.json
           active_context.md updated.
           Git: <clean / dirty>
```

---

## MODE B: LOG QUERY

Trigger: only when the USER explicitly requests to search, review, or trace session logs.

### Protocol

**Step 1 - List available logs**

```bash
ls -t <workspace>/.agents/memories/sessions/session_*.json 2>/dev/null || ls -t ~/.agents/memories/sessions/session_*.json
```

**Step 2 - Read and search**

- Read relevant log files based on USER intent (date, topic, keyword, or full history).
- No interpretation - present facts from the logs as-is.
- Do not write, update, or delete any log file.

**Step 3 - Output**

```text
[LOKA-LOG QUERY]
-----------------------------
Logs found  : <count>
Range       : <oldest> -> <newest>
Match       : <what was found>
-----------------------------
```

---

## Constraints

- Mode A must be fully factual: never disguise interpretation as a decision.
- `active_context.md` is overwriteable current state; session JSON files are immutable evidence ledgers.
- Do not duplicate session detail into `active_context.md`; summarize only what a new session needs to start correctly.
- No hallucinations: use only actual session history, Git status, and files read in the session.
- Structure fidelity: always follow the templates in `loka-log/templates/` (relative to the skill root).
- Logs are append-only: never edit them after creation.
- On filename collision, never overwrite existing logs.
- Update active context only during Mode A (explicit logging, status capture, or session end).
- Keep document paths relative inside skill outputs and instructions.
- Do not commit or revert dirty patches unless the user explicitly requests it.
