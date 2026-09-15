---
id: specification-and-schema-standards
name: Specification and Schema Standards
type: standard
status: active
deprecated: false
description: Enforces domain-pure frontmatter schemas, isolates parser fallbacks, and requires line-level code citations.
created: 2026-09-05
owner: custodian
---

# Specification and Schema Standards

## Context
**Problem:** Conflating conceptual analogies from external metadata frameworks with internal schema definitions introduces structural contradictions, while incorporating runtime parser tolerances or legacy fallbacks directly into normative specifications dilutes architectural rigor and invites legacy drift. Furthermore, asserting parser or runtime behaviors without citing line-level source code erodes epistemic credibility and mimics hallucination.
**Solution:** A strict specification engineering and schema integrity standard enforcing domain-pure field classification, direct schema parity verification against external standards, rigorous demarcation between canonical standards and non-normative parser tolerances, and mandatory forensic code citations for all tooling claims.

## Mechanism
- **Principle:** Specifications must enforce strictly canonical, domain-grounded schemas and isolate runtime tolerances into non-normative notes, with every tooling or parser claim proven by line-level code citations.
- **Structure:** Tripartite specification governance model: (1) Concrete schema classification and 1:1 format parity mapping, (2) Normative freeze separating canonical requirements from implementation fallbacks, and (3) Forensic code verification grounding parser assertions in exact line numbers.

## Implementation
```markdown
<!-- Normative Schema Definition (Canonical Fields Only) -->
| Field Name | Requirement | Type / Format | Purpose | Classification |
|---|---|---|---|---|
| `<canonical_field>` | Mandatory | String | <Domain purpose> | <Domain-specific or Generic> |

<!-- Non-Normative Implementation Tolerance Notes -->
> [!note]
> Parser tolerances (e.g. legacy alias `<legacy_alias>:` in `path/to/parser:L123`) are non-normative fallbacks and must not be treated as valid specification syntax.

<!-- Forensic Code Verification Citation -->
- Ground assertion `<tool_behavior>` in verifiable repository source (`path/to/script.sh:L45` regex `<pattern>`).
```

## Rules
- Classify every field in a specification strictly according to its concrete definition in the target domain, prohibiting assumed conceptual equivalents from external frameworks.
- Verify field parity directly against target schemas when establishing mapping tables to external formats, explicitly declaring unmatched fields as domain-specific extensions.
- Mandate strictly canonical forms within normative format specifications, enforcing a freeze against speculative extensions or backward-compatibility aliases.
- Document parser tolerances, legacy aliases, and runtime fallback keys exclusively as non-compliant implementation notes, never as valid normative syntax.
- Ground all assertions regarding tooling logic, fallback parsers, or runtime flags in exact source file paths and line numbers with verifiable extracts.
- Adhere strictly to Single Source of Truth principles to ensure specification rules are defined authoritatively without cross-artifact paraphrasing.
