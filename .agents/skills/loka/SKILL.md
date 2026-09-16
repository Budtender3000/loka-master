---
name: loka
description: Master Orchestrator for LOKA Knowledge Artifacts (KAs). Governs schema.md minting of new KAs and auditing, lifecycle promotion (draft→test→active), and deprecation of existing KAs using dual read-only masters and an explicit Human Gate with draft-hash verification. Use when the user wants to mint/document/archive findings ("add this to LOKA", "mint this", "document this pattern") or audit/review/promote KAs ("audit LOKA", "review this KA", "promote X").
type: skill
version: 0.2.1
owner: USER
---

# loka — Dual-Master Orchestrator

Master skill governing the Knowledge Artifact lifecycle in `./.agents/loka-brain/`. Operates two strictly isolated pipelines — Mint and Review — each driven by a specialized read-only Master Subagent, gated by user confirmation before any vault modification.

## Architectural Model

```text
[User Request] ──────────────────────────► [Main Agent: agy]
                                                   │
                  ┌────────────────────────────────┴────────────────────────────────┐
                  ▼                                                                 ▼
           [Mint-Modus]                                                     [Review-Modus]
                  │                                                                 │
  [Master: loka-mint-master]                                        [Master: loka-review-master]
  (Read-Only: write_tools: false)                                   (Read-Only: write_tools: false)
  - Classify domain & vault-wide ID check                           - Inspect candidate / transition
  - Draft SCHEMA v0.2.3 KA & de-identify                            - Evaluate 5 audit dimensions
  - Verify normative operators & whitespace hygiene                 - Formulate recommendation
                  │                                                                 │
                  ▼                                                                 ▼
        [Candidate Draft]                                                 [Review Finding]
                  │                                                                 │
                  └────────────────────────────────┬────────────────────────────────┘
                                                   ▼
                                       [Hash & Pre-Flight Gate]
                                       (Main Agent: sha256sum)
                                       - Compute deterministic SHA-256
                                       - Verify zero trailing whitespace
                                                   │
                                                   ▼
                                         [Human Gate: User]
                                     (TARGET_PATH + DRAFT_HASH)
                                                   │
                                        (Approved / Confirmed)
                                                   ▼
                                      [Worker: loka-writer]
                                      (Privileged: write_tools: true)
                                      - Invokes scripts/apply_mint.sh:
                                        * Enforce realpath containment
                                        * Verify DRAFT_HASH verbatim
                                        * Pre-flight whitespace & existence
                                        * Atomic write -> audit.sh -> index.sh -> vault audit
                                        * Automatic rollback if any step fails
```

## Bundled Components

- `agents/mint-master.md` — Mint pipeline orchestrator prompt (read-only master).
- `agents/review-master.md` — Review and promotion pipeline orchestrator prompt (read-only master).
- `agents/writer-worker.md` — Execution worker prompt for vault mutations post Human Gate.
- `scripts/apply_mint.sh` — Transactional Knowledge Artifact mint and rollback engine.
- `scripts/audit.sh` — Deterministic verification and promotion engine (SCHEMA v0.2.3).
- `scripts/index.sh` — Vault catalog generator with progressive disclosure descriptions.
- `scripts/lib/parse_frontmatter.sh` — Order-agnostic frontmatter parser.
- `prompts/retrospective.prompt.md` — Standalone context distillation into `./.agents/loka-brain/retrospectives.md`.

## Mode Selection

**DETERMINE** pipeline mode strictly by matching user intent before invocation:

| User Intent / Triggers | Pipeline Mode | Target Master |
|---|---|---|
| "add this to LOKA", "mint this", "save as KA", "document this pattern" | Mint | `loka-mint-master` |
| "audit LOKA", "review this KA", "promote X", "deprecate X", "validate vault" | Review | `loka-review-master` |
| Unclear or ambiguous input | Clarification | **ASK** user before proceeding |

---

## Directives

### 1. Delegation & Payload Contract (Runtime-Neutral)

- **SELECT** target master (`mint-master` or `review-master`) per Mode Selection table.
- **SPAWN** selected Master Subagent in read-only mode (write capabilities strictly disabled).
- **TRANSFER** following payload from Master Subagent to Parent Orchestrator (`STATUS: AWAITING_HUMAN`):
  - `TARGET_PATH`, `BASE_HASH` (`NONE` on new mints), `BASE_CONTENT` (`NONE` on new mints), `CANDIDATE_DRAFT`.
- **COMPUTE** cryptographic `DRAFT_HASH` via `sha256sum` directly from `CANDIDATE_DRAFT`.
- **VERIFY** zero trailing whitespace across `CANDIDATE_DRAFT`.
- **PROHIBIT** read-only subagents from calculating, emitting, or hallucinating cryptographic hashes.
- **PRESENT** `TARGET_PATH`, computed `DRAFT_HASH`, and candidate artifact to user at Human Gate.
- **HALT** execution and await explicit user confirmation.
- **DISPATCH** following payload from Orchestrator to Write Worker (`agents/writer-worker.md`) strictly post-approval:
  - `TARGET_PATH`, `BASE_HASH`, `BASE_CONTENT`, `DRAFT_CONTENT`, verified `DRAFT_HASH`.
- **ENFORCE** transactional execution through `scripts/apply_mint.sh` (realpath containment, hash verification, `audit.sh` before `index.sh`, full vault audit, automatic rollback).

*(Consult Architectural Model diagram above for execution flow, pipeline branching, and privilege boundaries.)*

### 2. Runtime Implementation Reference (Antigravity CLI / AGY)

#### Mint-Modus:
```text
1. READ: ./.agents/skills/loka/agents/mint-master.md
2. DEFINE: define_subagent(
     name="loka-mint-master",
     description="Read-only mint master",
     system_prompt=<mint-master.md>,
     enable_write_tools=false,
     enable_subagent_tools=true
   )
3. INVOKE: invoke_subagent(
     TypeName="loka-mint-master",
     Role="Mint Master Orchestrator",
     Prompt="Run loka mint pipeline on input:\n<RAW_INPUT>",
     Model="pro"
   )
4. HASH & HUMAN GATE:
   - Orchestrator computes verified SHA-256 DRAFT_HASH from CANDIDATE_DRAFT via sha256sum/Python.
   - Orchestrator asserts zero trailing whitespace.
   - Orchestrator presents TARGET_PATH, computed DRAFT_HASH, and candidate draft. Await user confirmation.
5. EXECUTE WRITER: Upon approval:
   define_subagent(
     name="loka-writer",
     description="Write worker",
     system_prompt=<writer-worker.md>,
     enable_write_tools=true
   )
   invoke_subagent(
     TypeName="loka-writer",
     Role="Write Worker",
     Prompt="Apply mint. ACTION: NEW_MINT, TARGET_PATH: <TARGET_PATH>, DRAFT_HASH: <DRAFT_HASH>, DRAFT_CONTENT:\n<CONTENT>",
     Model="flash"
   )
```

#### Review-Modus:
```text
1. READ: ./.agents/skills/loka/agents/review-master.md
2. DEFINE: define_subagent(
     name="loka-review-master",
     description="Read-only review master",
     system_prompt=<review-master.md>,
     enable_write_tools=false,
     enable_subagent_tools=true
   )
3. INVOKE: invoke_subagent(
     TypeName="loka-review-master",
     Role="Review Master Orchestrator",
     Prompt="Run loka review pipeline. Target: <TARGET>, Action: <ACTION>",
     Model="pro"
   )
4. EVALUATE:
   - If Action is read-only audit: Present audit report to user.
   - If Action is promote/deprecate: Present TARGET_PATH, DRAFT_HASH, transition diff. Await user confirmation at Human Gate.
5. EXECUTE WRITER: Upon approval, invoke loka-writer (enable_write_tools=true) to execute transition.
```

---

## Prohibitions

- **NEVER** write, edit, or delete any file inside `./.agents/loka-brain/` without explicit user confirmation at the Human Gate.
- **NEVER** overwrite existing files under a `MINT` action.
- **NEVER** execute a `MERGE` without verified `BASE_CONTENT` matching on-disk `BASE_HASH`.
- **NEVER** allow file mutations outside realpath containment of `./.agents/loka-brain/`.
- **NEVER** grant write permissions to `loka-mint-master` or `loka-review-master`.
- **NEVER** persist changes if the computed SHA-256 hash does not match `DRAFT_HASH` verbatim.
- **NEVER** run `index.sh` before the newly written or merged file has passed `audit.sh`.
- **NEVER** accept host-specific or private system terms (e.g. host-specific containers or internal kernel references) inside Knowledge Artifacts.
- **NEVER** include the legacy `time` field in newly minted or updated frontmatter.
- **NEVER** retain a minted or mutated file if the post-write `audit.sh` check produces any errors or warnings.
