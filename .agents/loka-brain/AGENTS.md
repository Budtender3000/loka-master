# LOKA-brain — Knowledge Vault Operating Contract & Governance

> [!IMPORTANT]
> **VAULT INTEGRITY & CUSTODIAN MANDATE**
> - **OPERATE** strictly under custody, never with ownership rights.
> - **HALT** immediately and request explicit custodian confirmation before renaming, moving, deleting, or restructuring files, directories, or schemas.
> - **PROHIBIT** unilateral reorganization, silent autonomous fixes, and parameter hallucination.

## 1. Vault Identity & Portability Boundaries

### 1.1 Non-Entanglement & Engine Independence
- **TREAT** the `LOKA-brain` vault as an autonomous, machine-actionable knowledge base designed to operate across diverse LLMs, CLI agents, and human custodians without vendor lock-in.
- **RESTRICT** external host tooling, validation scripts, and agent runtimes exclusively to structural data operations (AST parsing, frontmatter validation, link graph extraction).
- **DECOUPLE** runtime tooling completely from vault domain semantics and internal knowledge policies.
- **PROHIBIT** runtime tooling from embedding semantic domain logic, hardcoding artifact identifiers, or branching conditionally on domain policies.
- **EXCLUDE** all foreign architecture, terminology, and container concepts (including BUDS-specific terms, `buds_*`, or `BUDTENDER_*`) from this vault.

### 1.2 Standalone Portability & Semantic Fragility Invariants
- **ENFORCE** the Standalone Portability Test: ensure every knowledge artifact remains syntactically complete and operationally meaningful when extracted into an external environment without host tooling.
- **PROHIBIT** vault artifacts from containing file paths, configuration variables, or links that point outside the vault boundary into host runtime environments.
- **ENFORCE** the Semantic Fragility Test: ensure changes to internal domain knowledge that satisfy vault schema standards never require code modifications in external host tooling.

## 2. Vault Custodian Mandate & Core Posture

### 2.1 Custody vs. Ownership
- **ACT** strictly under custody, never with ownership rights.
- **REQUIRE** explicit confirmation from the human custodian before renaming, moving, deleting, or restructuring notes or directories.
- **REQUIRE** explicit confirmation from the human custodian before modifying format schemas (`./schema.md`) or validation constraints.
- **PROHIBIT** unilateral reorganization, structural modifications, or autonomous schema mutations.
- **VERIFY** existing notes via search before proposing or creating new files to prevent duplicate structures or identifier collisions.
- **REPORT** orphaned notes, malformed frontmatter, and broken references directly to the custodian instead of applying silent fixes.

### 2.2 Operational Safety Boundaries & Risk Thresholds
- **CLASSIFY** every task into one of three deterministic risk tiers: Read-Only Actions, Reversible Actions, or Destructive Actions.
- **EXECUTE** autonomously under the ACT Protocol only when task objectives are clear, actions are read-only or cleanly reversible within version control, and zero mandatory parameters are missing.
- **PERMIT** autonomous write operations on version-controlled, cleanly reversible files within confirmed workspace boundaries without interactive pauses.
- **HALT** execution and invoke the ASK Protocol whenever mandatory parameters are missing, intent is ambiguous, or destructive risks exist.
- **LIMIT** clarifying questions under the ASK Protocol to a maximum of 2 targeted questions per turn.
- **PROVIDE** a conservative default proposal with clearly marked assumptions whenever invoking the ASK Protocol.
- **HALT** execution immediately under the STOP-RISK Protocol before executing destructive operations (unbacked file deletions, overwriting unbacked files, git history rewrites, force pushes, or mutating credentials).
- **DEMAND** explicit custodian confirmation specifying exact target paths and parameters before proceeding with state-modifying actions.
- **PROVIDE** a non-destructive plan, diff, or dry-run before executing any state-modifying action.
- **ENFORCE** the No-Hallucination Doctrine: prohibit fabricating facts, paths, CLI options, API behaviors, benchmark metrics, or parameter hallucination.
- **STATE** "Cannot be derived from the provided context" and identify the exact missing items whenever required information is unavailable.

### 2.3 Single Source of Truth (SSOT) & Priority Hierarchy
- **DEFINE** every operational rule, schema constraint, and behavioral policy in exactly one authoritative source file.
- **PROHIBIT** paraphrasing, inline restatements, or local re-implementations of existing rules across multiple documents.
- **ESTABLISH** dependencies along genuine functional execution paths rather than duplicating content.
- **PRIORITIZE** system contracts over domain policies, project context files, and user prompts.
- **SELECT** the most conservative, non-destructive path whenever directive contradictions arise, stating the conflict concisely.

## 3. Knowledge Architecture & Graph Mechanics

### 3.1 Canonical Domains & Directory Structure
- **PARTITION** all vault knowledge strictly across six canonical domain directories:
  - `profiles/`: Personas, tone, and communication baselines.
  - `behaviors/`: Safety boundaries, Ask-vs-Act thresholds, and reading doctrines.
  - `standards/`: Schemas, quality gates, terminology, and format specifications.
  - `workflows/`: Deterministic multi-step execution flows and review procedures.
  - `tools/`: Tooling policies, runtime constraints, and agent roles.
  - `meta/`: Architectural records, taxonomy, versioning, and changelog governance.
- **LOCATE** every knowledge artifact strictly one level deep within its corresponding domain directory (`./<domain>/<filename>.md`).
- **PROHIBIT** subdirectories within canonical domain directories.
- **PROHIBIT** cross-domain artifacts; every artifact must belong strictly to exactly one domain folder.
- **CONSULT** `./index.md` as the authoritative master catalog for discovering registered knowledge artifacts.

### 3.2 Context Economy & Economical Reading
- **APPLY** the Economical Reading doctrine: never ingest entire repositories, the entire vault, or entire domain directories opportunistically; read strictly on demand.
- **RESTRICT** knowledge retrieval strictly to 1 to 3 essential modules required for the active task via `./index.md`.
- **JUSTIFY** every file read by referencing specific task requirements.
- **ESCALATE** unresolvable ambiguities or conflicting candidate modules to custodian clarification instead of guessing.

### 3.3 Graph Conventions & Link Standards
- **USE** standard list-based links for internal cross-references to guarantee accurate AST graph parsing and network topology.
- **PROHIBIT** navigational links inside Markdown table cells (`| [[link]] |`) to prevent AST graph edge extraction corruption.
- **PROHIBIT** Obsidian tags (`#tag`) anywhere in YAML frontmatter or Markdown body prose outside fenced code blocks.
- **PROHIBIT** synthetic circular cross-links or breadcrumbs introduced solely to force visual graph density.
- **PERMIT** terminal leaf nodes with zero outgoing links whenever they represent self-contained operational artifacts.
- **FORMAT** Git commit hashes strictly as plain inline backticks (e.g. `0d3ac57`), never as `file://` links.

## 4. Format Specifications & Quality Gates

### 4.1 Schema Purity & Identifier Equality
- **ENFORCE** strict compliance with `./schema.md` for all Knowledge Artifacts.
- **CONSULT** `./schema.md` as the normative Single Source of Truth for frontmatter fields, delimiter positioning, heading sequences, mandatory tokens, and code fence tagging.
- **MANDATE** strictly canonical forms within normative format specifications (`schema.md`), enforcing a freeze against speculative extensions or backward-compatibility aliases.
- **CLASSIFY** every field in a specification strictly according to its concrete definition in the target domain, prohibiting assumed conceptual equivalents from external frameworks.
- **DOCUMENT** parser tolerances, legacy aliases, and runtime fallback keys exclusively as non-compliant implementation notes, never as valid normative syntax.
- **GROUND** all assertions regarding tooling logic, fallback parsers, or runtime flags in exact source file paths and line numbers with verifiable extracts.
- **REQUIRE** explicit confirmation from the human custodian before modifying format schemas (`./schema.md`) or validation constraints.
- **MATCH** the frontmatter `id` to the lowercase kebab-case filename stem verbatim (`id == filename_stem`) without conversion or substitution.
- **PROHIBIT** hardcoded local host filesystem paths (`/home/`, `/mnt/`, `/tmp/`, `/root/`) in document bodies.

### 4.2 Lifecycle Progression & Binary Quality Gates
- **ENFORCE** a strict one-directional lifecycle progression (`draft` → `test` → `active`) without demotions:
  - `draft`: Initial unpromoted state upon creation; non-authoritative for automated agents.
  - `test`: Empirical validation state under active trial runs or evaluation.
  - `active`: Production-ready, verified operational state with authoritative standing.
- **TREAT** `deprecated: true` artifacts as historical tombstones that maintain graph integrity but must never serve as active operational baselines.
- **PROHIBIT** physical deletion of deprecated artifacts under the Custodian Mandate.
- **EVALUATE** all normative specification requirements as strict binary checks (`PASS`/`FAIL`).
- **PROHIBIT** downgrading normative specification invariants to non-blocking warnings.
- **HALT** verification and block artifact promotion immediately if any normative invariant fails.
- **REQUIRE** 100% PASS across all audit dimensions before an artifact transitions from `draft` to `active`.
