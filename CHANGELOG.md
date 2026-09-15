# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
