## Changelog

### v0.2.3
- **Radical Script Simplification ("Back to Roots"):** Purged over 1,380 lines of enterprise bloat across all pipeline scripts (`audit.sh`, `apply_mint.sh`, `index.sh`, `lib/parse_frontmatter.sh`), reducing total script footprint by over 56% while preserving 100% CLI interface compatibility and all architectural safety guarantees.
- **Locking & Bloat De-escalation:** Removed unnecessary flocking, probe file descriptors, `/proc/self/fd` inspections, and convoluted multi-phase rollback cascades while retaining clean, standard POSIX signal traps (`EXIT INT TERM`).
- **Strict Containment & Hash Verification:** Enforced canonical `readlink -m` containment against `BRAIN_DIR`, symlink target rejection, and `--base-hash` verification on `MERGE` to eliminate silent concurrent overwrite hazards.
- **Strict Schema v0.2.3 Validation:** Fully enforced OKF trust signals (`stale_after`, `verified`, `sources`, `owner`), closing delimiter line arithmetic (`line == field_count + 2`), canonical key ordering, duplicate key detection, schema purity against unknown/undeclared keys, internal wikilink integrity, and code-fence-isolated heading checks.
- **Mutation & File Permission Hygiene:** Scoped frontmatter updates in `promote_file()` and `set_deprecation()` to YAML frontmatter lines, preserved original file permissions via `chmod --reference` in `index.sh`, and registered all temp files in cleanup traps.

### v0.2.2
- **Shared Frontmatter Parser Isolation & Diagnostics:** Removed `#`-comment stripping and quote-cut heuristics in `scripts/lib/parse_frontmatter.sh` to preserve literal scalar content. Exported structured, distinct parser error channels (`ERR_DUPLICATE`, `ERR_UNKNOWN`, `ERR_COMMENTS`, `ERR_BLANK`, `ERR_MALFORMED`), established single-source-of-truth domain enums (`CANONICAL_DOMAINS`, `type_to_domain()`, `domain_to_type()`), and guarded `set -euo pipefail` behind `BASH_SOURCE == $0` to prevent caller shell pollution upon sourcing.
- **Transactional Minting & Realpath Safety:** Hardened `scripts/apply_mint.sh` to reject target symlinks before dereferencing (`exit 17`), enforced realpath containment, and added atomic staging via brain-local temporary files with post-write SHA-256 verification (`exit 18`) and `mv -T` rename. Added signal trapping (`EXIT INT TERM HUP`) with `set +e` inside rollback routines, propagated `export LOKA_BRAIN_ROOT="$BRAIN_DIR"` to child processes, and teed full-vault audit logs to stderr on pre-existing vault failures (`exit 22`).
- **Deterministic Audit Verification & Promotion Lifecycle:** Upgraded `scripts/audit.sh` to capture awk process errors, skipped body evaluation when frontmatter boundaries are unparseable, and placed `deprecated: true` strictly following `status:` in `set_deprecation_flag()`. Enforced exit code 3 on empty vaults, added vault root structure inspection for non-canonical files or nested domain folders, upgraded code fence and POSIX whitespace regexes (`^[ \t]*```+`, `[[:space:]]+$`), gated ANSI colors against TTY/`NO_COLOR`, purged legacy "Warnings: 0" lines, and separated "already active" accounting during artifact promotion.
- **Atomic Index Synchronization & Concurrency Safety:** Enhanced `scripts/index.sh` with index marker injection rejection (`exit 5`) and exact marker count verification. Moved temporary table and index files to the vault root with permission preservation (`chmod --reference`) and `EXIT` trap cleanup, added vault-wide mutual exclusion via `.loka.lock` flock, and purged unused `owner` frontmatter extraction.

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
