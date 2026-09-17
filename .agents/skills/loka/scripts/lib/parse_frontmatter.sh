#!/usr/bin/env bash
# ==============================================================================
# parse_frontmatter.sh — Shared Frontmatter Parser for LOKA Knowledge Artifacts
# Implements schema.md v0.2.3 contract (canonical key ordering, 4-mandatory-field model with OKF v0.2 trust signals)
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# ------------------------------------------------------------------------------
# Output Formatting & Color Gating
# ------------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN=''
    RED=''
    YELLOW=''
    CYAN=''
    BOLD=''
    NC=''
fi

# ------------------------------------------------------------------------------
# Canonical Domain & Schema Enums (Single Source of Truth)
# ------------------------------------------------------------------------------
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

# Derive CANONICAL_TYPES strictly from CANONICAL_DOMAINS SSOT via domain_to_type
CANONICAL_TYPES=()
for _domain in "${CANONICAL_DOMAINS[@]}"; do
    CANONICAL_TYPES+=("$(domain_to_type "$_domain")")
done

parse_frontmatter() {
    local target_file="$1"

    if [[ ! -f "$target_file" ]]; then
        printf "ERR=File does not exist: %s\n" "$target_file"
        return 0
    fi

    local types_pattern="^($(IFS='|'; echo "${CANONICAL_TYPES[*]}"))$"
    local types_csv="$(printf ", %s" "${CANONICAL_TYPES[@]}")"
    types_csv="${types_csv:2}"

    awk -v types_pattern="$types_pattern" -v types_csv="$types_csv" '
    BEGIN {
        err = ""
        err_delimiter = ""
        err_order = ""
        err_duplicate = ""
        err_unknown = ""
        err_comments = ""
        err_blank = ""
        err_malformed = ""
        in_fm = 0
        fm_start = 0
        fm_end = 0
        line_count = 0
        key_count = 0

        id = ""; name = ""; type = ""; status = ""
        deprecated = ""; description = ""; created = ""; stale_after = ""; owner = ""; verified = ""; sources = ""

        has_id = 0; has_name = 0; has_type = 0; has_status = 0
        has_deprecated = 0; has_description = 0; has_created = 0; has_stale_after = 0; has_owner = 0; has_verified = 0; has_sources = 0

        unknown_keys = ""
    }
    function clean_val(v) {
        sub(/^[ \t]+/, "", v)
        sub(/[ \t]+$/, "", v)
        if (v ~ /^"/) {
            if (v !~ /^"([^"\\]|\\.)*"$/) {
                if (err == "") err = "Ambiguous or malformed double-quoted scalar: " v
                return v
            }
            sub(/^"/, "", v)
            sub(/"$/, "", v)
            gsub(/\\"/, "\"", v)
            gsub(/\\\\/, "\\", v)
            return v
        } else if (v ~ /^\047/) {
            if (v !~ /^\047([^\047]|\047\047)*\047$/) {
                if (err == "") err = "Ambiguous or malformed single-quoted scalar: " v
                return v
            }
            sub(/^\047/, "", v)
            sub(/\047$/, "", v)
            gsub(/\047\047/, "\047", v)
            return v
        }
        return v
    }
    {
        line_count++
        raw = $0
        gsub(/\r/, "", raw)
    }
    NR == 1 {
        if (raw ~ /^---[ \t]*$/) {
            in_fm = 1
            fm_start = 1
        } else {
            err_delimiter = "Line 1 must be opening delimiter --- (found: " raw ")"
        }
        next
    }
    in_fm {
        if (raw ~ /^---[ \t]*$/) {
            in_fm = 0
            fm_end = line_count
            exit
        }
        if (raw ~ /^[a-zA-Z0-9_-]+:[ \t]*/) {
            key = raw
            sub(/:[ \t]*.*$/, "", key)
            sub(/^[ \t]+/, "", key)
            val = raw
            sub(/^[a-zA-Z0-9_-]+:[ \t]*/, "", val)
            val = clean_val(val)

            key_count++
            key_arr[key_count] = key

            if (key == "id") {
                if (has_id && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: id"
                id = val
                has_id = 1
            } else if (key == "name") {
                if (has_name && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: name"
                name = val
                has_name = 1
            } else if (key == "type") {
                if (has_type && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: type"
                type = val
                has_type = 1
            } else if (key == "status") {
                if (has_status && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: status"
                status = val
                has_status = 1
            } else if (key == "deprecated") {
                if (has_deprecated && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: deprecated"
                deprecated = val
                has_deprecated = 1
            } else if (key == "description") {
                if (has_description && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: description"
                description = val
                has_description = 1
            } else if (key == "created") {
                if (has_created && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: created"
                created = val
                has_created = 1
            } else if (key == "stale_after") {
                if (has_stale_after && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: stale_after"
                stale_after = val
                has_stale_after = 1
            } else if (key == "owner") {
                if (has_owner && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: owner"
                owner = val
                has_owner = 1
            } else if (key == "verified") {
                if (has_verified && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: verified"
                verified = val
                has_verified = 1
            } else if (key == "sources") {
                if (has_sources && err_duplicate == "") err_duplicate = "Duplicate frontmatter key: sources"
                sources = val
                has_sources = 1
            } else {
                if (unknown_keys == "") {
                    unknown_keys = key
                } else {
                    unknown_keys = unknown_keys ", " key
                }
            }
        } else if (raw ~ /^[ \t]*#/) {
            if (err_comments == "") {
                err_comments = "Comment lines are prohibited in frontmatter (line " line_count ": " raw ")"
            }
        } else if (raw ~ /^[ \t]*$/) {
            if (err_blank == "") {
                err_blank = "Blank lines are prohibited in frontmatter (line " line_count ")"
            }
        } else {
            if (err_malformed == "") {
                err_malformed = "Malformed frontmatter line " line_count ": " raw
            }
        }
    }
    END {
        expected_end = (fm_end > 0 ? fm_end : 0)
        if (unknown_keys != "" && err_unknown == "") {
            err_unknown = "Unknown frontmatter key(s) prohibited: " unknown_keys
        }
        if (err_delimiter == "" && fm_start == 1 && fm_end == 0) {
            err_delimiter = "Missing closing frontmatter delimiter ---"
        }
        if (line_count < 2 && err_delimiter == "") {
            err_delimiter = "File too short to contain valid frontmatter"
        }

        canonical_keys[1] = "id"
        canonical_keys[2] = "name"
        canonical_keys[3] = "type"
        canonical_keys[4] = "status"
        canonical_keys[5] = "deprecated"
        canonical_keys[6] = "description"
        canonical_keys[7] = "created"
        canonical_keys[8] = "stale_after"
        canonical_keys[9] = "owner"
        canonical_keys[10] = "verified"
        canonical_keys[11] = "sources"

        err_order = ""
        curr_pos = 1
        for (i = 1; i <= key_count; i++) {
            found_idx = 0
            for (j = curr_pos; j <= 11; j++) {
                if (key_arr[i] == canonical_keys[j]) {
                    found_idx = j
                    break
                }
            }
            if (found_idx == 0) {
                err_order = "Key order violation: key \"" key_arr[i] "\" is unexpected or out of canonical sequence"
                break
            }
            curr_pos = found_idx + 1
        }

        missing = ""
        if (!has_id || id == "") missing = missing (missing == "" ? "" : ", ") "id"
        if (!has_name || name == "") missing = missing (missing == "" ? "" : ", ") "name"
        if (!has_type || type == "") missing = missing (missing == "" ? "" : ", ") "type"
        if (!has_description || description == "") missing = missing (missing == "" ? "" : ", ") "description"

        format_err = ""
        if (has_id && id == "") {
            format_err = "Field id declared but value is empty"
        } else if (has_name && name == "") {
            format_err = "Field name declared but value is empty"
        } else if (has_type && type == "") {
            format_err = "Field type declared but value is empty"
        } else if (has_description && description == "") {
            format_err = "Field description declared but value is empty"
        } else if (has_status && status == "") {
            format_err = "Field status declared but value is empty"
        } else if (has_deprecated && deprecated == "") {
            format_err = "Field deprecated declared but value is empty"
        } else if (has_created && created == "") {
            format_err = "Field created declared but value is empty"
        } else if (has_stale_after && stale_after == "") {
            format_err = "Field stale_after declared but value is empty"
        } else if (has_owner && owner == "") {
            format_err = "Field owner declared but value is empty"
        } else if (has_verified && verified == "") {
            format_err = "Field verified declared but value is empty"
        } else if (has_sources && sources == "") {
            format_err = "Field sources declared but value is empty"
        } else if (has_id && id !~ /^[a-z0-9-]+$/) {
            format_err = "Invalid id (" id "): must be lowercase kebab-case"
        } else if (has_type && type !~ types_pattern) {
            format_err = "Invalid type (" type "): must be one of " types_csv
        } else if (has_status && status !~ /^(draft|test|active)$/) {
            format_err = "Invalid status (" status "): must be one of draft, test, active"
        } else if (has_deprecated && deprecated !~ /^(true|false)$/) {
            format_err = "Invalid deprecated flag (" deprecated "): must be boolean literal true or false"
        } else if (has_created && created !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
            format_err = "Invalid created date (" created "): must match YYYY-MM-DD"
        } else if (has_stale_after && stale_after !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
            format_err = "Invalid stale_after date (" stale_after "): must match YYYY-MM-DD"
        } else if (has_verified && verified !~ /^(human|attested|automated)$/) {
            format_err = "Invalid verified status (" verified "): must be one of human, attested, automated"
        } else if (has_sources && sources !~ /^\[.*\]$/) {
            format_err = "Invalid sources array (" sources "): must be an inline list [\"url\", ...]"
        }

        validation_err = ""
        if (missing != "") {
            validation_err = "Missing mandatory frontmatter field(s): " missing
        } else if (err_order != "") {
            validation_err = err_order
        } else if (format_err != "") {
            validation_err = format_err
        }

        final_err = ""
        if (err_delimiter != "") {
            final_err = err_delimiter
        } else if (err_malformed != "") {
            final_err = err_malformed
        } else if (err_comments != "") {
            final_err = err_comments
        } else if (err_blank != "") {
            final_err = err_blank
        } else if (err_duplicate != "") {
            final_err = err_duplicate
        } else if (err_unknown != "") {
            final_err = err_unknown
        } else if (err != "") {
            final_err = err
        } else if (validation_err != "") {
            final_err = validation_err
        }

        printf "ERR=%s\n", final_err
        printf "ERR_DELIMITER=%s\n", err_delimiter
        printf "ERR_ORDER=%s\n", err_order
        printf "ERR_DUPLICATE=%s\n", err_duplicate
        printf "ERR_UNKNOWN=%s\n", err_unknown
        printf "ERR_COMMENTS=%s\n", err_comments
        printf "ERR_BLANK=%s\n", err_blank
        printf "ERR_MALFORMED=%s\n", err_malformed
        printf "EXPECTED_END=%d\n", expected_end
        printf "FM_START=%d\n", fm_start
        printf "FM_END=%d\n", fm_end
        printf "HAS_ID=%d\n", has_id
        printf "HAS_NAME=%d\n", has_name
        printf "HAS_TYPE=%d\n", has_type
        printf "HAS_STATUS=%d\n", has_status
        printf "HAS_DEPRECATED=%d\n", has_deprecated
        printf "HAS_DESCRIPTION=%d\n", has_description
        printf "HAS_CREATED=%d\n", has_created
        printf "HAS_STALE_AFTER=%d\n", has_stale_after
        printf "HAS_OWNER=%d\n", has_owner
        printf "HAS_VERIFIED=%d\n", has_verified
        printf "HAS_SOURCES=%d\n", has_sources
        printf "ID=%s\n", id
        printf "NAME=%s\n", name
        printf "TYPE=%s\n", type
        printf "STATUS=%s\n", status
        printf "DEPRECATED=%s\n", deprecated
        printf "DESCRIPTION=%s\n", description
        printf "CREATED=%s\n", created
        printf "STALE_AFTER=%s\n", stale_after
        printf "OWNER=%s\n", owner
        printf "VERIFIED=%s\n", verified
        printf "SOURCES=%s\n", sources
        printf "UNKNOWN_KEYS=%s\n", unknown_keys
        printf "MISSING_FIELDS=%s\n", missing
    }
    ' "$target_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <file.md>" >&2
        exit 1
    fi
    parse_frontmatter "$1"
fi
