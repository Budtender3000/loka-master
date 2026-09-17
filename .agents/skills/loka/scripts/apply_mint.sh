#!/usr/bin/env bash
# ==============================================================================
# apply_mint.sh — LOKA Knowledge Artifact Mint & Write Engine
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/audit.sh"
INDEX_SCRIPT="$SCRIPT_DIR/index.sh"

BRAIN_DIR="${LOKA_BRAIN_ROOT:-}"
if [[ -z "$BRAIN_DIR" ]]; then
    for candidate in "$SCRIPT_DIR/../../../loka-brain" "$SCRIPT_DIR/../../loka-brain" "./.agents/loka-brain" "./loka-brain"; do
        if [[ -d "$candidate" ]]; then
            BRAIN_DIR="$(readlink -f "$candidate")"
            break
        fi
    done
fi

if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
    echo "Error: Could not resolve valid loka-brain directory." >&2
    exit 1
fi
BRAIN_DIR="$(readlink -f "$BRAIN_DIR")"

ACTION=""
TARGET_PATH=""
EXPECTED_HASH=""
DRAFT_FILE=""
BASE_HASH=""
ALLOW_DIRTY_VAULT=false

usage() {
    cat <<EOF
Usage: $0 --action <NEW_MINT|MERGE> --target <target_path> --draft-file <file> [--expected-hash <sha256>] [--base-hash <sha256>] [--allow-dirty-vault]
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action) ACTION="${2:-}"; shift 2 ;;
        --target) TARGET_PATH="${2:-}"; shift 2 ;;
        --expected-hash) EXPECTED_HASH="${2:-}"; shift 2 ;;
        --draft-file) DRAFT_FILE="${2:-}"; shift 2 ;;
        --base-hash) BASE_HASH="${2:-}"; shift 2 ;;
        --allow-dirty-vault) ALLOW_DIRTY_VAULT=true; shift ;;
        -h|--help) usage ;;
        *) echo "Error: Unknown option '$1'" >&2; usage ;;
    esac
done

if [[ -z "$ACTION" || -z "$TARGET_PATH" || -z "$DRAFT_FILE" ]]; then
    echo "Error: Missing mandatory arguments (--action, --target, --draft-file)" >&2
    usage
fi

if [[ "$ACTION" != "NEW_MINT" && "$ACTION" != "MERGE" ]]; then
    echo "Error: Invalid action '$ACTION' (must be NEW_MINT or MERGE)" >&2
    usage
fi

if [[ ! -f "$DRAFT_FILE" ]]; then
    echo "Error: Draft file does not exist: $DRAFT_FILE" >&2
    exit 1
fi

# Optional expected draft hash verification
if [[ -n "$EXPECTED_HASH" ]]; then
    ACTUAL_HASH="$(sha256sum "$DRAFT_FILE" | awk '{print $1}')"
    if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
        echo "Error: Draft file hash ($ACTUAL_HASH) does not match expected ($EXPECTED_HASH)" >&2
        exit 1
    fi
fi

# Resolve target file path
if [[ "$TARGET_PATH" == /* ]]; then
    TARGET_CANDIDATE="$TARGET_PATH"
elif [[ "$TARGET_PATH" == "$BRAIN_DIR"/* || "$TARGET_PATH" == "./$BRAIN_DIR"/* ]]; then
    TARGET_CANDIDATE="$TARGET_PATH"
elif [[ "$TARGET_PATH" == "${BRAIN_DIR#./}"/* ]]; then
    TARGET_CANDIDATE="$TARGET_PATH"
else
    clean_target="${TARGET_PATH#./}"
    if [[ "$clean_target" == *loka-brain/* ]]; then
        clean_target="${clean_target#*loka-brain/}"
    fi
    TARGET_CANDIDATE="$BRAIN_DIR/$clean_target"
fi

# Canonical containment check against BRAIN_DIR
TARGET_REAL="$(readlink -m "$TARGET_CANDIDATE")"
if [[ "$TARGET_REAL" != "$BRAIN_DIR"/* ]]; then
    echo "Error: Target path outside brain vault containment: $TARGET_REAL" >&2
    exit 1
fi

if [[ -L "$TARGET_CANDIDATE" || -L "$TARGET_REAL" ]]; then
    echo "Error: Symlink targets are prohibited: $TARGET_CANDIDATE" >&2
    exit 1
fi

TARGET_FILE="$TARGET_REAL"
TARGET_DIR="$(dirname "$TARGET_FILE")"
mkdir -p "$TARGET_DIR"

BACKUP_FILE=""
ROLLBACK_NEEDED=false

cleanup() {
    local exit_code=$?
    if [[ "$ROLLBACK_NEEDED" == true ]]; then
        echo "Error: Operation failed or was interrupted. Rolling back..." >&2
        if [[ "$ACTION" == "NEW_MINT" ]]; then
            rm -f "$TARGET_FILE"
        elif [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
            mv -f "$BACKUP_FILE" "$TARGET_FILE"
        fi
    fi
    if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
        rm -f "$BACKUP_FILE"
    fi
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

# Pre-checks for NEW_MINT vs MERGE
if [[ "$ACTION" == "NEW_MINT" ]]; then
    if [[ -e "$TARGET_FILE" ]]; then
        echo "Error: Target already exists under NEW_MINT: $TARGET_FILE" >&2
        exit 1
    fi
elif [[ "$ACTION" == "MERGE" ]]; then
    if [[ ! -f "$TARGET_FILE" ]]; then
        echo "Error: Target does not exist for MERGE: $TARGET_FILE" >&2
        exit 1
    fi
    if [[ -n "$BASE_HASH" ]]; then
        ACTUAL_BASE_HASH="$(sha256sum "$TARGET_FILE" | awk '{print $1}')"
        if [[ "$ACTUAL_BASE_HASH" != "$BASE_HASH" ]]; then
            echo "Error: Target base hash ($ACTUAL_BASE_HASH) does not match expected base-hash ($BASE_HASH)" >&2
            exit 1
        fi
    fi
    BACKUP_FILE="$(mktemp)"
    cp -p "$TARGET_FILE" "$BACKUP_FILE"
fi

# Write draft to target with rollback armed
ROLLBACK_NEEDED=true
cp -f "$DRAFT_FILE" "$TARGET_FILE"

# 1. Run audit on target
if ! LOKA_BRAIN_ROOT="$BRAIN_DIR" bash "$AUDIT_SCRIPT" "$TARGET_FILE"; then
    echo "Error: Audit failed on minted artifact." >&2
    exit 1
fi

# 2. Update index
if [[ -f "$INDEX_SCRIPT" ]]; then
    if ! bash "$INDEX_SCRIPT" "$BRAIN_DIR"; then
        echo "Error: Index update failed." >&2
        exit 1
    fi
fi

# 3. Run full-vault audit unless dirty vault is explicitly allowed
if [[ "$ALLOW_DIRTY_VAULT" == false ]]; then
    if ! LOKA_BRAIN_ROOT="$BRAIN_DIR" bash "$AUDIT_SCRIPT" --all; then
        echo "Error: Vault audit failed post-mint." >&2
        exit 1
    fi
fi

# Successful completion
ROLLBACK_NEEDED=false

echo ""
echo "=================================================================="
echo "STATUS: MINT_APPLIED"
echo "ACTION: $ACTION"
echo "TARGET: $TARGET_FILE"
echo "AUDIT: PASS"
echo "INDEX: REGENERATED"
echo "=================================================================="
exit 0
