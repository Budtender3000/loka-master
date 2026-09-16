#!/usr/bin/env bash
# ==============================================================================
# apply_mint.sh — LOKA Transactional Knowledge Artifact Mint & Rollback Engine
# Implements schema.md v0.2.3 atomic write, verification, catalog indexing, and rollback
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Colors & Logging
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "  ${CYAN}INFO:${NC} $*"; }
log_pass() { echo -e "  [${GREEN}PASS${NC}] $*"; }
log_fail() { echo -e "  [${RED}FAIL${NC}] $*" >&2; }
log_warn() { echo -e "  [${YELLOW}WARN${NC}] $*"; }

# ------------------------------------------------------------------------------
# 2. Path Discovery & Environment Resolution
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit.sh"
INDEX_SCRIPT="$SCRIPT_DIR/index.sh"

if [[ ! -f "$AUDIT_SCRIPT" ]]; then
    log_fail "audit.sh not found at $AUDIT_SCRIPT"
    exit 1
fi
if [[ ! -f "$INDEX_SCRIPT" ]]; then
    log_fail "index.sh not found at $INDEX_SCRIPT"
    exit 1
fi

BRAIN_DIR="${LOKA_BRAIN_ROOT:-}"
if [[ -z "$BRAIN_DIR" ]]; then
    check_dir="$SCRIPT_DIR"
    while [[ "$check_dir" != "/" ]]; do
        if [[ -d "$check_dir/loka-brain" ]]; then
            BRAIN_DIR="$check_dir/loka-brain"
            break
        fi
        check_dir="$(dirname "$check_dir")"
    done
fi

if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
    fixed_depth_dir="$(cd "$SCRIPT_DIR/../../../loka-brain" 2>/dev/null && pwd || true)"
    if [[ -z "$fixed_depth_dir" || ! -d "$fixed_depth_dir" ]]; then
        fixed_depth_dir="$(cd "$SCRIPT_DIR/../../../../loka-brain" 2>/dev/null && pwd || true)"
    fi
    if [[ -n "$fixed_depth_dir" && -d "$fixed_depth_dir" ]]; then
        BRAIN_DIR="$fixed_depth_dir"
    fi
fi

if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
    log_fail "Could not resolve loka-brain directory."
    exit 1
fi

VAULT_ROOT="$(readlink -f "$BRAIN_DIR")"

# ------------------------------------------------------------------------------
# 3. Argument Parsing
# ------------------------------------------------------------------------------
ACTION=""
TARGET_PATH=""
EXPECTED_HASH=""
DRAFT_FILE=""
BASE_HASH=""

usage() {
    echo "Usage: $0 --action <NEW_MINT|MERGE> --target <target_path> --expected-hash <sha256> --draft-file <file> [--base-hash <sha256>]"
    echo ""
    echo "Options:"
    echo "  --action        Operation mode: NEW_MINT or MERGE (required)"
    echo "  --target        Relative or absolute path to target .md file in vault (required)"
    echo "  --expected-hash Expected SHA-256 hash of draft content (required)"
    echo "  --draft-file    Path to file containing candidate draft markdown (required)"
    echo "  --base-hash     Expected SHA-256 hash of existing file before merge (required for MERGE)"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action)
            ACTION="${2:-}"
            shift 2
            ;;
        --target)
            TARGET_PATH="${2:-}"
            shift 2
            ;;
        --expected-hash)
            EXPECTED_HASH="${2:-}"
            shift 2
            ;;
        --draft-file)
            DRAFT_FILE="${2:-}"
            shift 2
            ;;
        --base-hash)
            BASE_HASH="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_fail "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$ACTION" || -z "$TARGET_PATH" || -z "$EXPECTED_HASH" || -z "$DRAFT_FILE" ]]; then
    log_fail "Missing mandatory arguments."
    usage
fi

if [[ "$ACTION" != "NEW_MINT" && "$ACTION" != "MERGE" ]]; then
    log_fail "Invalid action '$ACTION'. Must be NEW_MINT or MERGE."
    exit 1
fi

if [[ "$ACTION" == "MERGE" && -z "$BASE_HASH" ]]; then
    log_fail "Action MERGE requires --base-hash."
    exit 1
fi

if [[ ! -f "$DRAFT_FILE" ]]; then
    log_fail "Draft file does not exist: $DRAFT_FILE"
    exit 1
fi

# ------------------------------------------------------------------------------
# 4. Realpath Containment & Target Resolution
# ------------------------------------------------------------------------------
TARGET_DIR="$(dirname "$TARGET_PATH")"
TARGET_FILENAME="$(basename "$TARGET_PATH")"

if [[ ! "$TARGET_PATH" = /* ]]; then
    if [[ "$TARGET_PATH" == "./loka-brain/"* || "$TARGET_PATH" == "loka-brain/"* ]]; then
        TARGET_DIR_REL="${TARGET_DIR#*loka-brain/}"
        TARGET_DIR_ABS="$VAULT_ROOT/$TARGET_DIR_REL"
    else
        TARGET_DIR_ABS="$VAULT_ROOT/$TARGET_DIR"
    fi
else
    TARGET_DIR_ABS="$TARGET_DIR"
fi

TARGET_DIR_REAL="$(readlink -f "$TARGET_DIR_ABS" 2>/dev/null || true)"
if [[ -z "$TARGET_DIR_REAL" || ! -d "$TARGET_DIR_REAL" ]]; then
    log_fail "Target domain directory does not exist: $TARGET_DIR_ABS"
    exit 10
fi

# Strict realpath containment: Target directory must be strictly inside VAULT_ROOT
if [[ "$TARGET_DIR_REAL" != "$VAULT_ROOT"/* ]]; then
    log_fail "Realpath containment violation: $TARGET_DIR_REAL is outside $VAULT_ROOT"
    exit 11
fi

TARGET_REAL="$TARGET_DIR_REAL/$TARGET_FILENAME"

# ------------------------------------------------------------------------------
# 5. Pre-Flight Verification on Draft File
# ------------------------------------------------------------------------------
# 5.1 Trailing Whitespace Hygiene
if grep -q '[[:space:]]$' "$DRAFT_FILE"; then
    log_fail "Pre-flight failed: Draft content contains trailing whitespace (violates git pre-flight)."
    exit 12
fi

# 5.2 Cryptographic Hash Match
ACTUAL_HASH="$(sha256sum "$DRAFT_FILE" | awk '{print $1}')"
if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
    log_fail "Pre-flight failed: Cryptographic hash mismatch!"
    log_fail "  Expected: $EXPECTED_HASH"
    log_fail "  Actual:   $ACTUAL_HASH"
    exit 13
fi

# 5.3 Existence / Collision Preconditions
if [[ "$ACTION" == "NEW_MINT" ]]; then
    if [[ -e "$TARGET_REAL" ]]; then
        log_fail "Pre-flight failed: Target already exists on disk under NEW_MINT: $TARGET_REAL"
        exit 14
    fi
elif [[ "$ACTION" == "MERGE" ]]; then
    if [[ ! -f "$TARGET_REAL" ]]; then
        log_fail "Pre-flight failed: Target does not exist on disk for MERGE: $TARGET_REAL"
        exit 15
    fi
    CURRENT_BASE_HASH="$(sha256sum "$TARGET_REAL" | awk '{print $1}')"
    if [[ "$CURRENT_BASE_HASH" != "$BASE_HASH" ]]; then
        log_fail "Pre-flight failed: On-disk base hash ($CURRENT_BASE_HASH) does not match expected BASE_HASH ($BASE_HASH)"
        exit 16
    fi
fi

log_pass "Pre-flight verified: Containment, whitespace hygiene, and hash matched ($EXPECTED_HASH)"

# ------------------------------------------------------------------------------
# 6. Transactional Write & Verification Sequence
# ------------------------------------------------------------------------------
BACKUP_FILE=""
CLEANUP_REQUIRED=false

cleanup_rollback() {
    log_warn "Executing automated transactional rollback..."
    if [[ "$ACTION" == "NEW_MINT" ]]; then
        if [[ -f "$TARGET_REAL" ]]; then
            rm -f "$TARGET_REAL"
            log_info "Removed uncommitted target file: $TARGET_REAL"
        fi
        "$INDEX_SCRIPT" >/dev/null 2>&1 || true
        log_info "Restored index catalog."
    elif [[ "$ACTION" == "MERGE" ]]; then
        if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
            mv -f "$BACKUP_FILE" "$TARGET_REAL"
            log_info "Restored original base file from backup."
        fi
        "$INDEX_SCRIPT" >/dev/null 2>&1 || true
        log_info "Restored index catalog."
    fi
}

trap 'if [[ "$CLEANUP_REQUIRED" == true ]]; then cleanup_rollback; fi' EXIT

CLEANUP_REQUIRED=true

if [[ "$ACTION" == "MERGE" ]]; then
    BACKUP_FILE="$(mktemp "${TARGET_REAL}.bak.XXXXXX")"
    cp -p "$TARGET_REAL" "$BACKUP_FILE"
fi

# Step 1: Write file
cp -f "$DRAFT_FILE" "$TARGET_REAL"
log_info "Draft written to target: $TARGET_REAL"

# Step 2: Audit target file
log_info "Running single-file audit..."
if ! bash "$AUDIT_SCRIPT" "$TARGET_REAL"; then
    log_fail "Target audit failed!"
    exit 20
fi
log_pass "Target audit passed (SPEC v0.2.1 compliant)"

# Step 3: Regenerate index
log_info "Regenerating index catalog..."
if ! bash "$INDEX_SCRIPT"; then
    log_fail "Index regeneration failed!"
    exit 21
fi
log_pass "Index catalog regenerated"

# Step 4: Verify full vault integrity
log_info "Running full vault audit..."
if ! bash "$AUDIT_SCRIPT" --all >/dev/null 2>&1; then
    log_fail "Full vault audit failed post-index!"
    exit 22
fi
log_pass "Full vault audit passed (zero errors, zero warnings)"

# All steps succeeded: Disarm rollback trap
CLEANUP_REQUIRED=false
if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    rm -f "$BACKUP_FILE"
fi

echo ""
echo "=================================================================="
echo "STATUS: MINT_APPLIED"
echo "ACTION: $ACTION"
echo "TARGET: $TARGET_REAL"
echo "DRAFT_HASH: $EXPECTED_HASH (VERIFIED)"
echo "REALPATH_CONTAINMENT: PASS"
echo "AUDIT: PASS"
echo "INDEX: REGENERATED"
echo "VAULT_INTEGRITY: PASS"
echo "=================================================================="
exit 0
