# LOKA Knowledge Artifact Format Schema

- **Specification Version:** 0.2.3
- **Scope:** Normative structural and syntactic format schema for Knowledge Artifacts (`./.agents/loka-brain/`)

---

## 1. Frontmatter Schema

Every Knowledge Artifact must begin on line 1 with a YAML frontmatter block enclosed between `---` delimiters. No preceding whitespace, empty lines, or characters are permitted.

### 1.1 Field Definitions

| Field Name | Requirement | Type / Format | Validation Constraint |
|---|---|---|---|
| `id` | Mandatory | String (`^[a-z0-9-]+$`) | Unique lowercase `kebab-case` identifier. Must match the filename stem exactly without conversion. |
| `name` | Mandatory | String (UTF-8) | Human-readable artifact title. Must match the level-1 Markdown heading (`# <Title>`) verbatim. |
| `type` | Mandatory | Enum String | Canonical domain: `profile`, `behavior`, `standard`, `workflow`, `tool`, `meta`. Must match the parent domain folder name in singular form. |
| `description` | Mandatory | String (UTF-8) | Non-empty concise single-line description surfaced in index catalogs (`index.md`) for progressive disclosure. |
| `status` | Optional | Enum String | Operational lifecycle status: `draft`, `test`, `active`. If omitted, the artifact is treated as unpromoted working draft. |
| `deprecated` | Optional | Boolean Literal | Supersession flag: `false` or `true`. Defaults to `false` if omitted. |
| `created` | Optional | ISO-8601 Date (`YYYY-MM-DD`) | Creation date matching `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. Emitted unquoted. |
| `stale_after` | Optional | ISO-8601 Date (`YYYY-MM-DD`) | OKF v0.2 Freshness trust signal matching `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. Emitted unquoted. |
| `owner` | Optional | String (UTF-8) | Custodian tracking identifier (e.g. `custodian`). |
| `verified` | Optional | Enum String | OKF v0.2 Trustworthiness signal: `human`, `attested`, or `automated`. Emitted unquoted. |
| `sources` | Optional | Inline Array (`["..."]`) | OKF v0.2 Provenance signal: inline JSON/YAML array of URI or source references matching `^\[.*\]$`. |

### 1.2 Canonical Key Order & Formatting Rules

When present, frontmatter keys must appear in the following relative order:

```yaml
---
id: <kebab-case-identifier>
name: <Title Matching H1 Verbatim>
type: <profile|behavior|standard|workflow|tool|meta>
status: <draft|test|active>
deprecated: <false|true>
description: <Concise single line description>
created: YYYY-MM-DD
stale_after: YYYY-MM-DD
owner: <custodian_identifier>
verified: <human|attested|automated>
sources: [<source_url>, ...]
---
```

- **Opening Delimiter:** Line 1 (`---`).
- **Closing Delimiter:** Must reside on line $2 + \text{present\_valid\_fields}$ (`---`). With all 4 mandatory fields present and 0 optional fields, the closing delimiter is on line 6; with all 7 optional fields present, it is on line 13.
- **Quoting Rules:** `deprecated`, `created`, `stale_after`, and `verified` must remain unquoted literals. `sources` must be an inline array (`["..."]` or `[]`). `description` must remain unquoted unless containing characters with special YAML syntactic meaning (`:`, `{`, `}`, `[`, `]`).
- **Schema Purity:** Zero undeclared keys, legacy aliases (such as `time`), or unknown fields are permitted.

---

## 2. File Placement & Domain Mapping

### 2.1 File System Invariants

- **Location:** Artifacts must reside strictly one level deep under their designated canonical domain directory (`./<domain>/<filename>.md`). Subdirectories within domain folders are prohibited.
- **Filename Pattern:** Filename stem must match `^[a-z0-9-]+\.md$` (lowercase kebab-case).
- **Identifier Equality:** The frontmatter `id` must match the filename stem exactly (`id == filename_stem`). No character substitution or case conversion is permitted.

### 2.2 Canonical Domain Mapping

| Domain Directory | Canonical `type` Value |
|---|---|
| `profiles/` | `profile` |
| `behaviors/` | `behavior` |
| `standards/` | `standard` |
| `workflows/` | `workflow` |
| `tools/` | `tool` |
| `meta/` | `meta` |

---

## 3. Document Structure & Heading Hierarchy

### 3.1 Document Title (H1)

- Exactly one level-1 heading (`# <Title>`) must appear immediately after the closing frontmatter delimiter, separated by a single blank line.
- The title text must match the frontmatter `name` value verbatim.
- Additional H1 headings or empty headings anywhere in the document body are prohibited.

### 3.2 Heading Depth

- Section depth beneath H1 is restricted to level-2 (`##`) and level-3 (`###`) headings only.

### 3.3 Section Sequence

Every Knowledge Artifact must conform to one of the following two exact H2 heading sequences:

**3-Section Sequence:**
1. `## Context`
2. `## Mechanism`
3. `## Rules`

**4-Section Sequence:**
1. `## Context`
2. `## Mechanism`
3. `## Implementation`
4. `## Rules`

### 3.4 Mandatory Section Tokens

- **`## Context`:** Must contain explicit `**Problem:**` and `**Solution:**` tokens.
- **`## Mechanism`:** Must contain explicit `- **Principle:**` and `- **Structure:**` list items.
- **`## Implementation`:** Optional section for illustrative code fences, schemas, or structural templates.
- **`## Rules`:** Mandatory bulleted list of normative constraints and operational boundaries.

---

## 4. Syntax & Content Hygiene Constraints

- **Code Fences:** Every opening code fence must declare an explicit language identifier (e.g. ` ```bash `, ` ```json `, ` ```markdown `, ` ```text `). Untagged code fences (` ``` `) are prohibited.
- **Obsidian Tags:** The `#tag` syntax is strictly prohibited in YAML frontmatter and Markdown body prose outside fenced code blocks.
- **Table Wikilinks:** Wikilinks enclosed in Markdown table cells (`| [[link]] |`) are prohibited.
- **Internal Link Integrity:** All internal wikilinks (`[[target]]` or `[[target|label]]`) must resolve to a valid existing Knowledge Artifact in one of the 6 canonical domain folders.
- **De-Identification:** Document bodies must not contain hardcoded local host filesystem paths (`/home/`, `/mnt/`, `/tmp/`, `/root/`).
- **Secrets:** Hardcoded tokens, API keys, credentials, or private variables are prohibited.
- **Runtime Isolation:** BUDS-specific terms, modules, or identifiers (`BUDTENDER_KERNEL`, `BUDS_*`, `buds_*`) are strictly prohibited.
- **Whitespace Hygiene:** Zero trailing whitespace across the entire document.
