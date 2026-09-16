#!/usr/bin/env bash
# ==============================================================================
# index.sh — Auto-Updating Index Generator for loka-brain Knowledge Artifacts
# Implements schema.md v0.2.3 frontmatter contract with progressive disclosure
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Path Resolution
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Source shared frontmatter parser
LIB_PARSER="$SCRIPT_DIR/lib/parse_frontmatter.sh"
if [[ ! -f "$LIB_PARSER" ]]; then
    echo "ERROR: Shared frontmatter parser not found at $LIB_PARSER" >&2
    exit 1
fi
source "$LIB_PARSER"

# Optional override: first positional arg, else $LOKA_BRAIN_ROOT env var
BRAIN_DIR="${1:-${LOKA_BRAIN_ROOT:-}}"

# If no override, walk up from script directory looking for 'loka-brain'
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

# Fallback: relative depth scripts -> loka -> skills -> .agents -> root
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
    echo "ERROR: Could not resolve loka-brain directory." >&2
    exit 1
fi

INDEX_FILE="$BRAIN_DIR/index.md"
DOMAINS=("profiles" "behaviors" "standards" "workflows" "tools" "meta")

# ------------------------------------------------------------------------------
# 2. Parsing & Validation
# ------------------------------------------------------------------------------
TEMP_TABLES="$(mktemp "${TMPDIR:-/tmp}/loka_tables.XXXXXX")"
trap 'rm -f "$TEMP_TABLES"' EXIT

has_any_table=false
has_error=false

for domain in "${DOMAINS[@]}"; do
    domain_dir="$BRAIN_DIR/$domain"
    [[ ! -d "$domain_dir" ]] && continue

    domain_entries=()

    # Find all *.md files under loka-brain/<domain>/ (1 level deep)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        err=""
        id=""
        name=""
        type=""
        status=""
        deprecated=""
        description=""
        created=""
        owner=""

        while IFS='=' read -r k v; do
            case "$k" in
                ERR) err="$v" ;;
                ID) id="$v" ;;
                NAME) name="$v" ;;
                TYPE) type="$v" ;;
                STATUS) status="$v" ;;
                DEPRECATED) deprecated="$v" ;;
                DESCRIPTION) description="$v" ;;
                CREATED) created="$v" ;;
                OWNER) owner="$v" ;;
            esac
        done < <(parse_frontmatter "$file")

        if [[ -n "$err" ]]; then
            echo "ERROR in '$file': $err" >&2
            has_error=true
            continue
        fi

        # Validate domain folder matches type
        expected_domain=""
        case "$type" in
            profile)  expected_domain="profiles" ;;
            behavior) expected_domain="behaviors" ;;
            standard) expected_domain="standards" ;;
            workflow) expected_domain="workflows" ;;
            tool)     expected_domain="tools" ;;
            meta)     expected_domain="meta" ;;
            *)
                echo "ERROR: Artifact '$file' type ('$type') is not a canonical domain" >&2
                has_error=true
                continue
                ;;
        esac

        if [[ "$domain" != "$expected_domain" ]]; then
            echo "ERROR: Artifact '$file' type '$type' does not match domain folder '$domain' (expected '$expected_domain')" >&2
            has_error=true
            continue
        fi

        # Validate id matches filename stem (exact kebab-case)
        filename="$(basename "$file")"
        basename_no_ext="${filename%.md}"
        if [[ "$id" != "$basename_no_ext" ]]; then
            echo "ERROR: Artifact '$file' id '$id' does not match filename stem '$basename_no_ext'" >&2
            has_error=true
            continue
        fi

        # Wikilink: if basename matches name, [[name]]; otherwise [[basename|name]]
        if [[ "$basename_no_ext" == "$name" ]]; then
            wikilink="[[${name}]]"
        else
            wikilink="[[${basename_no_ext}|${name}]]"
        fi

        # Defaults for optional fields
        display_status="${status:-draft}"
        display_deprecated="${deprecated:-false}"
        display_created="${created:-undated}"

        # Format entry:
        # - [[id|name]] (`type` | `status` | deprecated: `bool` | `created`) — description
        entry_line="- ${wikilink} (\`${type}\` | \`${display_status}\` | deprecated: \`${display_deprecated}\` | \`${display_created}\`) — ${description}"

        # Store for sorting: created (descending), id (ascending)
        domain_entries+=("${created:-0000-00-00}"$'\t'"${id}"$'\t'"${entry_line}")
    done < <(find "$domain_dir" -maxdepth 1 -type f -name "*.md" ! -iname "index.md" ! -iname "AGENTS.md" ! -iname "README.md" | sort)

    # If domain has at least one valid artifact, format section
    if [[ ${#domain_entries[@]} -gt 0 ]]; then
        case "$domain" in
            profiles)  domain_title="Profiles" ;;
            behaviors) domain_title="Behaviors" ;;
            standards) domain_title="Standards" ;;
            workflows) domain_title="Workflows" ;;
            tools)     domain_title="Tools" ;;
            meta)      domain_title="Meta" ;;
            *)         domain_title="$(tr '[:lower:]' '[:upper:]' <<< "${domain:0:1}")${domain:1}" ;;
        esac

        echo "" >> "$TEMP_TABLES"
        echo "## ${domain_title}" >> "$TEMP_TABLES"
        echo "" >> "$TEMP_TABLES"

        # Sort rows: created descending (-k1,1r), tie-break by id ascending (-k2,2)
        printf "%s\n" "${domain_entries[@]}" | sort -t$'\t' -k1,1r -k2,2 | cut -f3- >> "$TEMP_TABLES"

        has_any_table=true
    fi
done

# If any validation errors occurred across artifacts, abort before touching index.md
if [[ "$has_error" == true ]]; then
    echo "ERROR: Master catalog generation aborted due to artifact validation error(s)." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Output Generation & Overwrite Protection
# ------------------------------------------------------------------------------
START_MARKER="<!-- AUTO-INDEX:START -->"
END_MARKER="<!-- AUTO-INDEX:END -->"

# If index.md does not exist, initialize with default template including markers
if [[ ! -f "$INDEX_FILE" ]]; then
    cat << 'EOF' > "$INDEX_FILE"
# LOKA Index

Master directory of Knowledge Artifacts (KA) in loka-brain. Consult this index at the start of non-trivial tasks to discover and retrieve verified operational knowledge across domains.

## How to Use This Index

1. **Analyze Task Scope:** Identify the operational requirements of the request (e.g. persona specification, behavioral boundary, output schema, workflow, tool policy, or meta governance).
2. **Discover Modules:** Check the domain sections below to locate applicable knowledge artifacts.
3. **Targeted Retrieval:** Load only the minimal set of 1–3 essential modules required for the active scope using relative paths (`./<domain>/<file>.md`).
4. **Execute & Verify:** Apply acquired standards and validate the resulting output against required quality gates.

<!-- AUTO-INDEX:START -->
<!-- AUTO-INDEX:END -->
EOF
else
    # File exists: verify presence and order of both markers to prevent accidental overwrite
    has_start=false
    has_end=false
    if grep -qF "$START_MARKER" "$INDEX_FILE"; then
        has_start=true
    fi
    if grep -qF "$END_MARKER" "$INDEX_FILE"; then
        has_end=true
    fi

    if [[ "$has_start" != true || "$has_end" != true ]]; then
        echo "ERROR: '$INDEX_FILE' exists but is missing required index marker(s):" >&2
        [[ "$has_start" != true ]] && echo "  - Missing start marker: $START_MARKER" >&2
        [[ "$has_end" != true ]] && echo "  - Missing end marker: $END_MARKER" >&2
        echo "Refusing to overwrite existing index file. Please insert markers manually into '$INDEX_FILE' or remove the file to reinitialize." >&2
        exit 1
    fi

    start_line="$(grep -nF "$START_MARKER" "$INDEX_FILE" | head -n 1 | cut -d: -f1)"
    end_line="$(grep -nF "$END_MARKER" "$INDEX_FILE" | head -n 1 | cut -d: -f1)"
    if (( start_line >= end_line )); then
        echo "ERROR: Markers in '$INDEX_FILE' are inverted or malformed (start marker on line $start_line, end marker on line $end_line)." >&2
        exit 1
    fi
fi

TEMP_INDEX="$(mktemp "${TMPDIR:-/tmp}/loka_index.XXXXXX")"

# Replace content strictly between markers, preserving all exterior content exactly as-is
awk -v tables_file="$TEMP_TABLES" -v has_tables="$has_any_table" '
BEGIN {
    in_block = 0
}
/<!-- AUTO-INDEX:START -->/ {
    print $0
    in_block = 1
    if (has_tables == "true") {
        while ((getline line < tables_file) > 0) {
            print line
        }
        close(tables_file)
        print ""
    }
    next
}
/<!-- AUTO-INDEX:END -->/ {
    in_block = 0
    print $0
    next
}
!in_block {
    print $0
}
' "$INDEX_FILE" > "$TEMP_INDEX"

mv "$TEMP_INDEX" "$INDEX_FILE"
