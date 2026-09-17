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
        *) shift ;;
    esac
done

if [[ -z "$ACTION" || -z "$TARGET_PATH" || -z "$DRAFT_FILE" ]]; then
    echo "Error: Missing mandatory arguments (--action, --target, --draft-file)" >&2
    usage
fi

if [[ ! -f "$DRAFT_FILE" ]]; then
    echo "Error: Draft file does not exist: $DRAFT_FILE" >&2
    exit 1
fi

# Optional hash verification
if [[ -n "$EXPECTED_HASH" ]]; then
    ACTUAL_HASH="$(sha256sum "$DRAFT_FILE" | awk '{print $1}')"
    if [[ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]]; then
        echo "Error: Draft file hash ($ACTUAL_HASH) does not match expected ($EXPECTED_HASH)" >&2
        exit 1
    fi
fi

# Resolve target file path
if [[ "$TARGET_PATH" == /* ]]; then
    TARGET_FILE="$TARGET_PATH"
elif [[ "$TARGET_PATH" == "$BRAIN_DIR"/* || "$TARGET_PATH" == "./$BRAIN_DIR"/* ]]; then
    TARGET_FILE="$(readlink -f "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")"
elif [[ -n "$BRAIN_DIR" && "$TARGET_PATH" == "${BRAIN_DIR#./}"/* ]]; then
    TARGET_FILE="$(readlink -f "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")"
else
    clean_target="${TARGET_PATH#./}"
    if [[ "$clean_target" == *loka-brain/* ]]; then
        clean_target="${clean_target#*loka-brain/}"
    fi
    TARGET_FILE="$BRAIN_DIR/$clean_target"
fi

TARGET_DIR="$(dirname "$TARGET_FILE")"
mkdir -p "$TARGET_DIR"

# Pre-checks for NEW_MINT vs MERGE
BACKUP_FILE=""
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
    BACKUP_FILE="$(mktemp)"
    cp "$TARGET_FILE" "$BACKUP_FILE"
fi

# Write draft to target
cp -f "$DRAFT_FILE" "$TARGET_FILE"

# Run audit on target
if ! LOKA_BRAIN_ROOT="$BRAIN_DIR" bash "$AUDIT_SCRIPT" "$TARGET_FILE"; then
    echo "Error: Audit failed on minted artifact. Rolling back..." >&2
    if [[ "$ACTION" == "NEW_MINT" ]]; then
        rm -f "$TARGET_FILE"
    elif [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
        mv "$BACKUP_FILE" "$TARGET_FILE"
    fi
    exit 1
fi

if [[ -n "$BACKUP_FILE" && -f "$BACKUP_FILE" ]]; then
    rm -f "$BACKUP_FILE"
fi

# Update index
if [[ -f "$INDEX_SCRIPT" ]]; then
    bash "$INDEX_SCRIPT" "$BRAIN_DIR"
fi

echo ""
echo "=================================================================="
echo "STATUS: MINT_APPLIED"
echo "ACTION: $ACTION"
echo "TARGET: $TARGET_FILE"
echo "AUDIT: PASS"
echo "INDEX: REGENERATED"
echo "=================================================================="
exit 0
