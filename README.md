# LOKA — Local Open Knowledge Artifact

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

LOKA provides a machine-actionable Knowledge Artifact vault and deterministic tooling for AI pair-programming agents and human custodians. It replaces unstructured, prone-to-hallucination agent prompts with strictly versioned Markdown files containing machine-parseable YAML frontmatter. Knowledge is cataloged in a progressive-disclosure index and organized across six canonical domains (`profiles`, `behaviors`, `standards`, `workflows`, `tools`, `meta`). All vault state modifications enforce cryptographic human confirmation and transactional rollback to eliminate unilateral model drift.

## How to Use LOKA

LOKA is designed to be operated through an external AI coding assistant following the governance contracts defined in [`.agents/AGENTS.md`](./.agents/AGENTS.md):

1. **Bootstrap & Scope Discovery:** The agent discovers the repository entry point at [`./AGENTS.md`](./AGENTS.md), inspects [`.agents/AGENTS.md`](./.agents/AGENTS.md) as the Single Source of Truth (SSOT), and examines the vault catalog at [`.agents/loka-brain/index.md`](./.agents/loka-brain/index.md).
2. **Targeted Retrieval:** The agent identifies required operational knowledge and loads strictly 1–3 relevant artifacts via relative paths (e.g., `./standards/review.md`), minimizing context overhead.
3. **Creation & Review Pipeline:** To propose or update knowledge, the agent delegates to a read-only master prompt (`mint-master` or `review-master` from [`.agents/skills/loka/SKILL.md`](./.agents/skills/loka/SKILL.md)), which produces candidate content and computes a verbatim SHA-256 `DRAFT_HASH`.
4. **Human Gate & Execution:** The candidate and `DRAFT_HASH` are presented to the human custodian. Upon explicit approval, a privileged write worker (`writer-worker`) executes `loka mint` (or `promote`/`deprecate`) to write the file atomically, format frontmatter, and update the catalog with rollback on failure.

The entire governance framework, skills, and knowledge vault reside within [`./.agents/`](./.agents/README.md), allowing the framework to be placed directly inside any host repository alongside the root bootstrap [`./AGENTS.md`](./AGENTS.md).

## Quickstart

Run commands from the repository root using standard Python 3.

### 1. Check an Empty Vault

Checking an unpopulated vault reports zero pending formatting tasks:

```console
$ python3 .agents/skills/loka/scripts/loka.py format --all --check
No files found to format.
```

### 2. Create a Valid Artifact

Create a new standard in `.agents/loka-brain/standards/code-review.md`:

```markdown
---
id: code-review
name: Code Review Standards
type: standard
status: draft
deprecated: false
description: Baseline criteria for peer review and mechanical validation.
sources: ["https://example.com/standards/review"]
---

# Code Review Standards

## Context

Review procedures require deterministic mechanical formatting and semantic verification before deployment.

## Mechanism

Artifacts transition through unidirectional lifecycle progression from draft to test and active status.

## Rules

- Always verify frontmatter schema compliance before committing changes.
```

### 3. Verify Formatting, Indexing, and Lifecycle Promotion

Format-check the new artifact, regenerate the catalog index, and advance its status:

```console
$ python3 .agents/skills/loka/scripts/loka.py format --check .agents/loka-brain/standards/code-review.md

Format Summary:
  Files checked:  1
  Files needing changes: 0

$ python3 .agents/skills/loka/scripts/loka.py index
Index updated: .agents/loka-brain/index.md

$ python3 .agents/skills/loka/scripts/loka.py promote .agents/loka-brain/standards/code-review.md
Index updated: .agents/loka-brain/index.md
[PROMOTED] .agents/loka-brain/standards/code-review.md (draft -> test)
```

### 4. Validation Rejection in Strict Mode

When an artifact violates frontmatter syntax or semantic rules (such as `deprecated: nope`), `loka index` skips the defective file with a warning on `stderr`. Under `--strict`, it terminates with exit code `1`:

```console
$ python3 .agents/skills/loka/scripts/loka.py index --strict
WARNING: Skipping .agents/loka-brain/standards/invalid-sample.md in index: Invalid deprecated 'nope' (must be true or false)
Index updated: .agents/loka-brain/index.md
$ echo $status
1
```

## CLI Reference

The CLI entry point is located at `scripts/loka.py` under `.agents/skills/loka/`.

```console
python3 .agents/skills/loka/scripts/loka.py <command> [options]
```

| Command | Arguments / Options | Description |
|---|---|---|
| `format` | `[files...]`, `--all`, `--check`, `--vault VAULT` | Auto-format frontmatter key order, quote normalization, and whitespace mechanics. |
| `index` | `[vault]`, `--strict` | Generate deterministic `index.md` catalog. Exits `1` on `--strict` if files are skipped. |
| `promote` | `file`, `--vault VAULT` | Advance artifact lifecycle status (`draft` → `test` → `active`). |
| `deprecate` | `file`, `--vault VAULT` | Mark an artifact as deprecated (`deprecated: true`). |
| `undeprecate` | `file`, `--vault VAULT` | Restore a deprecated artifact (`deprecated: false`). |
| `mint` | `--action {NEW_MINT,MERGE}`, `--target TARGET`, `--draft-file DRAFT_FILE`, `--expected-hash HASH`, `[--base-hash HASH]`, `[--vault VAULT]` | Transactional write with path containment, SHA-256 verification, and rollback. |

### Exit Codes & Environment

- `0`: Operation succeeded (or completed with non-fatal warnings in non-strict mode).
- `1`: Validation failed, syntax error encountered, `--check` found diffs, or invalid files skipped under `--strict`.
- `LOKA_BRAIN_ROOT`: Environment variable overriding the path to the `loka-brain` vault directory.

## Requirements

- Python 3 (standard library only; zero third-party dependencies).

## Tests

Execute the test suite using Python's built-in `unittest` runner:

```console
python3 -m unittest discover -s ./.agents/skills/loka/scripts/tests
```

## Documentation & Standards

- [Vault Architecture & Skill Reference](.agents/README.md)
- [Knowledge Artifact Schema Specification v0.3.0](.agents/loka-brain/schema.md)
- [Workspace Operating Contract](.agents/AGENTS.md)
