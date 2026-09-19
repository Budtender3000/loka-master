# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-09-19

### Added
- **Python CLI Tooling Suite:** Migrated vault management from legacy Bash scripts to a zero-dependency Python 3 CLI (`.agents/skills/loka/scripts/loka.py`) providing unified `format`, `index`, `promote`, `deprecate`, `undeprecate`, and `mint` subcommands with automated transactional rollback.
- **Unit Test Suite:** Added comprehensive `unittest` suite (61 tests) covering frontmatter parsing, mechanical formatting, progressive disclosure catalog indexing, and transactional lifecycle mutations.
- **Knowledge Consumption Contract & Host Integration:** Introduced `.agents/loka-brain/LOKA.md` as the dedicated read-only consumption contract, `AGENTS.template.md` as the bootstrap snippet for host repositories, and documented installation, embedding, and update procedures.
- **Frontmatter Semantic Validation:** Added calendar date validation (`created`, `stale_after` matching `YYYY-MM-DD` validated via `datetime.date.fromisoformat`) and canonical trust signal enum validation (`verified` in `human|attested|automated`) in `check_semantics`, rejecting invalid values across `loka promote`, `deprecate`, and `mint`.
- **Root Bootstrap Gateway:** Added a minimal, deterministic root `AGENTS.md` serving strictly as an external agent interoperability bootstrap pointing to `.agents/loka-brain/LOKA.md` and `.agents/AGENTS.md`.
- **Skill-Centric Changelogs:** Added dedicated, isolated `changelog.md` ledgers for each core skill (`.agents/skills/loka/`, `.agents/skills/loka-git-manager/`, `.agents/skills/loka-log/`).
- **Session Memory Tracking:** Added `.agents/memories/sessions/` to tracked architecture documentation for factual execution audit trails.
- **Licensing:** Added standard MIT LICENSE for public release.

### Changed
- **README Rewrite & Host Integration Guide:** Completely rewrote repository `README.md` with standalone and embedded installation instructions, update procedures for host repositories, vault taxonomy overview, full CLI command reference, and verified quickstart lifecycle execution.
- **Unified Governance Architecture:** Consolidated operating contract governance into `.agents/AGENTS.md` with root `AGENTS.md` serving as an external agent bootstrap pointing to `.agents/loka-brain/LOKA.md` and `.agents/AGENTS.md`, eliminating empty delegation stubs and rule duplications.
- **Self-Contained Framework Substrate:** Fully encapsulated LOKA governance, skills, and vault under `.agents/`, eliminating root-level file conflicts for seamless embedding into host repositories.
- **Vault-Scoped Operating Contract:** Refactored `.agents/AGENTS.md` §1 scope boundaries to explicitly govern only `./.agents/loka-brain/` and LOKA skill operations, clarifying that host application code outside `./.agents/` is not restricted.
- **Runtime-Neutral Agent Instructions:** Decoupled agent contracts and instructions (`LOKA.md`, `.agents/AGENTS.md`) from platform-specific tool syntax, replacing `view_file` references with runtime-neutral reading directives.
- **Git Safety & Sync Verification:** Enhanced `loka-git-manager` to v0.2.1 with strict post-push remote synchronization verification rules (`git fetch` + `git rev-list --left-right --count` / `git rev-parse`), prohibited treating bare `## <branch>` status as sync evidence, and added upstream tracking recommendations (`git push -u`).
- **Schema Specification v0.3.0:** Upgraded `.agents/loka-brain/schema.md` to specification version 0.3.0. Replaced closing delimiter line formula with compact delimiter invariant (one key per line, no blank lines), codified double-quoting triggers matching `render()`, aligned `sources` array syntax with double quotes, pruned Section 3.4 mandatory section tokens, delegated secret scanning to `loka-git-manager`, and introduced the binary `AUTO-FIX` vs `REPORT` fix class classification.
- **Schema Enforcement Attribution:** Re-attributed `REPORT` class rows in `schema.md` Section 5 to their concrete validators: mapping `status` enum, non-boolean `deprecated`, ISO-8601 dates, `verified` trust signal, and `sources` array syntax enforcement to `check_semantics` (via `loka promote`/`deprecate`/`mint`).
- **Skill Suite Standardization:** Aligned all core skill frontmatters with standard metadata schema (`type: skill`, `version`, `owner: USER`), syncing `loka` to v0.3.0, `loka-git-manager` to v0.2.1, and `loka-log` to v0.2.7.
- **Positive Technical English Directive:** Codified affirmative, clear technical English composition across schemas and agent instructions.

### Removed
- **Single README Policy:** Deleted `.agents/README.md` to establish root `README.md` as the single authoritative project documentation entry point, removing redundant architectural tables and dead links.
- **Legacy Bash Scripts:** Removed deprecated `audit.sh`, `index.sh`, `apply_mint.sh`, and `parse_frontmatter.sh` in favor of the Python CLI suite.

### Fixed
- **Index Generator Validation:** Enforced comprehensive parse and semantic validation in `scripts/lib/indexer.py` (`generate_index`), validating every knowledge artifact with `parse()` and `check_semantics()`. Any defect (`invalid_deprecated`, `invalid_sources`, unparseable syntax, missing required fields, `id_stem_mismatch`, `invalid_status`, etc.) excludes the artifact from `index.md`, emits a warning on stderr, and causes `loka index --strict` to exit with status 1 while maintaining non-strict exit 0 for isolated lifecycle operations.
- **Strict Frontmatter Validation:** Stopped coercing invalid `sources` and `deprecated` values in `frontmatter.py` and `formatter.py`. Added semantic validation rejecting non-boolean `deprecated` (`invalid_deprecated`) and non-array or unquoted `sources` (`invalid_sources`), ensuring lifecycle operations (`promote`, `deprecate`, `undeprecate`, `mint`) and `loka format` exit 1 and leave invalid files untouched.
- **Formatter Quote Detection:** Fixed false positive `quotes_required` detection in `formatter.py` for valid inline arrays (`sources: ["..."]`) by deriving quote change categories directly from frontmatter value diffs.
- **Retrospective Prompt Target:** Updated `retrospective.prompt.md` target path to `.agents/loka-brain/retrospectives.md` and sanitized legacy directory initialization.
- **Tooling Discovery:** Purged legacy uppercase `LOKA-brain` fallback paths from tooling scripts.

## [0.2.4] - 2026-09-17

### Fixed
- **Pipeline Containment & Realpath Safety:** Enforced canonical `readlink -m` containment against `BRAIN_DIR` and rejected symlink targets in `scripts/apply_mint.sh`.
- **Merge Concurrency Safety:** Added mandatory `--base-hash` verification against on-disk target sha256 checksum on `MERGE` to prevent silent overwrites.
- **Strict Schema v0.2.3 Validation:** Restored full enforcement of OKF trust signals (`stale_after`, `verified`, `sources`, `owner`), closing delimiter arithmetic (`line == field_count + 2`), canonical key ordering, duplicate key detection, and schema purity in `audit.sh` and `parse_frontmatter.sh`.
- **Wikilink Integrity & Code Block Protection:** Restored internal wikilink verification against all canonical domains, and scoped heading extraction to ignore code fence blocks.
- **Rollback & Permission Hygiene:** Added standard POSIX signal traps (`EXIT INT TERM`) with rollback, preserved permissions in `index.sh` (`chmod --reference`), and scoped frontmatter mutations in `promote_file()` and `set_deprecation()`.

### Changed
- **Skill Version Bump:** Bumped `loka` skill to `v0.2.4`.

## [0.2.3] - 2026-09-17

### Changed
- **Radical Script Simplification ("Back to Roots"):** Purged over 1,380 lines of enterprise bloat across all pipeline scripts (`audit.sh`, `apply_mint.sh`, `index.sh`, `lib/parse_frontmatter.sh`), reducing total script footprint by over 56% while preserving 100% CLI interface compatibility.
- **Concurrency & Locking Purge:** Removed vault-wide file-locking (`flock`), probe file descriptor checks, `/proc/self/fd` inspections, and multi-phase exit 22/23 dirty-vault error cascades.

## [0.2.0] - 2026-09-15

### Added
- **OKF v0.2 Trust Signals:** Extended `schema.md` to specification v0.2.3 with optional frontmatter fields `stale_after` (ISO-8601 date), `verified` (`human|attested|automated`), and `sources` (inline URI/source array).
- **Hardened Validation:** Updated `parse_frontmatter.sh` and `audit.sh` to validate OKF v0.2 trust signals, canonical key ordering, and reject empty declared keys.

### Changed
- **Decoupled Vault Framework:** Purged obsolete reference seed templates (`.agents/skills/loka/seed/`) and decoupled `audit.sh`, `mint-master.md`, and `writer-worker.md` from the Bootstrap Invariant (§6), making `loka-master` fully functional as an unpopulated standalone repository.
- **Synchronized Agent Prompts:** Updated `mint-master.md`, `review-master.md`, `writer-worker.md`, and `.agents/README.md` to schema specification v0.2.3 and aligned pre-flight delimiter rules.

### Removed
- Removed legacy developer testing harness `.agents/skills/loka/scripts/test_mid_pipeline_rollback.sh`.
- Purged obsolete reference seed templates `.agents/skills/loka/seed/`.

## [0.1.0] - 2026-09-14

### Added
- **Core Knowledge Vault (`./.agents/loka-brain/`):**
  - Normative format specification (`schema.md`, v0.2.2) defining YAML frontmatter constraints, heading hierarchies, and binary quality gates.
  - Auto-generated Master Catalog (`index.md`) supporting progressive disclosure and economical context retrieval.
  - Clean, unpopulated canonical domain folders (`behaviors/`, `profiles/`, `standards/`, `workflows/`, `tools/`, `meta/`) ready for user artifacts.
  - Vault Operating Contract (`.agents/loka-brain/AGENTS.md`) establishing the Custodian Mandate and standalone portability invariants.
- **Core Skill Suite (`./.agents/skills/`):**
  - `loka`: Master Orchestrator for knowledge minting, auditing, indexing, and lifecycle promotion.
  - `loka-git-manager`: Local Git safety, pre-flight checks, atomic Conventional Commits, and secret scanning.
  - `loka-log`: Deterministic session logging, factual audit trails, and context handovers.
- **Root Governance & Documentation:**
  - Workspace Operating Contract (`AGENTS.md`) defining project identity, boundary rules, and skill delegations.
  - Comprehensive Agent Environment architecture and sequence documentation (`.agents/README.md`).
  - Clean `.gitignore` masking local editor caches, secrets, and transient state.
