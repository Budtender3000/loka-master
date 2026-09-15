## Changelog

### v2.5.0
- **Decoupling (Step 5 & 6):** Streamlined session recording to purely local and workspace-contained storage (`.agents/memories/`), decoupling from external memory daemons and private host paths.

### v2.4.1
- **Fix 1 (Git Resilience):** Step 0 command updated to `git status --short --branch || echo "No git repository"` to prevent exit code 128 failures in non-git workspaces.
- **Fix 2 (Frontmatter Precision):** Step 5 updated with explicit instructions to dynamically resolve `project` and `conversation_id` placeholders in `active_context.md`.
