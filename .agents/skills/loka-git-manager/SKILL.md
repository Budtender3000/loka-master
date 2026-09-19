---
name: loka-git-manager
description: Use for all local Git operations in any repository; pre-flight checks, atomic Conventional Commits, secret and debug scanning, dirty worktree recovery, and local tagging. Trigger whenever git commits, status verification, branch safety, or tags are needed.
type: skill
version: 0.2.1
owner: USER
---

# LOKA GIT MANAGER

Provides strict, deterministic local Git operations for any repository across the ecosystem.

---

## 1. Operating Boundaries

- **EXECUTE** all Git operations strictly within the confirmed active repository.
- **DO NOT** execute automatic push operations without explicit user approval.
- **DO NOT** push to the `main` branch without explicit user approval.
- **RECOMMEND** `git push -u <remote> <branch>` on the first user-approved push of a branch without upstream to configure tracking.
- **DO NOT** treat a bare `## <branch>` from `git status -sb` (lacking `...<remote>/<branch>`) as evidence of synchronization; treat it strictly as unconfigured upstream.
- **VERIFY** remote sync claims strictly via raw output of `git fetch` followed by `git rev-list --left-right --count HEAD...<remote>/<branch>` (expecting `0 0`) or matching commit hashes via `git rev-parse HEAD <remote>/<branch>`.
- **CREATE** Git tags strictly after explicit user approval.
- **DO NOT** create GitHub releases or execute `gh` CLI commands in this skill.
- **DO NOT** switch repository contexts or execute operations across parent directories.

---

## 2. Hard STOP Rules

> **ABSOLUTE STOP — REPORT TO USER**
> Stop immediately and report the finding when encountering:
> - Unclear repository root or CWD mismatch.
> - Unexpected staged files or unstaged changes unrelated to the current task.
> - Merge conflicts, detached HEAD, or ambiguous branch state.
> - Secrets, credentials, tokens, or debug markers detected during pre-commit scans.

---

## 3. Mandatory Pre-Flight Check

- **VERIFY** repository root and working tree state before every Git operation:

```bash
echo "PWD:      $(pwd)"
echo "Git Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'NOT IN A REPO')"
echo "Branch:   $(git branch --show-current)"
git status --short --branch
```

- **STOP** and ask the user if `git rev-parse --show-toplevel` fails or does not match the intended workspace.

---

## 4. Commit Workflow

1. **RUN** the mandatory pre-flight check.
2. **INSPECT** modified files with `git status -s`.
3. **ISOLATE** related changes to ensure atomic commits (one logical change per commit).
4. **RUN** debug and secret scans on staged changes.
5. **FORMAT** the commit message strictly according to Conventional Commits.
6. **STAGE** matching files explicitly: `git add <files>`.
7. **EXECUTE** commit: `git commit -m "<type>[scope]: <description>"`.
8. **CONFIRM** commit result: `git log -1 --oneline`.

---

## 5. Conventional Commits Standard

Format: `<type>[optional scope]: <description>`

Types:
- `feat`: New feature or capability
- `fix`: Bug fix
- `docs`: Documentation changes only
- `refactor`: Code changes that neither fix bugs nor add features
- `chore`: Maintenance, dependencies, or tooling
- `style`: Formatting, whitespace, or visual styling
- `perf`: Performance improvements
- `test`: Adding or correcting tests

---

## 6. Secret & Debug Protection

- **SCAN** only files staged for the current commit before committing:

```bash
git diff --cached --check
git diff --cached -G '(password|passwd|secret|token|api[_-]?key|private[_-]?key)' -- .
```

- **STOP** immediately if secrets, credentials, or private keys are detected.

---

## 7. Recovery Protocol

- **EXECUTE** when encountering a dirty working tree requiring recovery:
  1. **DISPLAY** current `git status`.
  2. **SAVE** all uncommitted changes to a patch file before making changes:
     ```bash
     git diff > recovery.patch
     ```
  3. **REQUIRE** explicit user confirmation before any `git reset`, `git checkout --`, or stash operation.
