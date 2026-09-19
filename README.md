# LOKA — Local Open Knowledge Artifact

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

LOKA is a governed knowledge vault for AI coding agents. Knowledge lives as versioned Markdown files with machine-parseable frontmatter (Knowledge Artifacts, KA), organized in six domains and cataloged in a progressive-disclosure index. Agents read only what a task needs; every write to the vault passes a human confirmation gate and a transactional engine with rollback.

- **Plain files:** Markdown + frontmatter, no database, no embeddings, no vector store.
- **Deterministic tooling:** Python CLI (standard library only) for formatting, indexing, lifecycle changes, and transactional writes.
- **Human in control:** All mutations require explicit custodian approval, verified by a SHA-256 hash of the approved draft.
- **Portable:** The vault is independent of any agent runtime and can be embedded in any project.

## Contents

- [How It Works](#how-it-works)
- [Installation](#installation)
- [Host Project Integration](#host-project-integration)
- [Quickstart](#quickstart)
- [Vault Structure](#vault-structure)
- [Skills](#skills)
- [CLI Reference](#cli-reference)
- [Requirements](#requirements)
- [Tests](#tests)
- [Documentation](#documentation)
- [License](#license)

## How It Works

1. **Discovery:** The agent reads the root `AGENTS.md`, which points to the consumption contract [`LOKA.md`](.agents/loka-brain/LOKA.md) and the operating contract [`.agents/AGENTS.md`](.agents/AGENTS.md).
2. **Targeted retrieval:** The agent reads the catalog [`index.md`](.agents/loka-brain/index.md) and loads 1–3 relevant artifacts per task instead of the whole vault.
3. **Authoring and review:** Knowledge is proposed and evaluated by two read-only orchestrators (`mint-master`, `review-master`) inside the `loka` skill. They cannot write to the vault.
4. **Human Gate:** The candidate and its SHA-256 `DRAFT_HASH` are presented to the human custodian.
5. **Execution:** After approval, a privileged write worker runs `loka mint` (or `promote` / `deprecate`). The engine verifies the hash, writes atomically, formats frontmatter, regenerates the index, and rolls back on any failure.

Skill activation depends on the agent runtime: it must discover skills under `.agents/skills/` and match user intent against the `description` in each `SKILL.md`.

Example prompt: `Mint this pattern as a standard: <text>`

## Installation

LOKA is a directory, not a package. There is no build step; the CLI needs only Python 3.

### Standalone

Use the repository itself as the vault:

```bash
git clone https://github.com/Budtender3000/loka-master.git
cd loka-master
python3 .agents/skills/loka/scripts/loka.py format --all --check
```

Update with `git pull`.

### Embedded in an existing project

Run in the root of the host project:

```bash
curl -sL https://codeload.github.com/Budtender3000/loka-master/tar.gz/refs/tags/v0.3.0 \
  | tar -xz --strip-components=1 loka-master-0.3.0/.agents loka-master-0.3.0/AGENTS.template.md
{ echo; cat AGENTS.template.md; } >> AGENTS.md && rm AGENTS.template.md
```

This adds `.agents/` (skills, operating contract, empty vault) and appends the LOKA snippet to the host `AGENTS.md` (see [Host Project Integration](#host-project-integration)). Commit `.agents/` with the project.

### Updating an embedded installation

`.agents/loka-brain/` contains the user's artifacts and `index.md`. Update only the framework files:

```bash
tmp=$(mktemp -d)
curl -sL https://codeload.github.com/Budtender3000/loka-master/tar.gz/refs/tags/v0.3.0 \
  | tar -xz --strip-components=1 -C "$tmp"
rm -rf .agents/skills && cp -r "$tmp/.agents/skills" .agents/skills
cp "$tmp/.agents/AGENTS.md" .agents/AGENTS.md
cp "$tmp/.agents/loka-brain/LOKA.md" "$tmp/.agents/loka-brain/schema.md" .agents/loka-brain/
rm -rf "$tmp"
```

Never overwrite artifacts in the domain folders. `index.md` is regenerated with `loka index`.

### Not supported

- **Git submodules / subtrees:** The framework lives in `.agents/`, not in the repository root; all paths are relative to the host project root.
- **Package managers (pip, uv):** There is no installable Python package.

## Host Project Integration

Append the snippet from [`AGENTS.template.md`](AGENTS.template.md) to the root `AGENTS.md` (or `GEMINI.md` / `CODEX.md`) of the host project:

```markdown
# LOKA

- **ENFORCE** `./.agents/loka-brain/LOKA.md` as the authoritative knowledge consumption and retrieval contract before planning, designing, or modifying code.
- **ENFORCE** `./.agents/AGENTS.md` for workspace operating contract, custodian mandate, risk tiers, and skill delegation.
```

`LOKA.md` governs read-only consumption of the vault. `.agents/AGENTS.md` governs custody, risk tiers, and delegation of vault operations to the `loka` skill. Host application code outside `./.agents/` is not restricted by either file.

## Quickstart

Run all commands from the project root.

### 1. Check the empty vault

```console
$ python3 .agents/skills/loka/scripts/loka.py format --all --check
No files found to format.
```

### 2. Create an artifact

Create `.agents/loka-brain/standards/code-review.md`:

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

### 3. Format-check, index, promote

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

### 4. Strict validation

Copy the artifact to `.agents/loka-brain/standards/invalid-sample.md` and set `deprecated: nope`. `loka index` skips defective artifacts with a warning on `stderr`; with `--strict` it exits with code `1`:

```console
$ python3 .agents/skills/loka/scripts/loka.py index --strict
WARNING: Skipping .agents/loka-brain/standards/invalid-sample.md in index: Invalid deprecated 'nope' (must be true or false)
Index updated: .agents/loka-brain/index.md
$ echo $?
1
```

To reset after testing, delete the example artifacts and run `loka index` again.

## Vault Structure

```
.agents/
├── AGENTS.md              operating contract (custody, risk tiers, delegation)
├── loka-brain/            the vault
│   ├── LOKA.md            consumption and retrieval contract
│   ├── schema.md          Knowledge Artifact schema v0.3.0
│   ├── index.md           generated catalog
│   └── profiles/ behaviors/ standards/ workflows/ tools/ meta/
└── skills/
    ├── loka/              lifecycle orchestration + CLI
    ├── loka-git-manager/  local Git operations
    └── loka-log/          session logs and handovers
```

Each artifact lives one level deep in exactly one domain folder.

### Frontmatter

| Field | Requirement | Values |
|---|---|---|
| `id` | required | kebab-case; equals the filename stem |
| `name` | required | display name; equals the H1 |
| `type` | required | enum: `profile`, `behavior`, `standard`, `workflow`, `tool`, `meta`; must equal the parent domain folder in singular form |
| `description` | required | one line, shown in the index |
| `status` | optional | `draft` → `test` → `active` |
| `deprecated` | optional | `true` / `false` |
| `created`, `stale_after` | optional | `YYYY-MM-DD` |
| `verified` | optional | `human`, `attested`, `automated` |
| `owner`, `sources` | optional | owner identifier; list of double-quoted strings |

Full specification: [`schema.md`](.agents/loka-brain/schema.md).

### Lifecycle

Status progresses strictly one step at a time (`draft` → `test` → `active`). Deprecation is an independent flag and does not change the status.

## Skills

| Skill | Version | Purpose | Path |
|---|---|---|---|
| `loka` | 0.3.0 | Dual-master orchestrator for minting, review, lifecycle promotion, and deprecation. | [`SKILL.md`](.agents/skills/loka/SKILL.md) |
| `loka-git-manager` | 0.2.1 | Local Git operations: pre-flight checks, atomic Conventional Commits, secret scans, sync verification. | [`SKILL.md`](.agents/skills/loka-git-manager/SKILL.md) |
| `loka-log` | 0.2.7 | Session logging, log queries, and handover capture. | [`SKILL.md`](.agents/skills/loka-log/SKILL.md) |

## CLI Reference

```console
python3 .agents/skills/loka/scripts/loka.py <command> [options]
```

| Command | Arguments / Options | Description |
|---|---|---|
| `format` | `[files...]`, `--all`, `--check`, `--vault VAULT` | Normalize frontmatter key order, quoting, and whitespace. |
| `index` | `[vault]`, `--strict` | Generate the `index.md` catalog. With `--strict`, exits `1` if artifacts were skipped. |
| `promote` | `file`, `--vault VAULT` | Advance status by one step. |
| `deprecate` | `file`, `--vault VAULT` | Set `deprecated: true`. |
| `undeprecate` | `file`, `--vault VAULT` | Set `deprecated: false`. |
| `mint` | `--action {NEW_MINT,MERGE}`, `--target TARGET`, `--draft-file DRAFT_FILE`, `[--expected-hash HASH]`, `--base-hash HASH` (MERGE only), `[--vault VAULT]` | Transactional write with path containment, SHA-256 verification, and rollback. |

**Exit codes:** `0` success (warnings allowed in non-strict mode); `1` validation failure, syntax error, `--check` found differences, or artifacts skipped under `--strict`.

**Environment:** `LOKA_BRAIN_ROOT` overrides the path to the vault directory.

## Requirements

- Python 3, standard library only.
- Git, for `loka-git-manager`.
- For the mint/review pipeline: an agent runtime that supports subagents with write tools disabled (developed against Antigravity). The CLI and the vault work without any agent.

## Tests

```console
python3 -m unittest discover -s ./.agents/skills/loka/scripts/tests
```

## Documentation

- [Knowledge Artifact Schema v0.3.0](.agents/loka-brain/schema.md)
- [Consumption Contract](.agents/loka-brain/LOKA.md)
- [Workspace Operating Contract](.agents/AGENTS.md)
- [`loka` skill reference](.agents/skills/loka/README.md)
- [Changelog](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE).
