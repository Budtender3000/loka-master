#!/usr/bin/env bash
# ==============================================================================
# index.sh — Auto-Updating Index Generator for loka-brain Knowledge Artifacts
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LIB_PARSER="$SCRIPT_DIR/lib/parse_frontmatter.sh"

if [[ ! -f "$LIB_PARSER" ]]; then
    echo "ERROR: Shared frontmatter parser not found at $LIB_PARSER" >&2
    exit 1
fi
source "$LIB_PARSER"

# 1. Resolve Brain Directory
BRAIN_DIR="${1:-${LOKA_BRAIN_ROOT:-}}"
if [[ -z "$BRAIN_DIR" ]]; then
    for candidate in "$SCRIPT_DIR/../../../loka-brain" "$SCRIPT_DIR/../../loka-brain" "./.agents/loka-brain" "./loka-brain"; do
        if [[ -d "$candidate" ]]; then
            BRAIN_DIR="$(readlink -f "$candidate")"
            break
        fi
    done
fi

if [[ -z "$BRAIN_DIR" || ! -d "$BRAIN_DIR" ]]; then
    echo "ERROR: Could not resolve loka-brain directory." >&2
    exit 1
fi

INDEX_FILE="$BRAIN_DIR/index.md"
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "ERROR: Index file not found at $INDEX_FILE" >&2
    exit 1
fi

START_MARKER="<!-- AUTO-INDEX:START -->"
END_MARKER="<!-- AUTO-INDEX:END -->"

if ! grep -q "$START_MARKER" "$INDEX_FILE" || ! grep -q "$END_MARKER" "$INDEX_FILE"; then
    echo "ERROR: Index markers not found in $INDEX_FILE" >&2
    exit 1
fi

# 2. Build Index Content
TEMP_BLOCK="$(mktemp)"
cleanup() { rm -f "$TEMP_BLOCK"; }
trap cleanup EXIT

domain_title() {
    case "$1" in
        profiles)  echo "Profiles" ;;
        behaviors) echo "Behaviors" ;;
        standards) echo "Standards" ;;
        workflows) echo "Workflows" ;;
        tools)     echo "Tools" ;;
        meta)      echo "Meta" ;;
        *)         echo "$1" ;;
    esac
}

first_section=true
for domain in "${CANONICAL_DOMAINS[@]}"; do
    domain_dir="$BRAIN_DIR/$domain"
    [[ ! -d "$domain_dir" ]] && continue

    # Collect *.md files
    files=()
    while IFS= read -r -d '' f; do
        fname="$(basename "$f")"
        if [[ "$fname" != "index.md" && "$fname" != "schema.md" && "$fname" != .* ]]; then
            files+=("$f")
        fi
    done < <(find "$domain_dir" -maxdepth 1 -name "*.md" -type f -print0 | sort -z)

    [[ ${#files[@]} -eq 0 ]] && continue

    if [[ "$first_section" == false ]]; then
        echo "" >> "$TEMP_BLOCK"
    fi
    first_section=false

    echo "## $(domain_title "$domain")" >> "$TEMP_BLOCK"
    echo "" >> "$TEMP_BLOCK"

    for file in "${files[@]}"; do
        id="" name="" type="" status="" deprecated="" description="" created=""
        while IFS='=' read -r k v; do
            case "$k" in
                ID) id="$v" ;;
                NAME) name="$v" ;;
                TYPE) type="$v" ;;
                STATUS) status="$v" ;;
                DEPRECATED) deprecated="$v" ;;
                DESCRIPTION) description="$v" ;;
                CREATED) created="$v" ;;
            esac
        done < <(parse_frontmatter "$file")

        id="${id:-$(basename "$file" .md)}"
        name="${name:-$id}"
        type="${type:-$(domain_to_type "$domain")}"
        status="${status:-draft}"
        deprecated="${deprecated:-false}"
        created="${created:-undated}"
        description="${description:-No description provided.}"

        echo "- [[$id|$name]] (\`$type\` | \`$status\` | deprecated: \`$deprecated\` | \`$created\`) — $description" >> "$TEMP_BLOCK"
    done
done

# 3. Update index.md between markers
TEMP_OUT="$(mktemp)"
awk -v start="$START_MARKER" -v end="$END_MARKER" -v block_file="$TEMP_BLOCK" '
BEGIN { in_auto = 0 }
$0 ~ start {
    print $0;
    print "";
    while ((getline line < block_file) > 0) {
        print line;
    }
    close(block_file);
    print "";
    in_auto = 1;
    next;
}
$0 ~ end {
    in_auto = 0;
    print $0;
    next;
}
!in_auto { print $0 }
' "$INDEX_FILE" > "$TEMP_OUT"

mv "$TEMP_OUT" "$INDEX_FILE"
echo "Index updated: $INDEX_FILE"
