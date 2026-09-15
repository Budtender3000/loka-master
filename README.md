# LOKA — Local Open Knowledge Artifact

> **Modular, machine-actionable, and vendor-neutral Knowledge Artifact architecture for human engineers and autonomous agents.**

LOKA (Local Open Knowledge Artifact) is an open-source framework and knowledge governance system designed to store, validate, and retrieve institutional engineering knowledge. By enforcing strict runtime-vault decoupling, LOKA guarantees that knowledge artifacts remain self-contained, portable, and machine-actionable across diverse LLMs, CLI agents, and developer environments.

---

## Key Features

- **Strict Schema Enforcement:** Every Knowledge Artifact (KA) adheres to the normative format specification (`./.agents/loka-brain/schema.md`, v0.2.2) with strict YAML frontmatter, deterministic section hierarchies, and binary quality gates.
- **Runtime-Vault Decoupling:** Runtime tooling interacts with knowledge solely as a structural data substrate (AST parsing, frontmatter validation, link graphs), eliminating semantic coupling between host tooling and domain knowledge.
- **Economical Context Retrieval:** Progressive disclosure via `./.agents/loka-brain/index.md` ensures agents load only the minimal 1–3 essential modules required for a task, preventing context window bloat.
- **Autonomous Lifecycle Verification:** Built-in auditing engine (`audit.sh`) validates format purity, link integrity, de-identification, and security gates before any artifact reaches active status.
- **Dedicated Agent Skills:** Pre-configured agent workflows for knowledge curation (`loka`), local Git commit hygiene (`loka-git-manager`), and structured session logging (`loka-log`).

---

## Directory Structure

```text
loka-master/
├── AGENTS.md                   # Workspace Operating Contract & Agent Governance
├── CHANGELOG.md                # Project release history & version tracking
├── README.md                   # Project overview & quickstart guide
└── .agents/
    ├── loka-brain/             # Encapsulated Knowledge Vault
    │   ├── AGENTS.md           # Vault Operating Contract & Custodian Mandate
    │   ├── index.md            # Auto-generated Master Catalog (progressive disclosure)
    │   ├── schema.md           # Normative Knowledge Artifact Format Schema (v0.2.2)
    │   ├── behaviors/          # Behavioral rules & safety thresholds
    │   ├── profiles/           # Agent personas & communication baselines
    │   ├── standards/          # Technical specifications & boundary rules
    │   ├── workflows/          # Deterministic execution & review procedures
    │   ├── tools/              # Tooling policies & runtime constraints
    │   └── meta/               # Architectural records & governance
    └── skills/
        ├── loka/               # Knowledge minting, auditing, and indexing engine
        ├── loka-git-manager/   # Local Git safety, pre-flight checks & commit hygiene
        └── loka-log/           # Session memory, factual logging & context handover
```

---

## Quickstart & CLI Verification

All scripts are self-contained and execute from the repository root:

### 1. Audit the Knowledge Vault

Run the full audit suite to verify 100% compliance across all registered artifacts:

```bash
bash .agents/skills/loka/scripts/audit.sh --all
```

To audit a single artifact:

```bash
bash .agents/skills/loka/scripts/audit.sh ./.agents/loka-brain/<domain>/<artifact>.md
```

### 2. Rebuild the Master Catalog

Re-index all domain folders and update the catalog in `./.agents/loka-brain/index.md`:

```bash
bash .agents/skills/loka/scripts/index.sh
```

---

## The Knowledge Artifact Lifecycle

Every Knowledge Artifact transitions through three one-directional operational states:

1. **`draft`:** Initial created state; working draft, non-authoritative for automated agents.
2. **`test`:** Empirical validation state under active evaluation or trial runs.
3. **`active`:** Authoritative, production-verified knowledge requiring 100% PASS on all audit dimensions.

---

## Core Skills

- **`loka`:** Governs the end-to-end lifecycle of Knowledge Artifacts. Coordinates subagents (`loka-mint-master`, `loka-writer`, `loka-review-master`) for deterministic minting, strict auditing, index maintenance, and promotion.
- **`loka-git-manager`:** Enforces repository hygiene, atomic Conventional Commits, pre-flight branch checks, and sensitive data masking.
- **`loka-log`:** Captures factual session progress, milestones, and active context handovers in `./.agents/memories/`.

---

## Contributing & Custodian Protocol

LOKA operates under a strict **Custodian Mandate**:
- All modifications to format schemas (`schema.md`), operational boundaries, or directory structures require human custodian review.
- Automated agents operate under custody, never with unverified ownership rights.
- Destructive operations (history rewrites, unbacked deletions) are blocked by the `STOP-RISK` protocol.
