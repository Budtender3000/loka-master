---
id: runtime-vault-boundary-standards
name: Runtime Vault Boundary Standards
type: standard
status: active
deprecated: false
description: Restricts runtime tooling to structural schema parsing, decoupling host environments from vault domain content.
created: 2026-09-06
owner: custodian
---

# Runtime Vault Boundary Standards

## Context
**Problem:** Conflating structural schema parsing with semantic domain policy in runtime tooling couples the host environment tightly to vault contents, breaking runtime execution when domain knowledge evolves and destroying the standalone portability of the knowledge vault.
**Solution:** A normative boundary and non-entanglement standard restricting runtime tooling to structural, schema-agnostic operations, prohibiting semantic domain coupling, establishing bidirectional acid tests, and enforcing strict self-containment for all vault artifacts.

## Mechanism
- **Principle:** Host runtimes must interact with knowledge vaults exclusively as a structural data substrate through canonical schemas, remaining completely blind to domain semantics and internal knowledge policies.
- **Structure:** Decoupled tripartite boundary architecture: (1) Structural vs. Semantic coupling demarcation, (2) Bidirectional acid test evaluation (Semantic Fragility and Standalone Portability), and (3) Non-normative implementation isolation via [[specification-and-schema-standards|Specification and Schema Standards]].

## Implementation
```text
[ Host Runtime: Tooling & Agents ]
  │ (Structural Operations Only: AST parsing, Frontmatter validation, Link extraction)
  ▼
┌─────────────────────────────────────────────────────────────┐
│ Normative Boundary Interface: schema.md                      │
└─────────────────────────────────────────────────────────────┘
  ▲
  │ (Self-Contained Knowledge Substrate: Profiles, Behaviors, Standards, Workflows)
[ Knowledge Vault: Portable Artifacts ]
```

## Rules
- Restrict external runtime tooling, validation scripts, and agent behaviors exclusively to structural coupling (schema validation, YAML delimiter checks, AST traversal, and link graph extraction).
- Prohibit runtime scripts, skills, and tools from embedding semantic domain logic, hardcoding artifact identifiers, or branching conditionally on domain policies.
- Enforce the Semantic Fragility Test (Vault → Runtime): modifications to vault domain policies, profiles, or workflows that satisfy [[specification-and-schema-standards|Specification and Schema Standards]] must never require code changes in host runtime scripts.
- Enforce the Standalone Portability Test (Runtime → Vault): every artifact in the knowledge vault must remain fully functional and semantically complete when extracted into an external environment without host tooling.
- Prohibit vault artifacts from containing wikilinks, directory paths, or configuration references pointing outside the knowledge vault boundary into host runtime environments.
- Reference implementation tolerances and parser fallback defenses strictly via [[specification-and-schema-standards|Specification and Schema Standards]], adhering to Single Source of Truth principles to prevent rule duplication.
