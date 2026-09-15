#!/usr/bin/env bash
# ==============================================================================
# test_mid_pipeline_rollback.sh
# Empirical test harness for loka apply_mint.sh mid-pipeline rollback
# Tests Step 2 (Audit Failure -> Exit 20) and Step 3 (Index Failure -> Exit 21)
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Dynamic Path Resolution & Environment
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [[ -d "$REPO_ROOT/.agents/loka-brain" ]]; then
    BRAIN_ROOT="$REPO_ROOT/.agents/loka-brain"
elif [[ -d "$REPO_ROOT/loka-brain" ]]; then
    BRAIN_ROOT="$REPO_ROOT/loka-brain"
else
    BRAIN_ROOT="$REPO_ROOT/LOKA-brain"
fi
APPLY_MINT="$SCRIPT_DIR/apply_mint.sh"
AUDIT_SCRIPT="$SCRIPT_DIR/audit.sh"

if [[ ! -f "$APPLY_MINT" || ! -f "$AUDIT_SCRIPT" || ! -d "$BRAIN_ROOT" ]]; then
    echo "ERROR: Failed to resolve workspace directories relative to script." >&2
    exit 1
fi

SCRATCH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loka_rollback_test.XXXXXX")"
trap 'rm -rf "$SCRATCH_DIR"' EXIT

echo "=== 0. BASELINE REPOSITORY STATE ==="
INITIAL_LOKA_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo 'NONE')"
INITIAL_BRAIN_COMMIT="$(git -C "$BRAIN_ROOT" rev-parse HEAD 2>/dev/null || echo 'NONE')"
INITIAL_INDEX_HASH="$(sha256sum "$BRAIN_ROOT/index.md" 2>/dev/null | awk '{print $1}' || echo 'NONE')"

echo "LOKA HEAD:         $INITIAL_LOKA_COMMIT"
echo "BRAIN HEAD:        $INITIAL_BRAIN_COMMIT"
echo "index.md SHA-256:  $INITIAL_INDEX_HASH"

git_status_brain="$(git -C "$BRAIN_ROOT" status --porcelain 2>/dev/null || true)"
if [[ -n "$git_status_brain" ]]; then
    echo "ERROR: loka-brain working tree dirty before test!" >&2
    exit 1
fi
echo "loka-brain tree:   CLEAN"

# ------------------------------------------------------------------------------
# TEST 1: NEW_MINT — Fault in Step 2: audit.sh (Exit 20)
# ------------------------------------------------------------------------------
echo ""
echo "=== TEST 1: NEW_MINT — Fault in Step 2 (audit.sh) ==="
MINT_TARGET_REL="tools/fault-injection-mint.md"
MINT_TARGET_ABS="$BRAIN_ROOT/$MINT_TARGET_REL"
MINT_DRAFT="$SCRATCH_DIR/draft_mint_fault.md"

rm -f "$MINT_TARGET_ABS"

cat << 'EOF' > "$MINT_DRAFT"
---
id: fault_injection_mint
name: Fault Injection Mint
type: tool
status: draft
deprecated: false
description: Verifies automated transactional rollback on post-write audit failure.
created: 2026-09-07
owner: custodian
undeclared_fault_probe: mid_pipeline_failure
---

# Fault Injection Mint

## Context
**Problem:** Need to verify atomic rollback after mutation.
**Solution:** Candidate triggers audit.sh schema failure after file creation.

## Mechanism
- **Principle:** Post-mutation fault trigger.
- **Structure:** Schema purity violation.

## Rules
- ROLLBACK MUST REMOVE THIS FILE.
EOF

MINT_DRAFT_HASH="$(sha256sum "$MINT_DRAFT" | awk '{print $1}')"

set +e
MINT_OUTPUT="$(bash "$APPLY_MINT" --action NEW_MINT --target "$MINT_TARGET_REL" --expected-hash "$MINT_DRAFT_HASH" --draft-file "$MINT_DRAFT" 2>&1)"
MINT_EXIT_CODE=$?
set -e

if [[ "$MINT_EXIT_CODE" -eq 20 && ! -e "$MINT_TARGET_ABS" ]]; then
    echo "  [PASS] Test 1: Exit 20, target removed by rollback"
else
    echo "  [FAIL] Test 1 failed (exit: $MINT_EXIT_CODE, target exists: $(test -e "$MINT_TARGET_ABS" && echo YES || echo NO))"
    exit 1
fi

# ------------------------------------------------------------------------------
# TEST 2: MERGE — Fault in Step 2: audit.sh (Exit 20)
# ------------------------------------------------------------------------------
echo ""
echo "=== TEST 2: MERGE — Fault in Step 2 (audit.sh) ==="
MERGE_TARGET_REL="tools/tooling-safety-and-containment-policy.md"
MERGE_TARGET_ABS="$BRAIN_ROOT/$MERGE_TARGET_REL"
MERGE_DRAFT="$SCRATCH_DIR/draft_merge_fault.md"

PRE_MERGE_TARGET_HASH="$(sha256sum "$MERGE_TARGET_ABS" | awk '{print $1}')"

awk '
NR==9 {
    print "undeclared_fault_probe: mid_pipeline_merge_failure"
}
{ print }
' "$MERGE_TARGET_ABS" > "$MERGE_DRAFT"

MERGE_DRAFT_HASH="$(sha256sum "$MERGE_DRAFT" | awk '{print $1}')"

set +e
MERGE_OUTPUT="$(bash "$APPLY_MINT" --action MERGE --target "$MERGE_TARGET_REL" --expected-hash "$MERGE_DRAFT_HASH" --draft-file "$MERGE_DRAFT" --base-hash "$PRE_MERGE_TARGET_HASH" 2>&1)"
MERGE_EXIT_CODE=$?
set -e

POST_MERGE_TARGET_HASH="$(sha256sum "$MERGE_TARGET_ABS" | awk '{print $1}')"

if [[ "$MERGE_EXIT_CODE" -eq 20 && "$POST_MERGE_TARGET_HASH" == "$PRE_MERGE_TARGET_HASH" ]]; then
    echo "  [PASS] Test 2: Exit 20, target restored byte-identical to base ($POST_MERGE_TARGET_HASH)"
else
    echo "  [FAIL] Test 2 failed (exit: $MERGE_EXIT_CODE)"
    exit 2
fi

# ------------------------------------------------------------------------------
# TEST 3: NEW_MINT — Audit PASS -> Fault in Step 3: index.sh (Exit 21)
# ------------------------------------------------------------------------------
echo ""
echo "=== TEST 3: NEW_MINT — Audit PASS -> Fault in Step 3 (index.sh) ==="
STEP3_MINT_TARGET_REL="tools/valid-test-mint.md"
STEP3_MINT_TARGET_ABS="$BRAIN_ROOT/$STEP3_MINT_TARGET_REL"
STEP3_MINT_DRAFT="$SCRATCH_DIR/valid-test-mint.md"

rm -f "$STEP3_MINT_TARGET_ABS"

cat << 'EOF' > "$STEP3_MINT_DRAFT"
---
id: valid_test_mint
name: Valid Test Mint
type: tool
status: draft
deprecated: false
description: Test artifact for Step 3 index regeneration fault injection.
created: 2026-09-07
owner: custodian
---

# Valid Test Mint

## Context
**Problem:** Valid artifact needed to test Step 3 index failure after successful audit.
**Solution:** 100% compliant SPEC v0.2.1 artifact.

## Mechanism
- **Principle:** Passes single-file audit.
- **Structure:** Triggers downstream rollback when index.sh fails.

## Rules
- ROLLBACK MUST REMOVE THIS FILE.
EOF

STEP3_MINT_DRAFT_HASH="$(sha256sum "$STEP3_MINT_DRAFT" | awk '{print $1}')"

# Temporarily corrupt index start marker to trigger index.sh failure
sed -i 's/<!-- AUTO-INDEX:START -->/<!-- AUTO-INDEX:START_MUTATED -->/' "$BRAIN_ROOT/index.md"

set +e
STEP3_MINT_OUTPUT="$(bash "$APPLY_MINT" --action NEW_MINT --target "$STEP3_MINT_TARGET_REL" --expected-hash "$STEP3_MINT_DRAFT_HASH" --draft-file "$STEP3_MINT_DRAFT" 2>&1)"
STEP3_MINT_EXIT_CODE=$?
set -e

# Restore index marker immediately
sed -i 's/<!-- AUTO-INDEX:START_MUTATED -->/<!-- AUTO-INDEX:START -->/' "$BRAIN_ROOT/index.md"

if [[ "$STEP3_MINT_EXIT_CODE" -eq 21 && ! -e "$STEP3_MINT_TARGET_ABS" ]]; then
    echo "  [PASS] Test 3: Exit 21 (Audit PASS -> Index FAIL), target removed by rollback"
else
    echo "  [FAIL] Test 3 failed (exit: $STEP3_MINT_EXIT_CODE, target exists: $(test -e "$STEP3_MINT_TARGET_ABS" && echo YES || echo NO))"
    exit 3
fi

# ------------------------------------------------------------------------------
# TEST 4: MERGE — Audit PASS -> Fault in Step 3: index.sh (Exit 21)
# ------------------------------------------------------------------------------
echo ""
echo "=== TEST 4: MERGE — Audit PASS -> Fault in Step 3 (index.sh) ==="
STEP4_MERGE_DRAFT="$SCRATCH_DIR/valid_merge_draft.md"

PRE_STEP4_TARGET_HASH="$(sha256sum "$MERGE_TARGET_ABS" | awk '{print $1}')"

sed 's/AST-safe edits\./AST-safe edits and atomic transactional guarantees\./' "$MERGE_TARGET_ABS" > "$STEP4_MERGE_DRAFT"
STEP4_MERGE_DRAFT_HASH="$(sha256sum "$STEP4_MERGE_DRAFT" | awk '{print $1}')"

# Temporarily corrupt index start marker
sed -i 's/<!-- AUTO-INDEX:START -->/<!-- AUTO-INDEX:START_MUTATED -->/' "$BRAIN_ROOT/index.md"

set +e
STEP4_MERGE_OUTPUT="$(bash "$APPLY_MINT" --action MERGE --target "$MERGE_TARGET_REL" --expected-hash "$STEP4_MERGE_DRAFT_HASH" --draft-file "$STEP4_MERGE_DRAFT" --base-hash "$PRE_STEP4_TARGET_HASH" 2>&1)"
STEP4_MERGE_EXIT_CODE=$?
set -e

# Restore index marker
sed -i 's/<!-- AUTO-INDEX:START_MUTATED -->/<!-- AUTO-INDEX:START -->/' "$BRAIN_ROOT/index.md"

POST_STEP4_TARGET_HASH="$(sha256sum "$MERGE_TARGET_ABS" | awk '{print $1}')"

if [[ "$STEP4_MERGE_EXIT_CODE" -eq 21 && "$POST_STEP4_TARGET_HASH" == "$PRE_STEP4_TARGET_HASH" ]]; then
    echo "  [PASS] Test 4: Exit 21 (Audit PASS -> Index FAIL), target restored byte-identical ($POST_STEP4_TARGET_HASH)"
else
    echo "  [FAIL] Test 4 failed (exit: $STEP4_MERGE_EXIT_CODE)"
    exit 4
fi

# ------------------------------------------------------------------------------
# FINAL VAULT & REPO VERIFICATIONS
# ------------------------------------------------------------------------------
echo ""
echo "=== FINAL VERIFICATIONS ==="

CURRENT_INDEX_HASH="$(sha256sum "$BRAIN_ROOT/index.md" | awk '{print $1}')"
if [[ "$CURRENT_INDEX_HASH" == "$INITIAL_INDEX_HASH" ]]; then
    echo "  [PASS] index.md is byte-identical to pre-test baseline"
else
    echo "  [FAIL] index.md hash changed!"
    exit 5
fi

BACKUP_FILES="$(find "$BRAIN_ROOT" -name "*.bak*")"
if [[ -z "$BACKUP_FILES" ]]; then
    echo "  [PASS] Zero backup (*.bak*) files in vault"
else
    echo "  [FAIL] Leftover backup files: $BACKUP_FILES"
    exit 5
fi

GIT_BRAIN="$(git -C "$BRAIN_ROOT" status --porcelain)"
if [[ -z "$GIT_BRAIN" ]]; then
    echo "  [PASS] LOKA-brain git working tree clean"
else
    echo "  [FAIL] Dirty LOKA-brain git tree: '$GIT_BRAIN'"
    exit 5
fi

set +e
FULL_AUDIT_OUTPUT="$(bash "$AUDIT_SCRIPT" --all 2>&1)"
AUDIT_EXIT_CODE=$?
set -e

PASSED_CHECKS="$(echo "$FULL_AUDIT_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^Passed:' | awk '{print $2}')"
WARNING_CHECKS="$(echo "$FULL_AUDIT_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^Warnings:' | awk '{print $2}')"
FAILURE_CHECKS="$(echo "$FULL_AUDIT_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^Failures:' | awk '{print $2}')"

if [[ "$AUDIT_EXIT_CODE" -eq 0 && "$FAILURE_CHECKS" -eq 0 && "$WARNING_CHECKS" -eq 0 ]]; then
    echo "  [PASS] Full vault audit green: $PASSED_CHECKS checks passed, 0 warnings, 0 failures"
else
    echo "  [FAIL] Full vault audit failed"
    exit 5
fi

echo ""
echo "=== ALL 4 MID-PIPELINE FAULT-INJECTION TESTS PASSED (100% REPRODUCIBLE) ==="
