## Changelog

### v0.2.7
- **Mode Separation:** Streamlined default MODE A to strictly produce session log JSON files (`YYYY-MM-DD_HH-MM-sessionlog.json`). Decoupled `active_context.md` from automatic generation.
- **Delegated Query Mode:** Extracted former Mode B into `references/log-query.md` to keep core skill lean and load on demand.
- **Delegated Handover Mode:** Extracted handover generation into `references/session-handover.md` (target: `.agents/memories/handovers/YYYY-MM-DD_HH-MM-session-handover.md`). Embedded the template structure directly as a fenced block in `references/session-handover.md` without an external template file.
- **Handover Schema Purity & Body Alignment:** Realigned handover body 1:1 with `session-handover` skill structure while replacing legacy frontmatter with schema-pure LOKA/OKF frontmatter (`id`, `name`, `type`, `description`, `created`, `status`, `owner`). Enforced verbatim parity between `name` and `# SESSION HANDOVER — <Session Topic>`. Decoupled runtime metadata (`Project`, `Conversation ID`, `Agent / Model`) into the body and parameterized `owner` to ensure clean de-identification for public sharing. Added explicit `Repository State` section backed by Step 0 Git Reality Check in Mode C.
- **Template Restructuring:** Renamed `session_log.json` to `sessionlog-template.json` (bumped to Schema 1.2) with `last_task` status tracking and structured `workspace_state` fields (`branch`, `commit`, `working_tree`, `git_status`).
- **Structured Neutral Confirmation:** Upgraded Step 5 confirmation output to report structured last task status, repository state, and open blockers.

### v2.5.0
- **Decoupling (Step 5 & 6):** Streamlined session recording to purely local and workspace-contained storage (`.agents/memories/`), decoupling from external memory daemons and private host paths.

### v2.4.1
- **Fix 1 (Git Resilience):** Step 0 command updated to `git status --short --branch || echo "No git repository"` to prevent exit code 128 failures in non-git workspaces.
- **Fix 2 (Frontmatter Precision):** Step 5 updated with explicit instructions to dynamically resolve `project` and `conversation_id` placeholders in `active_context.md`.
