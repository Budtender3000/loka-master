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

# Vault-wide concurrency lock
LOCK_FILE="$BRAIN_DIR/.loka.lock"
if [[ -z "${LOKA_LOCK_HELD:-}" ]]; then
    exec 200>"$LOCK_FILE"
    flock -x 200
    export LOKA_LOCK_HELD=1
fi

INDEX_FILE="$BRAIN_DIR/index.md"
DOMAINS=("${CANONICAL_DOMAINS[@]}")

START_MARKER="<!-- AUTO-INDEX:START -->"
END_MARKER="<!-- AUTO-INDEX:END -->"

sanitize_index_val() {
    local val="$1"
    val="${val//$'\n'/ }"
    val="${val//$'\r'/ }"
    val="${val//$'\t'/ }"
    val="${val//<!--/}"
    val="${val//-->/}"
    val="${val//\[\[/\\[\\[}"
    val="${val//\]\]/\\]\\]}"
    val="${val//|/\\|}"
    printf '%s' "$val"
}

# ------------------------------------------------------------------------------
# 2. Parsing & Validation
# ------------------------------------------------------------------------------
TEMP_TABLES="$(mktemp "${BRAIN_DIR}/.tables.tmp.XXXXXX")"
TEMP_INDEX=""
cleanup() {
    rm -f "$TEMP_TABLES"
    if [[ -n "${TEMP_INDEX:-}" && -f "$TEMP_INDEX" ]]; then
        rm -f "$TEMP_INDEX"
    fi
}
trap cleanup EXIT

has_any_table=false
has_error=false

# Check for non-canonical markdown files under vault root
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#$BRAIN_DIR/}"
    if [[ "$f" == "$BRAIN_DIR/"* && "$rel" != *"/"* ]]; then
        case "$rel" in
            index.md|schema.md|README.md|AGENTS.md) ;;
            *)
                echo "ERROR: Non-canonical markdown file in vault root: '$rel'" >&2
                has_error=true
                ;;
        esac
    else
        domain="${rel%%/*}"
        rest="${rel#*/}"
        case "$domain" in
            profiles|behaviors|standards|workflows|tools|meta)
                if [[ "$rest" == *"/"* ]]; then
                    echo "ERROR: Forbidden nested subdirectory under domain '$domain': '$rel'" >&2
                    has_error=true
                fi
                ;;
            *)
                echo "ERROR: Markdown file in non-canonical domain '$domain': '$rel'" >&2
                has_error=true
                ;;
        esac
    fi
done < <(find "$BRAIN_DIR" -type f -name "*.md" | sort)

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
            esac
        done < <(parse_frontmatter "$file")

        if [[ -n "$err" ]]; then
            echo "ERROR in '$file': $err" >&2
            has_error=true
            continue
        fi

        # Hard-fail if any frontmatter value contains an index marker string
        for test_val in "$name" "$type" "$status" "$deprecated" "$description" "$created" "$id"; do
            if [[ "$test_val" == *"$START_MARKER"* || "$test_val" == *"$END_MARKER"* ]]; then
                echo "ERROR: Artifact '$file' contains index marker string in frontmatter value: '$test_val'" >&2
                exit 5
            fi
        done

        # Validate domain folder matches type
        expected_domain="$(type_to_domain "$type")"
        if [[ -z "$expected_domain" ]]; then
            echo "ERROR: Artifact '$file' type ('$type') is not a canonical domain" >&2
            has_error=true
            continue
        fi

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

        # Sanitize interpolated values
        sanitized_name="$(sanitize_index_val "$name")"
        if [[ "$basename_no_ext" == "$sanitized_name" ]]; then
            wikilink="[[${sanitized_name}]]"
        else
            wikilink="[[${basename_no_ext}|${sanitized_name}]]"
        fi

        # Defaults for optional fields
        display_status="$(sanitize_index_val "${status:-draft}")"
        display_deprecated="$(sanitize_index_val "${deprecated:-false}")"
        display_created="$(sanitize_index_val "${created:-undated}")"
        sanitized_type="$(sanitize_index_val "$type")"
        sanitized_desc="$(sanitize_index_val "$description")"

        # Format entry:
        # - [[id|name]] (`type` | `status` | deprecated: `bool` | `created`) — description
        entry_line="- ${wikilink} (\`${sanitized_type}\` | \`${display_status}\` | deprecated: \`${display_deprecated}\` | \`${display_created}\`) — ${sanitized_desc}"

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
    start_count="$(grep -cF "$START_MARKER" "$INDEX_FILE" || true)"
    end_count="$(grep -cF "$END_MARKER" "$INDEX_FILE" || true)"

    if [[ "$start_count" -ne 1 || "$end_count" -ne 1 ]]; then
        echo "ERROR: '$INDEX_FILE' must contain exactly one START marker and one END marker (found $start_count START, $end_count END)." >&2
        exit 1
    fi

    start_line="$(grep -nF "$START_MARKER" "$INDEX_FILE" | head -n 1 | cut -d: -f1)"
    end_line="$(grep -nF "$END_MARKER" "$INDEX_FILE" | head -n 1 | cut -d: -f1)"
    if (( start_line >= end_line )); then
        echo "ERROR: Markers in '$INDEX_FILE' are inverted or malformed (start marker on line $start_line, end marker on line $end_line)." >&2
        exit 1
    fi
fi

TEMP_INDEX="$(mktemp "${BRAIN_DIR}/.index.tmp.XXXXXX")"
chmod --reference="$INDEX_FILE" "$TEMP_INDEX" 2>/dev/null || true

# Replace content strictly between markers, preserving all exterior content exactly as-is
awk -v tables_file="$TEMP_TABLES" -v has_tables="$has_any_table" '
BEGIN {
    in_block = 0
    replaced = 0
}
/<!-- AUTO-INDEX:START -->/ {
    if (!replaced) {
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
}
/<!-- AUTO-INDEX:END -->/ {
    if (in_block) {
        in_block = 0
        replaced = 1
        print $0
        next
    }
}
!in_block {
    print $0
}
' "$INDEX_FILE" > "$TEMP_INDEX"

mv -T "$TEMP_INDEX" "$INDEX_FILE"
