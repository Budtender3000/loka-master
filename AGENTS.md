# LOKA — Workspace Operating Contract & Agent Governance

## 1. Project Identity & Scope

- **OPERATE** within the confirmed boundary of LOKA (Local Open Knowledge Artifact).
- **TREAT** `./.agents/loka-brain/` as the modular, machine-actionable Knowledge Artifact vault, governed strictly by its internal `./.agents/loka-brain/AGENTS.md`.
- **CONFINE** all verification lookups and evidence searches strictly to the active workspace.
- **EXCLUDE** all foreign architecture, private host terminology, and container concepts from this repository.

## 2. Operational Safety & Execution Thresholds

- Governed by `./.agents/loka-brain/AGENTS.md` §2.2.

## 3. Context Economy & Economical Reading

- Governed by `./.agents/loka-brain/AGENTS.md` §3.2.

## 4. Runtime-Vault Decoupling & Boundary Standards

- Governed by `./.agents/loka-brain/AGENTS.md` §1.

## 5. Specification & Schema Integrity

- Governed by `./.agents/loka-brain/AGENTS.md` §2.3 and §4.1.

## 6. Execution & Verification Discipline

### 6.1 Dynamic Execution Workflow
- **EXECUTE** non-trivial tasks through a structured 5-stage progression:
  1. Scope Analysis: Deconstruct requirements and identify active operational boundaries.
  2. Index Lookup: Consult `./.agents/loka-brain/index.md` to locate relevant knowledge modules.
  3. Targeted Knowledge Retrieval: Retrieve strictly 1 to 3 essential modules under Economical Reading.
  4. Plan Formulation & Execution: Apply retrieved domain standards and execute atomic changes.
  5. Standardized Output Verification: Validate outputs against domain schemas and output contracts before release.

### 6.2 Verification Discipline & Failure Recovery
- **FOLLOW** every code or file modification immediately with active verification before declaring completion or staging commits.
- **DISCOVER** and execute targeted repository tests whenever a test runner (`pytest`, `npm test`, `cargo test`) exists.
- **APPLY** verification fallbacks (syntax compilation checks `py_compile`, `node --check`, `bash -n` and minimal smoke tests) when no automated test suite exists.
- **REMEDIATE** regressions immediately; if unresolvable, cleanly roll back modified files to their prior verified baseline.
- **PROHIBIT** committing, pushing, or reporting tasks as complete when verification fails.
- **PERFORM** diagnostic analysis of stderr and exit codes upon encountering tool errors.
- **CHECK** argument syntax, parameter names, and path containment against documentation before attempting retries.
- **RESTRICT** parameter-corrected retries strictly to exactly one attempt (`Retry ONCE`).
- **ABORT** execution immediately if a retry fails or an internal engine error occurs; infinite retry loops and polling iterations are forbidden.

## 7. Response Structure & Output Protocols

- **DELIVER** direct, concise results without structural boilerplate for trivial single-step tasks.
- **STRUCTURE** non-trivial responses strictly in the following 4-part sequence:
  1. **Result:** Primary deliverable or explicit blocked statement.
  2. **Assumptions:** Explicitly labeled assumptions (if any).
  3. **Open Questions:** Maximum 2 decision-critical questions (if needed).
  4. **Next Step:** Concrete, smallest viable increment.
- **PREPEND** standardized status labels when execution halts, requires input, or completes non-trivial tasks:
  - `OK:` Task completed successfully.
  - `NEED-INFO:` Mandatory parameter or specification missing.
  - `CANNOT-VERIFY:` Environment or safety cannot be validated.
  - `STOP-RISK:` Destructive or unsafe operation blocked pending explicit confirmation.
  - `CONFLICT:` Contradictory directives detected.
- **EMIT** Strict JSON (valid JSON, zero comments, no trailing commas, zero undeclared keys) whenever structured data or `--json` is requested.
- **RUN** a pre-submission quality gate validating prompt fulfillment, factual grounding, format adherence, and safety boundaries before submitting responses.

## 8. Operational Safety & Skill Delegation

- **DELEGATE** the minting, auditing, indexing, and lifecycle promotion of Knowledge Artifacts exclusively to `loka`.
- **DELEGATE** local Git workflows (pre-flight checks, atomic Conventional Commits, branch hygiene, secret scanning) exclusively to `loka-git-manager`.
- **DELEGATE** session logging, context handover, and state capture to `loka-log`.
- **DO NOT** execute ad-hoc Git commits, branch modifications, or destructive operations outside designated skills.
- **EXCLUDE** secrets, credentials, and machine-local state from tracking, verifying `.gitignore` coverage before staging.
