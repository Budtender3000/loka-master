# LOKA GIT MANAGER — REFERENCE GUIDE

## Pre-Flight & Mode Detection Script

```bash
echo "PWD:      $(pwd)"
echo "Git Root: $(git rev-parse --show-toplevel 2>/dev/null || echo 'NOT IN A REPO')"
echo "Branch:   $(git branch --show-current)"
git status --short --branch
```

## Debug & Secret Scan Commands

Scan staged files prior to commit:

```bash
git diff --cached --check
git diff --cached -G '(password|passwd|secret|token|api[_-]?key|private[_-]?key)' -- .
```
