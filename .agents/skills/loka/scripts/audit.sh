#!/usr/bin/env bash
# ==============================================================================
# audit.sh — LOKA Guardian Knowledge Artifact (KA) Audit & Promotion Tool
# Implements schema.md v0.2.3 frontmatter contract & two-axis lifecycle model
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Colors & Output Formatting
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() {
    local msg="$1"
    echo -e "    [${GREEN}PASS${NC}] ${msg}"
    FILE_PASSES=$((FILE_PASSES + 1))
    TOTAL_PASSES=$((TOTAL_PASSES + 1))
}

fail() {
    local msg="$1"
    local detail="${2:-}"
    echo -e "    [${RED}FAIL${NC}] ${msg}"
    if [[ -n "$detail" ]]; then
        echo -e "           ${RED}↳ ${detail}${NC}"
    fi
    FILE_FAILS=$((FILE_FAILS + 1))
    TOTAL_FAILS=$((TOTAL_FAILS + 1))
}

warn() {
    local msg="$1"
    local detail="${2:-}"
    echo -e "    [${YELLOW}WARN${NC}] ${msg}"
    if [[ -n "$detail" ]]; then
        echo -e "           ${YELLOW}↳ ${detail}${NC}"
    fi
    FILE_WARNS=$((FILE_WARNS + 1))
    TOTAL_WARNS=$((TOTAL_WARNS + 1))
}

# Counters
TOTAL_FILES=0
TOTAL_PASSES=0
TOTAL_FAILS=0
TOTAL_WARNS=0

FILE_PASSES=0
FILE_FAILS=0
FILE_WARNS=0

# ------------------------------------------------------------------------------
# 2. Path Discovery
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Source shared frontmatter parser
LIB_PARSER="$SCRIPT_DIR/lib/parse_frontmatter.sh"
if [[ ! -f "$LIB_PARSER" ]]; then
    echo -e "${RED}ERROR: Shared frontmatter parser not found at $LIB_PARSER${NC}" >&2
    exit 1
fi
source "$LIB_PARSER"

# Resolve loka-brain directory (override, walk-up, or fallback)
BRAIN_DIR="${LOKA_BRAIN_ROOT:-}"
if [[ -z "$BRAIN_DIR" ]]; then
    check_dir="$SCRIPT_DIR"
    while [[ "$check_dir" != "/" ]]; do
        if [[ -d "$check_dir/loka-brain" ]]; then
            BRAIN_DIR="$check_dir/loka-brain"
            break
        elif [[ -d "$check_dir/LOKA-brain" ]]; then
            BRAIN_DIR="$check_dir/LOKA-brain"
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
    if [[ -z "$fixed_depth_dir" || ! -d "$fixed_depth_dir" ]]; then
        fixed_depth_dir="$(cd "$SCRIPT_DIR/../../../../LOKA-brain" 2>/dev/null && pwd || true)"
    fi
    if [[ -n "$fixed_depth_dir" && -d "$fixed_depth_dir" ]]; then
        BRAIN_DIR="$fixed_depth_dir"
    fi
fi

if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
    echo -e "${RED}ERROR: Could not resolve loka-brain directory.${NC}" >&2
    exit 1
fi

INDEX_SCRIPT="$SCRIPT_DIR/index.sh"
DOMAINS=("profiles" "behaviors" "standards" "workflows" "tools" "meta")

# ------------------------------------------------------------------------------
# 3. Audit Engine for a Single Knowledge Artifact
# ------------------------------------------------------------------------------
audit_file() {
    local file="$1"
    FILE_PASSES=0
    FILE_FAILS=0
    FILE_WARNS=0

    echo -e "\n  ${BOLD}Auditing:${NC} ${CYAN}${file}${NC}"

    if [[ ! -f "$file" ]]; then
        fail "File does not exist" "$file"
        return 1
    fi

    # Read metadata via shared parser
    local id="" name="" type="" status="" deprecated="" description="" created="" stale_after="" owner="" verified="" sources=""
    local fm_start=0 fm_end=0 expected_end=0 err="" err_delimiter="" err_order="" unknown_keys="" missing_fields=""
    local has_id=0 has_name=0 has_type=0 has_status=0 has_deprecated=0 has_description=0 has_created=0 has_stale_after=0 has_owner=0 has_verified=0 has_sources=0

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
            OWNER) owner="$v" ;;
            VERIFIED) verified="$v" ;;
            SOURCES) sources="$v" ;;
            FM_START) fm_start="$v" ;;
            FM_END) fm_end="$v" ;;
            EXPECTED_END) expected_end="$v" ;;
            ERR) err="$v" ;;
            ERR_DELIMITER) err_delimiter="$v" ;;
            ERR_ORDER) err_order="$v" ;;
            UNKNOWN_KEYS) unknown_keys="$v" ;;
            MISSING_FIELDS) missing_fields="$v" ;;
            HAS_ID) has_id="$v" ;;
            HAS_NAME) has_name="$v" ;;
            HAS_TYPE) has_type="$v" ;;
            HAS_STATUS) has_status="$v" ;;
            HAS_DEPRECATED) has_deprecated="$v" ;;
            HAS_DESCRIPTION) has_description="$v" ;;
            HAS_CREATED) has_created="$v" ;;
            HAS_STALE_AFTER) has_stale_after="$v" ;;
            HAS_OWNER) has_owner="$v" ;;
            HAS_VERIFIED) has_verified="$v" ;;
            HAS_SOURCES) has_sources="$v" ;;
        esac
    done < <(parse_frontmatter "$file")

    # --- Dimension 1: Frontmatter Integrity ---
    # Delimiter enforcement
    if [[ -n "$err_delimiter" ]]; then
        fail "YAML frontmatter delimiter error" "$err_delimiter"
    elif [[ $fm_start -eq 1 && $fm_end -eq ${expected_end} ]]; then
        pass "YAML frontmatter delimiters valid (line 1 to line ${fm_end})"
    else
        fail "YAML frontmatter delimiter error (closing delimiter must be line ${expected_end})"
    fi

    # Key ordering enforcement
    if [[ -n "$err_order" ]]; then
        fail "Canonical frontmatter key ordering violation" "$err_order"
    else
        pass "Frontmatter keys follow canonical ordering"
    fi

    # Mandatory field presence
    if [[ -n "$missing_fields" ]]; then
        fail "Missing mandatory frontmatter field(s)" "$missing_fields"
    else
        pass "All mandatory frontmatter fields present (id, name, type, description)"
    fi

    # Optional owner check
    if [[ "$has_owner" -eq 1 && -n "$owner" ]]; then
        pass "Optional custodian field 'owner' present ('$owner')"
    else
        pass "Optional custodian field 'owner' omitted (valid)"
    fi

    # Optional stale_after check
    if [[ "$has_stale_after" -eq 1 && -n "$stale_after" ]]; then
        if [[ "$stale_after" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            pass "Optional freshness field 'stale_after' present and valid ('$stale_after')"
        else
            fail "Freshness field 'stale_after' invalid. Must match YYYY-MM-DD"
        fi
    else
        pass "Optional freshness field 'stale_after' omitted (valid)"
    fi

    # Optional verified check
    if [[ "$has_verified" -eq 1 && -n "$verified" ]]; then
        case "$verified" in
            human|attested|automated)
                pass "Optional trustworthiness field 'verified' present and valid ('$verified')"
                ;;
            *)
                fail "Trustworthiness field 'verified' invalid ('$verified'). Must be one of: human, attested, automated"
                ;;
        esac
    else
        pass "Optional trustworthiness field 'verified' omitted (valid)"
    fi

    # Optional sources check
    if [[ "$has_sources" -eq 1 && -n "$sources" ]]; then
        if [[ "$sources" =~ ^\[.*\]$ ]]; then
            pass "Optional provenance field 'sources' present and valid ('$sources')"
        else
            fail "Provenance field 'sources' invalid. Must be an inline list [\"url\", ...]"
        fi
    else
        pass "Optional provenance field 'sources' omitted (valid)"
    fi

    # Schema purity enforcement (undeclared keys non-compliant)
    if [[ -n "$unknown_keys" ]]; then
        fail "Frontmatter schema purity violation (undeclared keys prohibited)" "$unknown_keys"
    else
        pass "Frontmatter schema purity verified (zero undeclared keys)"
    fi

    # Syntax & format checks
    if [[ "$has_id" -eq 1 && -n "$id" ]]; then
        if [[ "$id" =~ ^[a-z0-9-]+$ ]]; then
            pass "Identifier ('$id') is valid kebab-case"
        else
            fail "Identifier ('$id') must be lowercase kebab-case (^[a-z0-9-]+$)"
        fi
    fi

    if [[ "$has_type" -eq 1 && -n "$type" ]]; then
        case "$type" in
            profile|behavior|standard|workflow|tool|meta)
                pass "Type ('$type') is a valid canonical domain"
                ;;
            *)
                fail "Type ('$type') invalid. Must be one of: profile, behavior, standard, workflow, tool, meta"
                ;;
        esac
    fi

    if [[ "$has_status" -eq 1 && -n "$status" ]]; then
        case "$status" in
            draft|test|active)
                pass "Status ('$status') is valid (draft|test|active)"
                ;;
            *)
                fail "Status ('$status') invalid. Must be one of: draft, test, active"
                ;;
        esac
    fi

    if [[ "$has_deprecated" -eq 1 && -n "$deprecated" ]]; then
        case "$deprecated" in
            true|false)
                pass "Deprecated flag ('$deprecated') is valid boolean"
                ;;
            *)
                fail "Deprecated flag ('$deprecated') invalid. Must be boolean literal true or false"
                ;;
        esac
    fi

    if [[ "$has_description" -eq 1 && -n "$description" ]]; then
        pass "Description present for progressive disclosure ('$description')"
    fi

    if [[ "$has_created" -eq 1 && -n "$created" ]]; then
        if [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            pass "Created date ('$created') is valid ISO-8601 (YYYY-MM-DD)"
        else
            fail "Created date ('$created') invalid. Must match YYYY-MM-DD"
        fi
    fi

    # --- Dimension 2: Domain Taxonomy & Boundary ---
    local parent_dir filename basename_no_ext
    parent_dir="$(basename "$(dirname "$(readlink -f "$file")")")"
    filename="$(basename "$file")"
    basename_no_ext="${filename%.md}"

    # Filename kebab-case check
    if [[ "$filename" =~ ^[a-z0-9-]+\.md$ ]]; then
        pass "Filename ('$filename') is lowercase kebab-case"
    else
        fail "Filename ('$filename') must be lowercase kebab-case (.md)"
    fi

    # Identifier match (exact kebab-case match)
    if [[ -n "$id" && "$id" == "$basename_no_ext" ]]; then
        pass "Identifier ('$id') matches filename stem exactly ('$basename_no_ext')"
    else
        fail "Identifier mismatch: id '$id' does not match filename stem '$basename_no_ext'"
    fi

    # Domain directory matching type
    local expected_domain=""
    case "$type" in
        profile)  expected_domain="profiles" ;;
        behavior) expected_domain="behaviors" ;;
        standard) expected_domain="standards" ;;
        workflow) expected_domain="workflows" ;;
        tool)     expected_domain="tools" ;;
        meta)     expected_domain="meta" ;;
    esac

    if [[ -n "$expected_domain" ]]; then
        if [[ "$parent_dir" == "$expected_domain" ]]; then
            pass "Domain alignment valid (folder '$parent_dir' matches type '$type')"
        else
            fail "Domain mismatch: file is in '$parent_dir/', but type is '$type' (expected '$expected_domain/')"
        fi
    fi

    # --- Dimensions 3, 4, 5: Body Analysis ---
    local body_start="${fm_end:-10}"

    # --- Dimension 3: De-Identification & Neutrality ---
    # Scan note body (lines after frontmatter) for hardcoded host paths
    local host_paths
    host_paths=$(awk -v end="$body_start" 'NR > end && /(^|[^a-zA-Z0-9_/-])(\/home\/|\/mnt\/|\/tmp\/|\/root\/)/ { print NR ":" $0 }' "$file" || true)
    if [[ -z "$host_paths" ]]; then
        pass "De-identification verified (no hardcoded host paths like /home/, /mnt/, /tmp/)"
    else
        fail "Hardcoded host filesystem path detected in body" "$host_paths"
    fi

    # Scan for secret patterns in body
    local secret_matches
    secret_matches=$(awk -v end="$body_start" 'NR > end && /(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*["\047][a-zA-Z0-9_\-\.]{8,}["\047]/ { print NR ":" $0 }' "$file" || true)
    if [[ -z "$secret_matches" ]]; then
        pass "Credential scan clear (zero hardcoded secrets or tokens)"
    else
        fail "Potential hardcoded secret or token detected" "$secret_matches"
    fi

    # --- Dimension 4: LOKA Isolation & Runtime Independence ---
    local isolation_leakage
    isolation_leakage=$(awk -v end="$body_start" 'NR > end && /(BUDTENDER_KERNEL|BUDS_[A-Za-z0-9_]+|buds_[a-z0-9_]+)/ { print NR ":" $0 }' "$file" || true)
    if [[ -z "$isolation_leakage" ]]; then
        pass "LOKA runtime isolation verified (zero host or environment leaks)"
    else
        fail "Runtime isolation violation detected" "$isolation_leakage"
    fi

    # --- Dimension 5: Obsidian & Markdown Standards ---
    # First heading after frontmatter must be H1 matching name verbatim
    local h1_title
    h1_title=$(awk -v end="$body_start" 'NR > end && /^# / { sub(/^# [ \t]*/, ""); gsub(/\r/, ""); print; exit }' "$file" || true)
    if [[ -n "$h1_title" ]]; then
        if [[ "$h1_title" == "$name" ]]; then
            pass "H1 Title ('# $h1_title') matches frontmatter name verbatim"
        else
            fail "H1 Title mismatch: '# $h1_title' does not match frontmatter name ('$name') verbatim"
        fi
    else
        fail "Missing H1 document title ('# <Title>') after frontmatter"
    fi

    # Check for forbidden Obsidian tags (#tag) outside code fences
    local obsidian_tags
    obsidian_tags=$(awk -v end="$body_start" '
    BEGIN { in_code = 0 }
    NR > end {
        if ($0 ~ /^```/) { in_code = !in_code; next }
        if (!in_code && $0 !~ /^[#]+ / && $0 ~ /(^|[ \t])#[a-zA-Z][a-zA-Z0-9_-]*/) {
            print NR ":" $0
        }
    }' "$file" || true)

    if [[ -z "$obsidian_tags" ]]; then
        pass "Obsidian tag check passed (zero forbidden #tags found)"
    else
        fail "Obsidian #tag syntax detected (prohibited by vault contract)" "$obsidian_tags"
    fi

    # Check code fences have language tags
    local untagged_fences
    untagged_fences=$(awk -v end="$body_start" '
    BEGIN { in_code = 0 }
    NR > end {
        if ($0 ~ /^[ \t]*```+[ \t\r]*$/) {
            if (!in_code) {
                print NR ": opening code fence missing language identifier"
            }
            in_code = !in_code
        } else if ($0 ~ /^[ \t]*```+[a-zA-Z0-9_-]+/) {
            in_code = 1
        }
    }' "$file" || true)

    if [[ -z "$untagged_fences" ]]; then
        pass "Fenced code blocks specify language identifiers"
    else
        fail "Untagged code fence detected (language identifier required)" "$untagged_fences"
    fi

    # H2 section structure check (Context -> Mechanism -> [Implementation ->] Rules)
    local h2_headings=()
    while IFS= read -r heading_line; do
        [[ -n "$heading_line" ]] && h2_headings+=("$heading_line")
    done < <(awk -v end="$body_start" '
        BEGIN { in_code = 0 }
        NR > end {
            if ($0 ~ /^```/) { in_code = !in_code; next }
            if (!in_code && $0 ~ /^## /) {
                h = $0
                sub(/^##[ \t]+/, "", h)
                sub(/[ \t\r]+$/, "", h)
                print h
            }
        }' "$file" || true)

    local h2_joined
    h2_joined=$(IFS=','; echo "${h2_headings[*]}")

    if [[ "$h2_joined" == "Context,Mechanism,Rules" || "$h2_joined" == "Context,Mechanism,Implementation,Rules" ]]; then
        pass "H2 section structure verified (${h2_joined//,/ -> })"
    else
        local h2_detail=""
        if [[ ${#h2_headings[@]} -eq 0 ]]; then
            h2_detail="Zero H2 headings found in document body"
        else
            h2_detail="Found: [${h2_joined//,/, }] (expected: 'Context -> Mechanism -> Rules' or 'Context -> Mechanism -> Implementation -> Rules')"
        fi
        fail "H2 section structure violation (mandatory sections missing, duplicated, or out of order)" "$h2_detail"
    fi

    # Wikilink validity check
    local dead_links=()
    while IFS=':' read -r line_num link_target; do
        [[ -z "$link_target" ]] && continue
        local resolved=false
        for d in "${DOMAINS[@]}"; do
            if [[ -f "$BRAIN_DIR/$d/${link_target}.md" ]]; then
                resolved=true
                break
            fi
        done
        if [[ "$resolved" != true ]]; then
            dead_links+=("line ${line_num}: [[${link_target}]]")
        fi
    done < <(awk -v end="$body_start" '
        BEGIN { in_code = 0 }
        NR > end {
            if ($0 ~ /^```/) { in_code = !in_code; next }
            if (in_code) next
            line = $0
            gsub(/\r/, "", line)
            gsub(/`[^`]*`/, "", line)
            while (match(line, /\[\[([^\]]+)\]\]/)) {
                link = substr(line, RSTART + 2, RLENGTH - 4)
                line = substr(line, RSTART + RLENGTH)
                sub(/\|.*$/, "", link)
                sub(/#.*$/, "", link)
                sub(/\.md$/, "", link)
                sub(/^[ \t]+/, "", link)
                sub(/[ \t]+$/, "", link)
                if (length(link) > 0) {
                    print NR ":" link
                } else {
                    print NR ":(empty)"
                }
            }
        }' "$file" || true)

    if [[ ${#dead_links[@]} -eq 0 ]]; then
        pass "Wikilink integrity verified (all internal [[...]] links resolve to valid artifacts)"
    else
        fail "Dead wikilink(s) detected in body (target does not exist in domain folders)" "${dead_links[*]}"
    fi

    # Body-wide heading integrity check (single H1 document title, zero empty headings)
    local extra_h1_lines=()
    local empty_heading_lines=()
    while IFS=':' read -r violation_type line_num violation_content; do
        case "$violation_type" in
            EXTRA_H1)
                extra_h1_lines+=("line ${line_num}")
                ;;
            EMPTY)
                empty_heading_lines+=("line ${line_num}")
                ;;
        esac
    done < <(awk -v end="$body_start" '
        BEGIN {
            in_code = 0
            first_h1_seen = 0
        }
        NR > end {
            if ($0 ~ /^```/) { in_code = !in_code; next }
            if (in_code) next

            if ($0 ~ /^#{1,6}[ \t\r]*$/) {
                print "EMPTY:" NR ":" $0
                next
            }

            if ($0 ~ /^#[ \t]+/) {
                if (!first_h1_seen) {
                    first_h1_seen = 1
                } else {
                    print "EXTRA_H1:" NR ":" $0
                }
            }
        }' "$file" || true)

    local heading_errors=()
    if [[ ${#extra_h1_lines[@]} -gt 0 ]]; then
        heading_errors+=("Multiple H1 headings detected (${extra_h1_lines[*]})")
    fi
    if [[ ${#empty_heading_lines[@]} -gt 0 ]]; then
        heading_errors+=("Empty heading without text (${empty_heading_lines[*]})")
    fi

    if [[ ${#heading_errors[@]} -eq 0 ]]; then
        pass "Body heading integrity verified (single H1 title, zero empty headings)"
    else
        local heading_detail
        heading_detail=$(IFS='; '; echo "${heading_errors[*]}")
        fail "Heading integrity violation detected" "$heading_detail"
    fi

    # Trailing whitespace hygiene check (prevents git pre-flight failures)
    local trailing_ws_lines=()
    while IFS= read -r ws_match; do
        [[ -n "$ws_match" ]] && trailing_ws_lines+=("$ws_match")
    done < <(awk '/[ \t]+$/ { print "line " NR ": " $0 }' "$file" || true)

    if [[ ${#trailing_ws_lines[@]} -eq 0 ]]; then
        pass "Whitespace hygiene verified (zero trailing whitespace across entire file)"
    else
        local ws_detail
        ws_detail=$(IFS='; '; echo "${trailing_ws_lines[*]}")
        fail "Trailing whitespace detected (violates git pre-flight check)" "$ws_detail"
    fi

    # Summary
    if [[ $FILE_FAILS -eq 0 ]]; then
        echo -e "    ${BOLD}${GREEN}Result: APPROVED${NC} (${FILE_PASSES} passed, ${FILE_WARNS} warnings)"
        return 0
    else
        echo -e "    ${BOLD}${RED}Result: REVISE${NC} (${FILE_FAILS} failed, ${FILE_PASSES} passed, ${FILE_WARNS} warnings)"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# 4. Target Validation & Promotion Safety
# ------------------------------------------------------------------------------
validate_target() {
    local target="$1"

    if [[ ! -f "$target" ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Target does not exist:${NC} $target" >&2
        return 1
    fi

    local real_target real_brain
    real_target="$(readlink -f "$target" 2>/dev/null || true)"
    real_brain="$(readlink -f "$BRAIN_DIR" 2>/dev/null || true)"

    if [[ -z "$real_target" || ! -f "$real_target" ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Cannot resolve realpath for target:${NC} $target" >&2
        return 1
    fi

    if [[ -z "$real_brain" || ! -d "$real_brain" ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Cannot resolve LOKA-brain directory:${NC} $BRAIN_DIR" >&2
        return 1
    fi

    local target_dir target_parent target_domain filename
    target_dir="$(dirname "$real_target")"
    target_parent="$(dirname "$target_dir")"
    target_domain="$(basename "$target_dir")"
    filename="$(basename "$real_target")"

    # Must be located strictly 1 level deep inside $BRAIN_DIR
    if [[ "$target_parent" != "$real_brain" ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Target file '$target' must be located strictly inside '$BRAIN_DIR/<domain>/'.${NC}" >&2
        return 1
    fi

    # Domain directory must be canonical
    local valid_domain=false
    for d in "${DOMAINS[@]}"; do
        if [[ "$target_domain" == "$d" ]]; then
            valid_domain=true
            break
        fi
    done

    if [[ "$valid_domain" != true ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Parent directory '$target_domain' is not a canonical domain (expected: ${DOMAINS[*]}).${NC}" >&2
        return 1
    fi

    if [[ ! "$filename" =~ ^[a-z0-9-]+\.md$ ]]; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Filename '$filename' must be lowercase kebab-case ending in .md.${NC}" >&2
        return 1
    fi

    return 0
}

promote_file() {
    local target_file="$1"

    echo -e "\n${BOLD}${CYAN}=== Promoting Knowledge Artifact ===${NC}"
    echo -e "Target: ${target_file}"

    if ! validate_target "$target_file"; then
        return 1
    fi

    # Read current frontmatter
    local current_status="" current_deprecated=""
    while IFS='=' read -r k v; do
        case "$k" in
            STATUS) current_status="$v" ;;
            DEPRECATED) current_deprecated="$v" ;;
        esac
    done < <(parse_frontmatter "$target_file")

    # Linear lifecycle transition matrix:
    # draft -> test
    # test -> active
    local next_status=""
    case "$current_status" in
        draft)
            next_status="test"
            ;;
        test)
            next_status="active"
            ;;
        active)
            echo -e "\n${YELLOW}Artifact is already active.${NC} No status change needed."
            return 0
            ;;
        *)
            echo -e "\n${BOLD}${RED}[BLOCKED] Promotion denied:${NC} Artifact has invalid or unpromotable status '${current_status}'." >&2
            echo -e "Allowed linear lifecycle transitions: draft → test, test → active.\n" >&2
            return 1
            ;;
    esac

    echo -e "Lifecycle Transition: ${CYAN}${current_status}${NC} ──> ${GREEN}${next_status}${NC}"
    if [[ -n "$current_deprecated" ]]; then
        echo -e "Deprecation Flag:     ${YELLOW}deprecated: ${current_deprecated}${NC} (preserved, orthogonal)"
    fi

    # Audit candidate artifact against all dimensions
    if ! audit_file "$target_file"; then
        echo -e "\n${BOLD}${RED}[BLOCKED] Promotion denied:${NC} Artifact failed audit checks. Resolve all failures first.\n" >&2
        return 1
    fi

    # Backup file before mutating
    local backup_file
    backup_file="$(mktemp "${TMPDIR:-/tmp}/ka_promote_backup.XXXXXX")"
    cp "$target_file" "$backup_file"

    # Mutate status in frontmatter (leaving deprecated untouched)
    local temp_file
    temp_file="$(mktemp "${TMPDIR:-/tmp}/ka_promote.XXXXXX")"
    awk -v next_st="$next_status" '
    BEGIN { in_fm = 0; fm_count = 0 }
    /^---[ \t\r]*$/ {
        fm_count++
        if (fm_count == 1) { in_fm = 1; print; next }
        if (fm_count == 2) { in_fm = 0; print; next }
    }
    in_fm && /^[ \t]*status:[ \t]*/ {
        print "status: " next_st
        next
    }
    { print }
    ' "$target_file" > "$temp_file"

    mv "$temp_file" "$target_file"
    echo -e "\n${BOLD}${GREEN}[SUCCESS] Status updated:${NC} ${current_status} → ${next_status} (${target_file})"

    # Refresh master index if index.sh exists
    if [[ -x "$INDEX_SCRIPT" ]]; then
        echo -e "Refreshing master catalog at ${CYAN}${BRAIN_DIR}/index.md${NC}..."
        if ! "$INDEX_SCRIPT" "$BRAIN_DIR"; then
            echo -e "${BOLD}${RED}[ERROR] Master index generation failed via ${INDEX_SCRIPT}. Rolling back promotion.${NC}" >&2
            mv "$backup_file" "$target_file"
            return 1
        fi
        echo -e "${GREEN}Index synchronized successfully.${NC}"
    else
        echo -e "${YELLOW}Warning: Index script not found or not executable at ${INDEX_SCRIPT}.${NC}" >&2
    fi

    rm -f "$backup_file"
    return 0
}

set_deprecation_flag() {
    local target_file="$1"
    local new_dep_val="$2" # "true" or "false"

    echo -e "\n${BOLD}${CYAN}=== Updating Deprecation Flag ===${NC}"
    echo -e "Target:    ${target_file}"
    echo -e "Setting:   deprecated: ${new_dep_val}"

    if ! validate_target "$target_file"; then
        return 1
    fi

    local current_dep=""
    while IFS='=' read -r k v; do
        case "$k" in
            DEPRECATED) current_dep="$v" ;;
        esac
    done < <(parse_frontmatter "$target_file")

    if [[ "$current_dep" == "$new_dep_val" ]]; then
        echo -e "\n${YELLOW}Artifact already has deprecated: ${new_dep_val}.${NC} No change needed."
        return 0
    fi

    local backup_file
    backup_file="$(mktemp "${TMPDIR:-/tmp}/ka_dep_backup.XXXXXX")"
    cp "$target_file" "$backup_file"

    local temp_file
    temp_file="$(mktemp "${TMPDIR:-/tmp}/ka_dep.XXXXXX")"
    awk -v new_val="$new_dep_val" '
    BEGIN { in_fm = 0; fm_count = 0; found = 0 }
    /^---[ \t\r]*$/ {
        fm_count++
        if (fm_count == 1) { in_fm = 1; print; next }
        if (fm_count == 2) {
            if (!found) {
                print "deprecated: " new_val
            }
            in_fm = 0; print; next
        }
    }
    in_fm && /^[ \t]*deprecated:[ \t]*/ {
        print "deprecated: " new_val
        found = 1
        next
    }
    { print }
    ' "$target_file" > "$temp_file"

    mv "$temp_file" "$target_file"
    echo -e "\n${BOLD}${GREEN}[SUCCESS] Deprecation flag updated:${NC} deprecated: ${new_dep_val} (${target_file})"

    if [[ -x "$INDEX_SCRIPT" ]]; then
        echo -e "Refreshing master catalog at ${CYAN}${BRAIN_DIR}/index.md${NC}..."
        if ! "$INDEX_SCRIPT" "$BRAIN_DIR"; then
            echo -e "${BOLD}${RED}[ERROR] Master index generation failed via ${INDEX_SCRIPT}. Rolling back change.${NC}" >&2
            mv "$backup_file" "$target_file"
            return 1
        fi
        echo -e "${GREEN}Index synchronized successfully.${NC}"
    fi

    rm -f "$backup_file"
    return 0
}

# ------------------------------------------------------------------------------
# 5. CLI Execution Dispatcher
# ------------------------------------------------------------------------------
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [options] [file]"
    echo ""
    echo "Options:"
    echo "  --all                 Audit all knowledge artifacts across all 6 domains (default)"
    echo "  --promote <file>      Audit and advance candidate artifact along linear lifecycle (draft → test, test → active)"
    echo "  --promote-all         Audit all artifacts and advance eligible artifacts (draft → test, test → active)"
    echo "  --deprecate <file>    Set deprecated: true (orthogonal to lifecycle status)"
    echo "  --undeprecate <file>  Set deprecated: false (orthogonal to lifecycle status)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ./LOKA-brain/profiles/copilot-operational-profile.md"
    echo "  $0 --all"
    echo "  $0 --promote ./LOKA-brain/workflows/dynamic-execution-workflow.md"
    echo "  $0 --deprecate ./LOKA-brain/tools/legacy-tool-policy.md"
    exit 0
}

AUDIT_ALL=false
PROMOTE_MODE=false
PROMOTE_ALL=false
DEPRECATE_MODE=false
UNDEPRECATE_MODE=false
TARGET_FILES=()

if [[ $# -eq 0 ]]; then
    AUDIT_ALL=true
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                AUDIT_ALL=true
                shift
                ;;
            --promote)
                PROMOTE_MODE=true
                shift
                if [[ $# -eq 0 ]]; then
                    echo -e "${RED}Error: --promote requires a target file path.${NC}" >&2
                    exit 1
                fi
                TARGET_FILES+=("$1")
                shift
                ;;
            --promote-all)
                PROMOTE_ALL=true
                shift
                ;;
            --deprecate)
                DEPRECATE_MODE=true
                shift
                if [[ $# -eq 0 ]]; then
                    echo -e "${RED}Error: --deprecate requires a target file path.${NC}" >&2
                    exit 1
                fi
                TARGET_FILES+=("$1")
                shift
                ;;
            --undeprecate)
                UNDEPRECATE_MODE=true
                shift
                if [[ $# -eq 0 ]]; then
                    echo -e "${RED}Error: --undeprecate requires a target file path.${NC}" >&2
                    exit 1
                fi
                TARGET_FILES+=("$1")
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                TARGET_FILES+=("$1")
                shift
                ;;
        esac
    done
fi

if [[ "$AUDIT_ALL" == true || "$PROMOTE_ALL" == true ]]; then
    TARGET_FILES=()
    for domain in "${DOMAINS[@]}"; do
        domain_dir="$BRAIN_DIR/$domain"
        [[ ! -d "$domain_dir" ]] && continue
        while IFS= read -r f; do
            [[ -n "$f" ]] && TARGET_FILES+=("$f")
        done < <(find "$domain_dir" -maxdepth 1 -type f -name "*.md" ! -iname "index.md" ! -iname "AGENTS.md" ! -iname "README.md" | sort)
    done
fi

if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No knowledge artifacts found to audit.${NC}"
    echo -e "\n${BOLD}${CYAN}=== Audit Summary (v0.2.3 Contract) ===${NC}"
    echo -e "Total Artifacts: 0"
    echo -e "Total Checks:    0"
    echo -e "Passed:          0"
    echo -e "Warnings:        0"
    echo -e "Failures:        0"
    echo -e "\n${BOLD}${GREEN}Result: ALL ARTIFACTS APPROVED! (Empty vault)${NC}\n"
    exit 0
fi

# Execution loop
echo -e "${BOLD}${CYAN}=== LOKA Knowledge Artifact Audit (v0.2.3 Contract) ===${NC}"
echo -e "Vault Root: ${BRAIN_DIR}"
echo -e "Artifacts:  ${#TARGET_FILES[@]}"

EXIT_CODE=0

if [[ "$PROMOTE_MODE" == true ]]; then
    for target in "${TARGET_FILES[@]}"; do
        if ! promote_file "$target"; then
            EXIT_CODE=1
        fi
    done
elif [[ "$PROMOTE_ALL" == true ]]; then
    promoted_count=0
    blocked_count=0
    for target in "${TARGET_FILES[@]}"; do
        if promote_file "$target"; then
            promoted_count=$((promoted_count + 1))
        else
            blocked_count=$((blocked_count + 1))
            EXIT_CODE=1
        fi
    done
    echo -e "\n${BOLD}Promotion Summary:${NC} ${GREEN}${promoted_count} promoted/verified${NC}, ${RED}${blocked_count} blocked${NC}"
elif [[ "$DEPRECATE_MODE" == true ]]; then
    for target in "${TARGET_FILES[@]}"; do
        if ! set_deprecation_flag "$target" "true"; then
            EXIT_CODE=1
        fi
    done
elif [[ "$UNDEPRECATE_MODE" == true ]]; then
    for target in "${TARGET_FILES[@]}"; do
        if ! set_deprecation_flag "$target" "false"; then
            EXIT_CODE=1
        fi
    done
else
    for target in "${TARGET_FILES[@]}"; do
        TOTAL_FILES=$((TOTAL_FILES + 1))
        if ! audit_file "$target"; then
            EXIT_CODE=1
        fi
    done

    echo -e "\n${BOLD}${CYAN}=== Audit Summary (v0.2.3 Contract) ===${NC}"
    echo -e "Total Artifacts: ${TOTAL_FILES}"
    echo -e "Total Checks:    $((TOTAL_PASSES + TOTAL_FAILS + TOTAL_WARNS))"
    echo -e "Passed:          ${GREEN}${TOTAL_PASSES}${NC}"
    echo -e "Warnings:        ${YELLOW}${TOTAL_WARNS}${NC}"
    echo -e "Failures:        ${RED}${TOTAL_FAILS}${NC}"

    if [[ $TOTAL_FAILS -gt 0 ]]; then
        echo -e "\n${BOLD}${RED}Result: AUDIT FAILED (${TOTAL_FAILS} failures across artifacts)${NC}\n"
    else
        echo -e "\n${BOLD}${GREEN}Result: ALL ARTIFACTS APPROVED!${NC}\n"
    fi
fi

exit $EXIT_CODE
