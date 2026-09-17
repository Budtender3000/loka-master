#!/usr/bin/env bash
# ==============================================================================
# audit.sh — LOKA Knowledge Artifact Audit & Lifecycle Engine (v0.2.3)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_PARSER="$SCRIPT_DIR/lib/parse_frontmatter.sh"
INDEX_SCRIPT="$SCRIPT_DIR/index.sh"

if [[ ! -f "$LIB_PARSER" ]]; then
    echo "ERROR: Shared frontmatter parser not found at $LIB_PARSER" >&2
    exit 1
fi
source "$LIB_PARSER"

# ------------------------------------------------------------------------------
# Colors & Output
# ------------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' NC=''
fi

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

pass() {
    local msg="$1"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "    [${GREEN}PASS${NC}] $msg"
}

fail() {
    local msg="$1"
    local file="${2:-}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    if [[ -n "$file" ]]; then
        echo -e "    [${RED}FAIL${NC}] $msg ($file)" >&2
    else
        echo -e "    [${RED}FAIL${NC}] $msg" >&2
    fi
}

# ------------------------------------------------------------------------------
# Vault Resolution
# ------------------------------------------------------------------------------
BRAIN_DIR="${LOKA_BRAIN_ROOT:-}"
if [[ -z "$BRAIN_DIR" ]]; then
    for candidate in "$SCRIPT_DIR/../../../loka-brain" "$SCRIPT_DIR/../../loka-brain" "./.agents/loka-brain" "./loka-brain"; do
        if [[ -d "$candidate" ]]; then
            BRAIN_DIR="$(readlink -f "$candidate")"
            break
        fi
    done
fi

# ------------------------------------------------------------------------------
# Core Audit Function
# ------------------------------------------------------------------------------
audit_file() {
    local file="$1"
    local file_fails=0

    echo -e "\n  ${BOLD}Auditing:${NC} ${CYAN}${file}${NC}"

    if [[ ! -f "$file" ]]; then
        fail "File does not exist or is not a regular file" "$file"
        return 1
    fi

    local filename="$(basename "$file")"
    local file_stem="${filename%.md}"

    # 1. Delimiter & Frontmatter basic syntax
    local first_line
    first_line="$(head -n 1 "$file")"
    if [[ "$first_line" != "---"* ]]; then
        fail "Line 1 is not opening delimiter ---" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Opening delimiter --- present on line 1"
    fi

    # Read frontmatter fields
    local id="" name="" type="" status="" deprecated="" description="" created="" stale_after="" verified="" err=""
    while IFS='=' read -r k v; do
        case "$k" in
            ID) id="$v" ;;
            NAME) name="$v" ;;
            TYPE) type="$v" ;;
            STATUS) status="$v" ;;
            DEPRECATED) deprecated="$v" ;;
            DESCRIPTION) description="$v" ;;
            CREATED) created="$v" ;;
            STALE_AFTER) stale_after="$v" ;;
            VERIFIED) verified="$v" ;;
            ERR*) err="$v" ;;
        esac
    done < <(parse_frontmatter "$file")

    if [[ -n "$err" ]]; then
        fail "Frontmatter parsing error: $err" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "YAML frontmatter syntax and closing delimiter valid"
    fi

    # 2. Mandatory Fields
    if [[ -z "$id" || -z "$name" || -z "$type" || -z "$description" ]]; then
        fail "Missing mandatory frontmatter fields (id, name, type, description)" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "All mandatory frontmatter fields present"
    fi

    # 3. ID Validation
    if [[ ! "$id" =~ ^[a-z0-9-]+$ ]]; then
        fail "ID '$id' is not lowercase kebab-case" "$file"
        file_fails=$((file_fails + 1))
    elif [[ "$id" != "$file_stem" ]]; then
        fail "ID '$id' does not match filename stem '$file_stem'" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "ID matches filename stem ('$id')"
    fi

    # 4. Type & Domain Alignment
    local expected_type=""
    local parent_dir="$(basename "$(dirname "$(readlink -f "$file")")")"
    expected_type="$(domain_to_type "$parent_dir")"

    if [[ -z "$expected_type" ]]; then
        fail "File is not directly inside a canonical domain folder (parent: '$parent_dir')" "$file"
        file_fails=$((file_fails + 1))
    elif [[ "$type" != "$expected_type" ]]; then
        fail "Type '$type' does not match domain folder '$parent_dir' (expected '$expected_type')" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Domain alignment valid (folder '$parent_dir' matches type '$type')"
    fi

    # 5. Optional Enum Validations
    if [[ -n "$status" && ! "$status" =~ ^(draft|test|active)$ ]]; then
        fail "Invalid status '$status' (must be draft, test, or active)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$status" ]]; then
        pass "Status '$status' is valid"
    fi

    if [[ -n "$deprecated" && ! "$deprecated" =~ ^(true|false)$ ]]; then
        fail "Invalid deprecated value '$deprecated' (must be true or false)" "$file"
        file_fails=$((file_fails + 1))
    fi

    if [[ -n "$created" && ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        fail "Invalid created date '$created' (must be YYYY-MM-DD)" "$file"
        file_fails=$((file_fails + 1))
    fi

    # 6. De-identification & Isolation
    if grep -q -E "(/home/|/mnt/|/tmp/)" "$file"; then
        fail "Hardcoded host filesystem paths detected (/home/, /mnt/, /tmp/)" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "De-identification verified (no hardcoded host paths)"
    fi

    if grep -q -i -E '(BUDTENDER_KERNEL|buds_)' "$file"; then
        fail "Runtime isolation leak detected (buds_* or BUDTENDER_KERNEL)" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Runtime isolation verified (zero buds_* leaks)"
    fi

    # 7. Document Structure & H1 Heading
    local h1_title
    h1_title="$(awk '
        NR == 1 && /^---/ { in_fm = 1; next; }
        in_fm && /^---/ { in_fm = 0; next; }
        !in_fm && /^# / { sub(/^# +/, ""); print; exit; }
    ' "$file")"

    if [[ -z "$h1_title" ]]; then
        fail "Missing level-1 heading (# <Title>) after frontmatter" "$file"
        file_fails=$((file_fails + 1))
    elif [[ "$h1_title" != "$name" ]]; then
        fail "H1 title '$h1_title' does not match frontmatter name '$name'" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "H1 title matches frontmatter name verbatim"
    fi

    # 8. Section Sequence & Tokens
    local h2_headings
    h2_headings="$(grep -E '^## ' "$file" | sed 's/^## //' | tr '\n' ',' | sed 's/,$//')"
    if [[ "$h2_headings" != "Context,Mechanism,Rules" && "$h2_headings" != "Context,Mechanism,Implementation,Rules" ]]; then
        fail "H2 sections must be 'Context -> Mechanism -> Rules' or 'Context -> Mechanism -> Implementation -> Rules' (found: '$h2_headings')" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "H2 section sequence valid ($h2_headings)"
    fi

    if ! grep -q '\*\*Problem:\*\*' "$file" || ! grep -q '\*\*Solution:\*\*' "$file"; then
        fail "## Context missing mandatory **Problem:** or **Solution:** tokens" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Context tokens present (**Problem:**, **Solution:**)"
    fi

    if ! grep -q -- '- \*\*Principle:\*\*' "$file" || ! grep -q -- '- \*\*Structure:\*\*' "$file"; then
        fail "## Mechanism missing mandatory - **Principle:** or - **Structure:** items" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Mechanism tokens present (- **Principle:**, - **Structure:**)"
    fi

    # 9. Code Fences & Obsidian Tags
    local untagged_code
    untagged_code="$(awk '/^```/ { in_c = !in_c; if (in_c && $0 ~ /^```[[:space:]]*$/) print NR; }' "$file")"
    if [[ -n "$untagged_code" ]]; then
        fail "Untagged code fence on line $untagged_code (explicit language tag required)" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Code fence syntax verified (all fences tagged)"
    fi

    local forbidden_tags
    forbidden_tags="$(awk '
        /^```/ { in_code = !in_code; next; }
        !in_code && /(^|[[:space:]])#[a-zA-Z0-9_-]+/ {
            if ($0 !~ /^[[:space:]]*#[[:space:]]/) { print $0; }
        }
    ' "$file")"

    if [[ -n "$forbidden_tags" ]]; then
        fail "Forbidden Obsidian tags found outside code blocks" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Obsidian tag check passed (zero forbidden #tags found)"
    fi

    # 10. Wikilinks & Whitespace Hygiene
    if grep -q -E "^\|.*\[\[.*\]\].*\|" "$file"; then
        fail "Forbidden navigational wikilinks inside markdown table cells" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Wikilink table placement check passed"
    fi

    if grep -q '[[:space:]]$' "$file"; then
        fail "Trailing whitespace detected" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Whitespace hygiene verified (zero trailing whitespace)"
    fi

    if [[ "$file_fails" -eq 0 ]]; then
        echo -e "    ${GREEN}${BOLD}Result: APPROVED${NC}"
        return 0
    else
        echo -e "    ${RED}${BOLD}Result: REJECTED ($file_fails failures)${NC}"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Promotion & Deprecation Helpers
# ------------------------------------------------------------------------------
promote_file() {
    local target="$1"
    if ! audit_file "$target"; then
        echo -e "\n${RED}Cannot promote: target artifact failed audit.${NC}" >&2
        return 1
    fi

    if grep -q "^status:" "$target"; then
        sed -i 's/^status:.*$/status: active/' "$target"
    else
        sed -i '/^type:/a status: active' "$target"
    fi

    echo -e "\n${GREEN}Promoted to active:${NC} $target"
    if [[ -f "$INDEX_SCRIPT" && -n "$BRAIN_DIR" ]]; then
        bash "$INDEX_SCRIPT" "$BRAIN_DIR"
    fi
}

set_deprecation() {
    local target="$1"
    local state="$2" # true or false

    if ! audit_file "$target"; then
        echo -e "\n${RED}Cannot modify: target artifact failed audit.${NC}" >&2
        return 1
    fi

    if grep -q "^deprecated:" "$target"; then
        sed -i "s/^deprecated:.*$/deprecated: $state/" "$target"
    elif grep -q "^status:" "$target"; then
        sed -i "/^status:/a deprecated: $state" "$target"
    else
        sed -i "/^type:/a deprecated: $state" "$target"
    fi

    echo -e "\n${GREEN}Updated deprecation flag (deprecated: $state):${NC} $target"
    if [[ -f "$INDEX_SCRIPT" && -n "$BRAIN_DIR" ]]; then
        bash "$INDEX_SCRIPT" "$BRAIN_DIR"
    fi
}

# ------------------------------------------------------------------------------
# Main Dispatcher
# ------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $0 [options] [file]

Options:
  --all                 Audit all knowledge artifacts across all 6 canonical domains
  --promote <file>      Audit and advance candidate artifact to status: active
  --deprecate <file>    Set deprecated: true
  --undeprecate <file>  Set deprecated: false
  -h, --help            Show this help message

Examples:
  $0 ./.agents/loka-brain/profiles/my-profile.md
  $0 --all
  $0 --promote ./.agents/loka-brain/workflows/my-workflow.md
EOF
    exit 0
}

MODE="single"
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            MODE="all"
            shift
            ;;
        --promote)
            MODE="promote"
            TARGET_FILE="${2:-}"
            shift 2
            ;;
        --deprecate)
            MODE="deprecate"
            TARGET_FILE="${2:-}"
            shift 2
            ;;
        --undeprecate)
            MODE="undeprecate"
            TARGET_FILE="${2:-}"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$TARGET_FILE" && "$1" != -* ]]; then
                TARGET_FILE="$1"
                shift
            else
                echo "Unknown option: $1" >&2
                usage
            fi
            ;;
    esac
done

case "$MODE" in
    promote)
        [[ -z "$TARGET_FILE" ]] && { echo "Error: --promote requires a file" >&2; exit 1; }
        promote_file "$TARGET_FILE"
        ;;
    deprecate)
        [[ -z "$TARGET_FILE" ]] && { echo "Error: --deprecate requires a file" >&2; exit 1; }
        set_deprecation "$TARGET_FILE" "true"
        ;;
    undeprecate)
        [[ -z "$TARGET_FILE" ]] && { echo "Error: --undeprecate requires a file" >&2; exit 1; }
        set_deprecation "$TARGET_FILE" "false"
        ;;
    single)
        if [[ -n "$TARGET_FILE" ]]; then
            audit_file "$TARGET_FILE"
            exit $?
        else
            MODE="all"
        fi
        ;;
esac

if [[ "$MODE" == "all" ]]; then
    if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
        echo "ERROR: Could not resolve loka-brain directory." >&2
        exit 1
    fi

    artifacts=()
    for domain in "${CANONICAL_DOMAINS[@]}"; do
        domain_dir="$BRAIN_DIR/$domain"
        [[ ! -d "$domain_dir" ]] && continue
        while IFS= read -r -d '' f; do
            artifacts+=("$f")
        done < <(find "$domain_dir" -maxdepth 1 -name "*.md" -type f ! -name "index.md" ! -name "schema.md" -print0 | sort -z)
    done

    artifact_count=${#artifacts[@]}
    if [[ $artifact_count -eq 0 ]]; then
        echo "No artifacts found in $BRAIN_DIR across canonical domains."
        exit 0
    fi

    failed_artifacts=0
    for art in "${artifacts[@]}"; do
        if ! audit_file "$art"; then
            failed_artifacts=$((failed_artifacts + 1))
        fi
    done

    echo -e "\n=== Audit Summary ==="
    echo "Total Artifacts: $artifact_count"
    echo "Total Checks:    $TOTAL_CHECKS"
    echo "Passed Checks:   $PASSED_CHECKS"
    echo "Failed Checks:   $FAILED_CHECKS"

    if [[ $failed_artifacts -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}Result: AUDIT PASSED${NC}"
        exit 0
    else
        echo -e "${RED}${BOLD}Result: AUDIT FAILED ($failed_artifacts artifacts failed)${NC}"
        exit 1
    fi
fi
