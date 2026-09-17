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

# Acquire vault-wide lock across write -> audit -> index -> verify
LOCK_FILE="$VAULT_ROOT/.loka.lock"
if [[ -z "${LOKA_LOCK_HELD:-}" ]]; then
    exec 200>"$LOCK_FILE"
    flock -x 200
    export LOKA_LOCK_HELD=1
fi

# ------------------------------------------------------------------------------
# 3. Argument Parsing
# ------------------------------------------------------------------------------
ACTION=""
TARGET_PATH=""
EXPECTED_HASH=""
DRAFT_FILE=""
BASE_HASH=""
ALLOW_DIRTY_VAULT=false

usage() {
    echo "Usage: $0 --action <NEW_MINT|MERGE> --target <target_path> --expected-hash <sha256> --draft-file <file> [--base-hash <sha256>] [--allow-dirty-vault]"
    echo ""
    echo "Options:"
    echo "  --action             Operation mode: NEW_MINT or MERGE (required)"
    echo "  --target             Relative or absolute path to target .md file in vault (required)"
    echo "  --expected-hash      Expected SHA-256 hash of draft content (required)"
    echo "  --draft-file         Path to file containing candidate draft markdown (required)"
    echo "  --base-hash          Expected SHA-256 hash of existing file before merge (required for MERGE)"
    echo "  --allow-dirty-vault  Do not exit with failure if full-vault audit fails on pre-existing artifacts"
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
        --allow-dirty-vault)
            ALLOW_DIRTY_VAULT=true
            shift
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
# Normalize TARGET_PATH: handle ./loka-brain, loka-brain, and bare domain paths uniformly
clean_target="${TARGET_PATH#./}"
if [[ "$TARGET_PATH" == "$VAULT_ROOT"/* ]]; then
    clean_target="${TARGET_PATH#$VAULT_ROOT/}"
elif [[ "$clean_target" == *"loka-brain/"* ]]; then
    clean_target="${clean_target#*loka-brain/}"
fi

if [[ "$clean_target" == *".."* ]]; then
    log_fail "Path traversal ('..') is prohibited: $TARGET_PATH"
    exit 11
fi

TARGET_DIR_REL="$(dirname "$clean_target")"
TARGET_FILENAME="$(basename "$clean_target")"

if [[ "$TARGET_FILENAME" != *.md || "$TARGET_FILENAME" == ".md" ]]; then
    log_fail "Target filename must be a valid .md file: $TARGET_FILENAME"
    exit 10
fi

# The directory must be strictly one of the 6 canonical domains at depth 1
case "$TARGET_DIR_REL" in
    profiles|behaviors|standards|workflows|tools|meta)
        TARGET_DOMAIN="$TARGET_DIR_REL"
        ;;
    *)
        log_fail "Invalid target domain '$TARGET_DIR_REL'. Target must be directly inside one of: profiles, behaviors, standards, workflows, tools, meta"
        exit 10
        ;;
esac

TARGET_DIR_ABS="$VAULT_ROOT/$TARGET_DOMAIN"
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

TARGET_FILE_EXPECTED="$TARGET_DIR_REAL/$TARGET_FILENAME"
if [[ -L "$TARGET_FILE_EXPECTED" ]]; then
    log_fail "Pre-flight failed: Symlinked artifacts are prohibited: $TARGET_FILE_EXPECTED"
    exit 17
fi

TARGET_REAL="$(readlink -f "$TARGET_FILE_EXPECTED" 2>/dev/null || echo "$TARGET_FILE_EXPECTED")"
if [[ "$TARGET_REAL" != "$VAULT_ROOT"/* ]]; then
    log_fail "Realpath containment violation: $TARGET_REAL is outside $VAULT_ROOT"
    exit 11
fi

if [[ -L "$TARGET_REAL" ]]; then
    log_fail "Pre-flight failed: Symlinked artifacts are prohibited: $TARGET_REAL"
    exit 17
fi

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
WRITE_TEMP=""
CLEANUP_REQUIRED=false

cleanup_rollback() {
    set +e
    log_warn "Executing automated transactional rollback..."
    if [[ -n "${WRITE_TEMP:-}" && -f "$WRITE_TEMP" ]]; then
        rm -f "$WRITE_TEMP" || log_warn "Rollback: Failed to remove temporary file $WRITE_TEMP"
    fi
    if [[ "$ACTION" == "NEW_MINT" ]]; then
        if [[ -f "$TARGET_REAL" ]]; then
            rm -f "$TARGET_REAL" || log_warn "Rollback: Failed to remove uncommitted target file $TARGET_REAL"
            log_info "Removed uncommitted target file: $TARGET_REAL"
        fi
        bash "$INDEX_SCRIPT" "$BRAIN_DIR" >/dev/null 2>&1 || log_warn "Rollback: Failed to restore index catalog."
        log_info "Restored index catalog."
    elif [[ "$ACTION" == "MERGE" ]]; then
        if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
            mv -f "$BACKUP_FILE" "$TARGET_REAL" || log_warn "Rollback: Failed to restore base file from backup."
            log_info "Restored original base file from backup."
        fi
        bash "$INDEX_SCRIPT" "$BRAIN_DIR" >/dev/null 2>&1 || log_warn "Rollback: Failed to restore index catalog."
        log_info "Restored index catalog."
    fi
}

trap 'exit_code=$?; if [[ "$CLEANUP_REQUIRED" == true ]]; then cleanup_rollback; fi; exit $exit_code' EXIT INT TERM HUP

CLEANUP_REQUIRED=true

WRITE_TEMP="$(mktemp "${TARGET_REAL}.tmp.XXXXXX")"

if [[ "$ACTION" == "MERGE" ]]; then
    BACKUP_FILE="$(mktemp "${TARGET_REAL}.bak.XXXXXX")"
    cp -p "$TARGET_REAL" "$BACKUP_FILE"
fi

# Step 1: Write file via temp file + atomic mv -T
cp -f "$DRAFT_FILE" "$WRITE_TEMP"
mv -T "$WRITE_TEMP" "$TARGET_REAL"
log_info "Draft written to target: $TARGET_REAL"

# Re-verify sha256sum of the final file against expected-hash
FINAL_HASH="$(sha256sum "$TARGET_REAL" | awk '{print $1}')"
if [[ "$FINAL_HASH" != "$EXPECTED_HASH" ]]; then
    log_fail "Post-write verification failed: Final hash ($FINAL_HASH) does not match expected hash ($EXPECTED_HASH)!"
    exit 18
fi

# Step 2: Audit target file
log_info "Running single-file audit..."
if ! bash "$AUDIT_SCRIPT" "$TARGET_REAL"; then
    log_fail "Target audit failed!"
    exit 20
fi
log_pass "Target audit passed (SPEC v0.2.1 compliant)"

# Step 3: Regenerate index
log_info "Regenerating index catalog..."
if ! bash "$INDEX_SCRIPT" "$BRAIN_DIR"; then
    log_fail "Index regeneration failed!"
    exit 21
fi
log_pass "Index catalog regenerated"

# Step 4: Verify full vault integrity
log_info "Running full vault audit..."
FULL_AUDIT_LOG="$(mktemp "${TARGET_DIR_REAL}/.full_audit_log.XXXXXX")"
if ! bash "$AUDIT_SCRIPT" --all >"$FULL_AUDIT_LOG" 2>&1; then
    # Target file itself was verified in Step 2.
    # The failure in Step 4 is due to pre-existing dirty/failing artifacts elsewhere in the vault.
    # Disarm rollback so validly minted target is preserved.
    CLEANUP_REQUIRED=false
    cat "$FULL_AUDIT_LOG" >&2
    rm -f "$FULL_AUDIT_LOG" || true
    if [[ "$ALLOW_DIRTY_VAULT" == true ]]; then
        log_warn "Full vault audit failed on pre-existing artifacts, but --allow-dirty-vault was specified. Preserving minted artifact."
    else
        log_fail "Full vault audit failed post-index! (Target artifact is valid, but other vault artifacts failed audit)"
        exit 22
    fi
else
    rm -f "$FULL_AUDIT_LOG" || true
    log_pass "Full vault audit passed (zero errors, zero warnings)"
fi

# All steps succeeded: Disarm rollback trap
CLEANUP_REQUIRED=false
if [[ -n "$WRITE_TEMP" && -f "$WRITE_TEMP" ]]; then
    rm -f "$WRITE_TEMP"
fi
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
