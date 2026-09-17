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
    if [[ ! "$first_line" =~ ^---[[:space:]]*$ ]]; then
        fail "Line 1 is not opening delimiter ---" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Opening delimiter --- present on line 1"
    fi

    # Helper for relative key ordering
    key_rank() {
        case "$1" in
            ID) echo 1 ;;
            NAME) echo 2 ;;
            TYPE) echo 3 ;;
            STATUS) echo 4 ;;
            DEPRECATED) echo 5 ;;
            DESCRIPTION) echo 6 ;;
            CREATED) echo 7 ;;
            STALE_AFTER) echo 8 ;;
            OWNER) echo 9 ;;
            VERIFIED) echo 10 ;;
            SOURCES) echo 11 ;;
            *) echo 99 ;;
        esac
    }

    # Read frontmatter fields
    local id="" name="" type="" status="" deprecated="" description="" created=""
    local stale_after="" owner="" verified="" sources="" closing_line=""
    local err="" unknown_keys=() field_count=0
    local current_rank=0 order_valid=true

    while IFS='=' read -r k v; do
        case "$k" in
            ID) id="$v"; field_count=$((field_count + 1)) ;;
            NAME) name="$v"; field_count=$((field_count + 1)) ;;
            TYPE) type="$v"; field_count=$((field_count + 1)) ;;
            STATUS) status="$v"; field_count=$((field_count + 1)) ;;
            DEPRECATED) deprecated="$v"; field_count=$((field_count + 1)) ;;
            DESCRIPTION) description="$v"; field_count=$((field_count + 1)) ;;
            CREATED) created="$v"; field_count=$((field_count + 1)) ;;
            STALE_AFTER) stale_after="$v"; field_count=$((field_count + 1)) ;;
            OWNER) owner="$v"; field_count=$((field_count + 1)) ;;
            VERIFIED) verified="$v"; field_count=$((field_count + 1)) ;;
            SOURCES) sources="$v"; field_count=$((field_count + 1)) ;;
            CLOSING_LINE) closing_line="$v"; continue ;;
            ERR*) err="$v"; continue ;;
            *) unknown_keys+=("$k"); continue ;;
        esac

        local rank
        rank="$(key_rank "$k")"
        if [[ "$rank" -le "$current_rank" && "$rank" -ne 99 ]]; then
            order_valid=false
        fi
        current_rank="$rank"
    done < <(parse_frontmatter "$file")

    if [[ -n "$err" ]]; then
        fail "Frontmatter parsing error: $err" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "YAML frontmatter syntax valid"
    fi

    # Schema Purity Check
    if [[ ${#unknown_keys[@]} -gt 0 ]]; then
        fail "Schema purity violation: undeclared frontmatter key(s): ${unknown_keys[*]}" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Schema purity verified (zero undeclared keys)"
    fi

    # Closing Delimiter Line Arithmetic
    local expected_closing_line=$((field_count + 2))
    if [[ -n "$closing_line" && "$closing_line" -ne "$expected_closing_line" ]]; then
        fail "Closing delimiter line mismatch (line $closing_line, expected $expected_closing_line for $field_count fields)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$closing_line" ]]; then
        pass "Closing delimiter arithmetic valid (line $closing_line matches $field_count fields)"
    fi

    # Canonical Key Order Check
    if [[ "$order_valid" == false ]]; then
        fail "Frontmatter keys violate canonical relative order" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Canonical key order verified"
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

    # 5. Optional Enum & Trust Signal Validations
    if [[ -n "$status" && ! "$status" =~ ^(draft|test|active)$ ]]; then
        fail "Invalid status '$status' (must be draft, test, or active)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$status" ]]; then
        pass "Status '$status' is valid"
    fi

    if [[ -n "$deprecated" && ! "$deprecated" =~ ^(true|false)$ ]]; then
        fail "Invalid deprecated value '$deprecated' (must be true or false)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$deprecated" ]]; then
        pass "Deprecated flag is valid ($deprecated)"
    fi

    if [[ -n "$created" && ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        fail "Invalid created date '$created' (must be YYYY-MM-DD)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$created" ]]; then
        pass "Created date is valid ($created)"
    fi

    if [[ -n "$stale_after" && ! "$stale_after" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        fail "Invalid stale_after date '$stale_after' (must be YYYY-MM-DD)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$stale_after" ]]; then
        pass "Freshness trust signal (stale_after) is valid ($stale_after)"
    fi

    if [[ -n "$verified" && ! "$verified" =~ ^(human|attested|automated)$ ]]; then
        fail "Invalid verified value '$verified' (must be human, attested, or automated)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$verified" ]]; then
        pass "Trustworthiness signal (verified) is valid ($verified)"
    fi

    if [[ -n "$sources" && ! "$sources" =~ ^\[.*\]$ ]]; then
        fail "Invalid sources format '$sources' (must be inline array matching ^\\[.*\\]$)" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$sources" ]]; then
        pass "Provenance signal (sources) is valid"
    fi

    if [[ -n "$owner" && ! "$owner" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        fail "Invalid owner format '$owner'" "$file"
        file_fails=$((file_fails + 1))
    elif [[ -n "$owner" ]]; then
        pass "Custodian owner signal is valid ($owner)"
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

    # 7. Document Structure, H1 Heading & Depth
    local h1_count
    h1_count="$(awk '
        NR == 1 && /^---/ { in_fm = 1; next; }
        in_fm && /^---/ { in_fm = 0; next; }
        !in_fm {
            if (/^```/) { in_code = !in_code; next; }
            if (!in_code && /^# /) { print NR; }
        }
    ' "$file" | wc -l)"

    if [[ "$h1_count" -ne 1 ]]; then
        fail "Document must contain exactly one level-1 heading (# <Title>), found $h1_count" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Exactly one level-1 heading present"
    fi

    local h1_title
    h1_title="$(awk '
        NR == 1 && /^---/ { in_fm = 1; next; }
        in_fm && /^---/ { in_fm = 0; next; }
        !in_fm {
            if (/^```/) { in_code = !in_code; next; }
            if (!in_code && /^# /) { sub(/^# +/, ""); print; exit; }
        }
    ' "$file")"

    if [[ -z "$h1_title" ]]; then
        fail "Missing level-1 heading (# <Title>) after frontmatter" "$file"
        file_fails=$((file_fails + 1))
    elif [[ "$h1_title" != "$name" ]]; then
        fail "H1 title '$h1_title' does not match frontmatter name '$name'" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "H1 title matches frontmatter name verbatim ('$h1_title')"
    fi

    local invalid_depth
    invalid_depth="$(awk '
        /^```/ { in_code = !in_code; next; }
        !in_code && /^####/ { print NR; exit; }
    ' "$file")"
    if [[ -n "$invalid_depth" ]]; then
        fail "Prohibited heading depth (#### or deeper) on line $invalid_depth" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Heading depth constraints verified (level 1-3 only)"
    fi

    # 8. Section Sequence & Tokens (Excluding Code Blocks)
    local h2_headings
    h2_headings="$(awk '
        /^```/ { in_code = !in_code; next; }
        !in_code && /^## / { sub(/^## /, ""); print; }
    ' "$file" | tr '\n' ',' | sed 's/,$//')"

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

    # Internal Wikilink Integrity Check
    local broken_links=()
    while IFS= read -r link_target; do
        [[ -z "$link_target" ]] && continue
        local found=false
        if [[ -n "$BRAIN_DIR" && -d "$BRAIN_DIR" ]]; then
            for d in "${CANONICAL_DOMAINS[@]}"; do
                if [[ -f "$BRAIN_DIR/$d/$link_target.md" ]]; then
                    found=true
                    break
                fi
            done
        fi
        if [[ "$found" == false ]]; then
            broken_links+=("$link_target")
        fi
    done < <(awk '
        /^```/ { in_code = !in_code; next; }
        !in_code {
            line = $0;
            while (match(line, /\[\[[a-z0-9-]+(\|[^]]+)?\]\]/)) {
                link = substr(line, RSTART + 2, RLENGTH - 4);
                pipe_idx = index(link, "|");
                if (pipe_idx > 0) {
                    target = substr(link, 1, pipe_idx - 1);
                } else {
                    target = link;
                }
                print target;
                line = substr(line, RSTART + RLENGTH);
            }
        }
    ' "$file")

    if [[ ${#broken_links[@]} -gt 0 ]]; then
        fail "Broken internal wikilink(s): ${broken_links[*]}" "$file"
        file_fails=$((file_fails + 1))
    else
        pass "Internal wikilink integrity verified"
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
update_frontmatter_field() {
    local target_file="$1"
    local field_name="$2"
    local field_value="$3"

    local temp_file="$(mktemp)"
    awk -v fn="$field_name" -v fv="$field_value" '
    BEGIN { in_fm = 0; replaced = 0; }
    NR == 1 && /^---/ { in_fm = 1; print; next; }
    in_fm && /^---/ {
        if (!replaced) {
            print fn ": " fv;
        }
        in_fm = 0;
        print;
        next;
    }
    in_fm {
        if ($0 ~ ("^" fn ":")) {
            print fn ": " fv;
            replaced = 1;
            next;
        }
        if (!replaced) {
            if (fn == "status" && $0 ~ /^type:/) {
                print;
                print fn ": " fv;
                replaced = 1;
                next;
            }
            if (fn == "deprecated" && ($0 ~ /^status:/ || $0 ~ /^type:/)) {
                print;
                print fn ": " fv;
                replaced = 1;
                next;
            }
        }
    }
    { print }
    ' "$target_file" > "$temp_file"

    chmod --reference="$target_file" "$temp_file" 2>/dev/null || true
    mv "$temp_file" "$target_file"
}

promote_file() {
    local target="$1"
    if ! audit_file "$target"; then
        echo -e "\n${RED}Cannot promote: target artifact failed initial audit.${NC}" >&2
        return 1
    fi

    update_frontmatter_field "$target" "status" "active"

    if ! audit_file "$target"; then
        echo -e "\n${RED}Cannot promote: artifact failed audit after modification.${NC}" >&2
        return 1
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
        echo -e "\n${RED}Cannot modify: target artifact failed initial audit.${NC}" >&2
        return 1
    fi

    update_frontmatter_field "$target" "deprecated" "$state"

    if ! audit_file "$target"; then
        echo -e "\n${RED}Cannot modify: artifact failed audit after modification.${NC}" >&2
        return 1
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
