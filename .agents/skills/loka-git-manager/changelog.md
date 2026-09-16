## Changelog

### v0.2.0
- **Instruction Formatting & Normative Operators:** Refactored `SKILL.md` to strictly adhere to `formatting.md` with front-positioned imperative verbs (`**EXECUTE**`, `**VERIFY**`, `**INSPECT**`, `**ISOLATE**`, `**FORMAT**`, `**STAGE**`).
- **Hard STOP Rules:** Formalized operational stop rules into an explicit alert block covering CWD mismatches, unexpected changes, ambiguous branch states, and secret/debug findings.
- **Recovery Protocol:** Established a deterministic dirty working tree recovery sequence requiring an atomic patch backup (`recovery.patch`) prior to any reset or checkout operation.
- **Proposal Cleanup:** Promoted verified improvements from `SKILL.prop.md` and deleted the proposal artifact.
- **Metadata Standardization:** Aligned YAML frontmatter with ecosystem standards (`type: skill`, `version: 0.2.0`, `owner: USER`).

### v0.1.0
- **Initial Implementation:** Initial release establishing deterministic local Git workflow: mandatory pre-flight checks, atomic Conventional Commits, staged diff secret/debug scanning, and strict local push/tag boundaries.
