# LOKA Brain — Knowledge Consumption & Retrieval Contract

> [!CAUTION]
> **VAULT INTEGRITY & READ-ONLY CONSUMPTION**
> - **TREAT** `./.agents/loka-brain/` strictly as a read-only knowledge repository.
> - **DO NOT** create, modify, rename, or delete files within `./.agents/loka-brain/`.
> - **DO NOT** execute state-modifying actions prior to completing pre-flight inspection.

## 1. Pre-Flight Knowledge Discovery

- **EXECUTE** a pre-flight inspection via `view_file` on `./.agents/loka-brain/index.md` before planning, designing, or implementing any non-trivial code, script, or schema modification.
- **IDENTIFY** applicable Knowledge Artifacts (KA) across canonical domains (`behaviors/`, `standards/`, `workflows/`, `tools/`) mapped to the active task requirements.
- **SKIP** pre-flight inspection ONLY for purely informational queries or trivial single-line typo fixes.

## 2. Economical Reading Doctrine

- **APPLY** the Economical Reading doctrine: never ingest entire repositories, directories, or the whole vault opportunistically.
- **RESTRICT** knowledge retrieval strictly to 1 to 3 essential modules per specific task.
- **LOAD** identified artifacts via `view_file` using relative paths (e.g. `./.agents/loka-brain/<domain>/<file>.md`).
- **JUSTIFY** every artifact read by explicitly tying it to an active requirement or constraint in scratchpad notes or reasoning.
- **DO NOT** perform exploratory or speculative reads across adjacent domain folders.

## 3. Knowledge Application & Safety Escalation

- **APPLY** the constraints, schemas, and standards defined in the retrieved artifacts directly to the execution plan.
- **PRIORITIZE** vault behavioral policies over default model generation patterns.
- **HALT** execution and invoke the ASK protocol if discovered artifacts contain conflicting guidance or if candidate modules leave the operational path ambiguous.
- **STATE** candidate modules and ask for custodian clarification instead of guessing.
- **DO NOT** hallucinate missing policies; report exact gaps plainly.
