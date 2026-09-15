---
name: loka-git-manager
description: Use for local Git operations within the active workspace (LOKA Workspace or Project Repo), including pre-flight checks, atomic Conventional Commits, debug/secret scans, recovery handling, local tags, and safe push boundaries.
type: skill
version: 2.0.0
owner: USER
---
 
# LOKA GIT MANAGER

This skill provides the local Git workflow for the LOKA repository and active project workspaces.
It manages local commits and tags without GitHub-release requirements.

---

## Out Of Scope

- No GitHub release requirement.
- No automatic push.
- No `gh` workflow.
- No Git operations outside the explicitly confirmed active context.

---

## In Scope

- Conventional Commits.
- Atomic commits: one logical change per commit.
- CWD safety protocol before every Git operation.
- Debug/secret scan before commits.
- Never revert dirty patches without explicit user approval.

---
  
## Hard STOP Rules

Stop immediately and report the finding to the user when there is:

- wrong Git root or unclear CWD
- unexpected staged files
- dirty state unrelated to the current task
- merge conflicts, detached HEAD, or unknown branch state
- unexplained version or tag mismatches
- secret, token, password, or debug findings before a commit

**Do not guess, auto-fix, or switch into parent repos.**

---

## Mode Detection & Context

Verify the current directory is a valid Git repository and establish context before any action:

```bash
git rev-parse --show-toplevel
```

* **Global Context:** Repo root resolves to the global environment.
* **Project Context:** Repo root resolves to your active project directory.

If the command fails (e.g., `fatal: not a git repository`) or the context remains ambiguous: **STOP** and ask the USER.
Do not auto-initialize (`git init`) a new repository and do not switch directories without explicit permission.

---

## Mandatory Pre-Flight

Before every Git operation:

```bash
echo "PWD:      $(pwd)"
echo "Git Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'NOT IN A REPO')"
echo "Branch:   $(git branch --show-current)"
git status --short --branch
```

---

## Commit Workflow

1. Run pre-flight.
2. Review changed files: `git status -s`.
3. Keep the commit atomic: only related changes together.
4. Run debug/secret scan.
5. Write a Conventional Commit message.
6. Commit: `git add <files>` and `git commit -m "<type>[scope]: <desc>"`.
7. Confirm: `git log -1 --oneline`.
No WIP commits. No mixed commits. Stage only explicitly matching files.

---

## Conventional Commits

```text
<type>[optional scope]: <description>
 
Types: feat | fix | docs | refactor | chore | style | perf | test
```

Examples:

- `docs: define loka entrypoint`
- `refactor: flatten package structure`
- `feat(runner): add sync adapter draft`

---

## Debug/Secret Scan

Before every commit, scan only the files staged for the current commit.

```bash
git diff --cached --check
git diff --cached -G '(password|passwd|secret|token|api[_-]?key|private[_-]?key)' -- .
```

If the staged diff contains a real secret, credential, token, password, or unclear sensitive value: **STOP** and ask the USER.

Do not scan the whole repository, `.git`, dependencies, generated files, or unrelated unstaged changes.

---

## Push And Tag Boundaries

- No automatic push.
- No push to `main` without explicit current user approval.
- Tags only after explicit user approval.
- No GitHub releases and no `gh` workflow in this skill.

---

## Recovery Rule

When the worktree is dirty and the user asks for recovery:

1. Show status.
2. Save the dirty patch to a file before removing anything.
3. No reverts, deletes, or stashes without explicit approval.
4. Decide what to keep, redesign, or remove only after the patch is saved.
