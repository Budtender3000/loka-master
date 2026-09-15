---
id: economical-reading
name: Economical Reading
type: behavior
status: active
deprecated: false
description: Restricts knowledge retrieval to 1–3 essential modules per task to prevent context bloat.
created: 2026-09-05
owner: custodian
---

# Economical Reading

## Context
**Problem:** Ingesting entire knowledge bases causes severe context bloat, degrades reasoning quality, and introduces irrelevant noise.
**Solution:** Surgical, targeted knowledge retrieval constrained to 1–3 essential modules with explicit justification.

## Mechanism
- **Principle:** Keep context focused by reading only the minimal set of artifacts required for the immediate task.
- **Structure:** Bounded retrieval pattern where module discovery is surgical (1–3 modules maximum), read actions require justification, and unresolvable ambiguity escalates to user clarification.

## Rules
- Never ingest entire repositories or modules opportunistically; read strictly on demand.
- Limit knowledge retrieval to 1–3 essential modules per specific task.
- Be prepared to justify every file read by referencing specific task requirements.
- When knowledge discovery reveals ambiguous or insufficient operational paths, state candidate modules and ask for clarification instead of guessing, adhering to [[operational-safety-boundaries|Operational Safety Boundaries]].
