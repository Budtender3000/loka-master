#!/usr/bin/env bash
# ==============================================================================
# parse_frontmatter.sh — Shared Frontmatter Parser for LOKA Knowledge Artifacts
# ==============================================================================

CANONICAL_DOMAINS=("profiles" "behaviors" "standards" "workflows" "tools" "meta")
CANONICAL_STATUSES=("draft" "test" "active")

domain_to_type() {
    local d="$1"
    case "$d" in
        profiles)  echo "profile" ;;
        behaviors) echo "behavior" ;;
        standards) echo "standard" ;;
        workflows) echo "workflow" ;;
        tools)     echo "tool" ;;
        meta)      echo "meta" ;;
        *)         echo "" ;;
    esac
}

type_to_domain() {
    local t="$1"
    case "$t" in
        profile)  echo "profiles" ;;
        behavior) echo "behaviors" ;;
        standard) echo "standards" ;;
        workflow) echo "workflows" ;;
        tool)     echo "tools" ;;
        meta)     echo "meta" ;;
        *)        echo "" ;;
    esac
}

CANONICAL_TYPES=()
for _domain in "${CANONICAL_DOMAINS[@]}"; do
    CANONICAL_TYPES+=("$(domain_to_type "$_domain")")
done

parse_frontmatter() {
    local target_file="$1"

    if [[ ! -f "$target_file" ]]; then
        echo "ERR=File does not exist: $target_file"
        return 0
    fi

    awk '
    BEGIN {
        in_fm = 0;
        closed = 0;
    }
    NR == 1 {
        if ($0 ~ /^---[[:space:]]*$/) {
            in_fm = 1;
            next;
        } else {
            print "ERR=Opening delimiter --- missing on line 1";
            exit;
        }
    }
    in_fm && !closed {
        if ($0 ~ /^---[[:space:]]*$/) {
            closed = 1;
            print "CLOSING_LINE=" NR;
            exit;
        }
        if ($0 ~ /^[a-zA-Z0-9_]+:[[:space:]]*/) {
            colon_idx = index($0, ":");
            key = substr($0, 1, colon_idx - 1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", key);
            val = substr($0, colon_idx + 1);
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", val);
            # strip surrounding single or double quotes
            if ((val ~ /^"[^"]*"$/) || (val ~ /^\047[^\047]*\047$/)) {
                val = substr(val, 2, length(val) - 2);
            }
            toupper_key = toupper(key);
            if (toupper_key in seen) {
                print "ERR=Duplicate frontmatter key: " key;
            }
            seen[toupper_key] = 1;
            print toupper_key "=" val;
        } else {
            print "ERR=Invalid frontmatter syntax on line " NR ": " $0;
        }
    }
    END {
        if (NR > 0 && in_fm && !closed) {
            print "ERR=Closing delimiter --- missing";
        }
    }
    ' "$target_file"
}
