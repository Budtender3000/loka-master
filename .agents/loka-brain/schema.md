# LOKA Knowledge Artifact Format Schema

- **Specification Version:** 0.3.0
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
| `sources` | Optional | Inline Array (`["..."]`) | OKF v0.2 Provenance signal: inline YAML array of double-quoted URI or source references (`["..."]` or `[]`) matching `^\[.*\]$`. |

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
sources: ["<source_url>", ...]
---
```

- **Opening Delimiter:** Line 1 (`---`). No preceding whitespace or empty lines permitted.
- **Closing Delimiter:** Must appear on the line immediately following the last frontmatter key (`---`).
- **Key Density:** Exactly one key per line. Blank lines and empty lines inside the frontmatter block are strictly prohibited.
- **Quoting Rules:**
  - Literals: `deprecated` must remain an unquoted boolean literal (`false` or `true`). `created`, `stale_after`, and `verified` must remain unquoted literals.
  - Identifiers: `id`, `type`, `status`, and `owner` must remain unquoted strings.
  - Inline arrays: `sources` must be an inline array formatted as `["..."]` or `[]`.
  - String scalars: `name` and `description` must remain unquoted unless double quotes (`"..."`) are required. Values must be enclosed in double quotes if and only if they meet any of the following conditions:
    - Value is empty (`""`).
    - Value has leading or trailing whitespace.
    - Value begins with a YAML special or indicator character: `-`, `?`, `:`, `[`, `{`, `]`, `}`, `,`, `#`, `&`, `*`, `!`, `|`, `>`, `'`, `"`, `%`, `@`, ``` ` ```.
    - Value ends with a colon (`:`).
    - Value contains a colon followed by a space (`: `).
    - Value contains a space followed by a hash (` #`).
    - Value contains embedded double quotes (`"`), which must be escaped as `\"`.
    - Value contains flow collection indicators (`{`, `}`, `[`, `]`).
    - Value contains control or escape characters (`\n`, `\t`, `\r`).
    - Value matches a YAML boolean or null literal case-insensitively (`true`, `false`, `yes`, `no`, `null`, `~`).
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

---

## 4. Syntax & Content Hygiene Constraints

- **Code Fences:** Every opening code fence must declare an explicit language identifier (e.g. ` ```bash `, ` ```json `, ` ```markdown `, ` ```text `). Untagged code fences (` ``` `) are prohibited.
- **Obsidian Tags:** The `#tag` syntax is strictly prohibited in YAML frontmatter and Markdown body prose outside fenced code blocks.
- **Table Wikilinks:** Wikilinks enclosed in Markdown table cells (`| [[link]] |`) are prohibited.
- **Internal Link Integrity:** All internal wikilinks (`[[target]]` or `[[target|label]]`) must resolve to a valid existing Knowledge Artifact in one of the 6 canonical domain folders.
- **De-Identification:** Document bodies must not contain hardcoded local host filesystem paths (`/home/`, `/mnt/`, `/tmp/`, `/root/`).
- **Runtime Isolation:** BUDS-specific terms, modules, or identifiers (`BUDTENDER_KERNEL`, `BUDS_*`, `buds_*`) are strictly prohibited.
- **Language Standard:** Knowledge Artifact frontmatter fields, headings, prose, and rules are authored in technical English.
- **Whitespace Hygiene:** Zero trailing whitespace across the entire document.

---

## 5. Fix Class & Invariant Enforcement

Every requirement in this specification is a normative invariant evaluated as a binary `PASS` or `FAIL`. Non-blocking warnings and severity levels are prohibited.

- **`AUTO-FIX`:** Mechanically remediated exclusively via explicit invocation of `loka format`.
- **`REPORT`:** Validated by `loka-review-master` semantic review; reports binary `FAIL` upon violation and never modifies files.

| Rule / Invariant | Fix Class | Operational Remediation |
|---|---|---|
| Frontmatter key order | `AUTO-FIX` | `loka format` reorders keys to canonical sequence |
| Frontmatter quoting rules | `AUTO-FIX` | `loka format` normalizes quotes and applies required double quotes |
| Blank lines in frontmatter | `AUTO-FIX` | `loka format` strips empty lines within frontmatter block |
| Closing delimiter compactness | `AUTO-FIX` | `loka format` places closing `---` directly after last key |
| Trailing whitespace | `AUTO-FIX` | `loka format` strips trailing spaces across document |
| Final newline | `AUTO-FIX` | `loka format` ensures exactly one terminating newline |
| Opening delimiter presence | `REPORT` | `loka-review-master` reports missing opening `---` on line 1 |
| Mandatory field presence (`id`, `name`, `type`, `description`) | `REPORT` | `loka-review-master` reports missing or empty mandatory fields |
| Canonical domain & type alignment | `REPORT` | `loka-review-master` reports mismatch between `type` and parent domain folder |
| Status & deprecation enum values | `REPORT` | `loka-review-master` reports invalid `status` or non-boolean `deprecated` |
| ISO-8601 date format (`created`, `stale_after`) | `REPORT` | `loka-review-master` reports invalid date format (`YYYY-MM-DD`) |
| Trust signal values (`verified`) | `REPORT` | `loka-review-master` reports unapproved `verified` enum values |
| Sources array syntax | `REPORT` | `loka-review-master` reports invalid array syntax or non-list values |
| Schema purity | `REPORT` | `loka-review-master` reports undeclared, unknown, or legacy keys |
| Identifier equality (`id == filename_stem`) | `REPORT` | `loka-review-master` reports mismatch between `id` and filename stem |
| File placement | `REPORT` | `loka-review-master` reports artifacts outside canonical domain roots or nested subdirectories |
| Document title (single H1 matching `name` verbatim) | `REPORT` | `loka-review-master` reports missing, duplicated, or mismatched H1 |
| Heading depth | `REPORT` | `loka-review-master` reports headings at level 4 (`####`) or deeper |
| Section sequence | `REPORT` | `loka-review-master` reports non-conforming H2 section sequences |
| Code fence tagging | `REPORT` | `loka-review-master` reports untagged code blocks |
| Obsidian tag prohibition | `REPORT` | `loka-review-master` reports `#tag` in frontmatter or Markdown body prose |
| Table wikilink prohibition | `REPORT` | `loka-review-master` reports wikilinks within Markdown table cells |
| Internal wikilink integrity | `REPORT` | `loka-review-master` reports unresolvable target artifacts |
| Host path de-identification | `REPORT` | `loka-review-master` reports hardcoded host paths (`/home/`, `/mnt/`, `/tmp/`, `/root/`) |
| Runtime isolation | `REPORT` | `loka-review-master` reports foreign runtime identifiers (`buds_*`, `BUDTENDER_KERNEL`) |
