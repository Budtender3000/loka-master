## Changelog

### v0.2.1
- **Delegation Contract Streamlining:** Streamlined Directive 1 in `SKILL.md` to cleanly separate the main agent orchestrator role from master subagents, formalizing strict payload inputs and return interfaces.
- **Prompt Target Alignment:** Realigned `prompts/retrospective.prompt.md` target path from legacy `docs/` to `.agents/loka-brain/retrospectives.md` and sanitized directory initialization logic.
- **Tooling Discovery & Legacy Fallback Purge:** Removed obsolete `LOKA-brain` uppercase fallbacks from `scripts/apply_mint.sh`, `scripts/audit.sh`, and `scripts/index.sh`, restricting runtime discovery strictly to dynamic walk-up and `.agents/loka-brain/`.
- **Writer Worker Resolution:** Simplified realpath resolution in `agents/writer-worker.md` to eliminate foreign and legacy fallback targets.
- **Documentation & CLI Parity:** Aligned CLI examples in `README.md` with schema v0.2.3 standards and exact script flag syntax (`--promote`, `--deprecate`, `--all`).

### v0.2.0
- **Trust Signal Validation:** Upgraded `scripts/lib/parse_frontmatter.sh` and `scripts/audit.sh` to validate OKF v0.2 trust signals (`stale_after`, `verified`, `sources`).
- **Canonical Key Ordering & Field Integrity:** Hardened `scripts/audit.sh` to enforce strict canonical frontmatter key sequences and reject empty declared keys.
- **Deterministic Delimiter Rule:** Aligned `scripts/audit.sh`, `agents/mint-master.md`, and `agents/review-master.md` to enforce the mathematical frontmatter delimiter calculation (`closing line == 2 + field_count`).
- **Harness Cleanup:** Purged deprecated development script `scripts/test_mid_pipeline_rollback.sh`.

### v0.1.0
- **Dual-Master Orchestration:** Initial release of the `loka` skill introducing privilege-separated pipeline roles (`agents/mint-master.md`, `agents/review-master.md`) and dedicated write worker (`agents/writer-worker.md`).
- **Cryptographic Human Gate:** Introduced SHA-256 draft hash calculation and user approval checkpoint prior to triggering disk mutations.
- **Transactional Mutation Engine:** Implemented `scripts/apply_mint.sh` featuring realpath containment, atomic staging, index rebuild, and automated rollback traps (`trap cleanup_rollback EXIT`).
- **Deterministic Verification Suite:** Implemented `scripts/audit.sh` enforcing 5 binary quality dimensions (schema, links, paths, syntax, lifecycle) and `scripts/index.sh` regenerating progressive disclosure tables between explicit comment markers.
