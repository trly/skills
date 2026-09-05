#!/usr/bin/env bash
#
# check-support.sh — Query the endoflife.date API for dependency support status.
#
# Usage:
#   check-support.sh <product>                 Show all release cycles with support status
#   check-support.sh <product> <version>       Check a specific version's support status
#   check-support.sh --latest <product>        Show the latest release cycle
#   check-support.sh --search <term>           Search for a product by name or label
#   check-support.sh --release <product> <cycle>  Show a specific release cycle
#   check-support.sh --help                    Show this help message
#
# Requirements: curl. jq is optional but recommended for formatted output.
#
set -euo pipefail

readonly API_BASE="https://endoflife.date/api/v1"

print_usage() {
    cat <<'EOF'
Usage:
  check-support.sh <product>                    Show all release cycles with support status
  check-support.sh <product> <version>          Check a specific version's support status
  check-support.sh --latest <product>           Show the latest release cycle
  check-support.sh --release <product> <cycle>  Show a specific release cycle
  check-support.sh --search <term>             Search for a product by name or label
  check-support.sh --help                      Show this help message
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

have_jq() {
    command -v jq >/dev/null 2>&1
}

# Fetch JSON from an API endpoint. Follows redirects, suppresses progress.
fetch() {
    local url="$1"
    local response
    local http_code

    # Capture both body and HTTP status code.
    response=$(curl -sS -L -w "\n%{http_code}" "$url" 2>/dev/null) || {
        # curl failed to connect or similar
        die "Failed to fetch $url"
    }

    # Split last line (HTTP status code) from body.
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    case "$http_code" in
        200)
            echo "$body"
            ;;
        404)
            die "Not found (404): $url — the product or release cycle does not exist on endoflife.date."
            ;;
        429)
            die "Rate limited (429): too many requests. Wait and retry."
            ;;
        301|302)
            die "Redirect ($http_code) from $url — this should have been followed automatically."
            ;;
        *)
            die "HTTP $http_code from $url"
            ;;
    esac
}

# Classify a release cycle's support status from JSON fields.
# Arguments: isMaintained isEol isEoas isEoes isDiscontinued
classify_status() {
    local is_maintained="$1"
    local is_eol="$2"
    local is_eoas="$3"
    local is_eoes="$4"
    local is_discontinued="$5"

    if [[ "$is_discontinued" == "true" ]]; then
        echo "Discontinued"
        return
    fi

    if [[ "$is_eol" == "true" ]]; then
        if [[ -n "$is_eoes" && "$is_eoes" != "true" ]]; then
            echo "Extended support"
        else
            echo "End-of-life"
        fi
        return
    fi

    if [[ "$is_eoas" == "true" ]]; then
        echo "Maintenance only"
        return
    fi

    if [[ "$is_maintained" == "true" ]]; then
        echo "Active support"
        return
    fi

    echo "Unknown"
    return
}

# Format a date field, handling null/absent values.
format_date() {
    local val="$1"
    if [[ -z "$val" || "$val" == "null" ]]; then
        echo "—"
    else
        echo "$val"
    fi
}

# Show all release cycles for a product.
show_product() {
    local product="$1"
    local json
    json=$(fetch "${API_BASE}/products/${product}")

    if have_jq; then
        local label generated_at
        label=$(echo "$json" | jq -r '.result.label')
        generated_at=$(echo "$json" | jq -r '.generated_at')

        echo "Product: ${label} (${product})"
        echo "Data generated: ${generated_at}"
        echo ""

        # Print a table of release cycles.
        echo "$json" | jq -r '
            .result.releases[]
            | [
                .name,
                (if .isMaintained then "yes" else "no" end),
                (if .isLts then "yes" else "no" end),
                (if .isEol then "yes" else "no" end),
                (.eolFrom // "—"),
                (if .isEoas == true then "yes" elif .isEoas == false then "no" else "—" end),
                (.eoasFrom // "—"),
                (.latest.name // "—"),
                (.latest.date // "—")
              ] | @tsv
        ' | {
            printf "%-12s  %-10s  %-5s  %-6s  %-12s  %-10s  %-12s  %-12s  %-12s\n" \
                "Cycle" "Maintained" "LTS" "EOL" "EOL Date" "EOAS" "EOAS Date" "Latest" "Latest Date"
            printf '%0.s-' {1..100}; echo
            while IFS=$'\t' read -r cycle maintained lts eol eol_date eoas eoas_date latest latest_date; do
                printf "%-12s  %-10s  %-5s  %-6s  %-12s  %-10s  %-12s  %-12s  %-12s\n" \
                    "$cycle" "$maintained" "$lts" "$eol" "$eol_date" "$eoas" "$eoas_date" "$latest" "$latest_date"
            done
        }
    else
        echo "jq is not installed — showing raw JSON."
        echo "$json"
    fi
}

# Check a specific version against a product's release cycles.
# Tries exact match first, then prefix match (e.g. 3.12.5 -> cycle 3.12).
check_version() {
    local product="$1"
    local version="$2"
    local json
    json=$(fetch "${API_BASE}/products/${product}")

    if have_jq; then
        local label generated_at
        label=$(echo "$json" | jq -r '.result.label')
        generated_at=$(echo "$json" | jq -r '.generated_at')

        # Try exact match on cycle name, then prefix match.
        local cycle_json
        cycle_json=$(echo "$json" | jq -e --arg v "$version" '.result.releases[] | select(.name == $v)' 2>/dev/null) || {
            # Prefix match: find the longest cycle name that is a prefix of the version.
            cycle_json=$(echo "$json" | jq -e --arg v "$version" '
                [.result.releases[] | select(.name as $name | ($v | startswith($name)))] | sort_by(.name | length) | reverse | .[0]
            ' 2>/dev/null) || true
        }

        if [[ -z "$cycle_json" ]]; then
            die "Version '${version}' does not match any release cycle for product '${product}'. Available cycles: $(echo "$json" | jq -r '.result.releases[].name' | tr '\n' ' ')"
        fi

        local cycle_name is_maintained is_lts is_eol eol_from is_eoas eoas_from is_eoes eoes_from is_discontinued latest_name latest_date release_date

        cycle_name=$(echo "$cycle_json" | jq -r '.name')
        is_maintained=$(echo "$cycle_json" | jq -r '.isMaintained')
        is_lts=$(echo "$cycle_json" | jq -r '.isLts')
        is_eol=$(echo "$cycle_json" | jq -r '.isEol')
        eol_from=$(echo "$cycle_json" | jq -r '.eolFrom // "—"')
        is_eoas=$(echo "$cycle_json" | jq -r 'if has("isEoas") then (.isEoas | tostring) else "" end')
        eoas_from=$(echo "$cycle_json" | jq -r 'if has("eoasFrom") then (.eoasFrom // "—") else "" end')
        is_eoes=$(echo "$cycle_json" | jq -r 'if has("isEoes") then (.isEoes | tostring) else "" end')
        eoes_from=$(echo "$cycle_json" | jq -r 'if has("eoesFrom") then (.eoesFrom // "—") else "" end')
        is_discontinued=$(echo "$cycle_json" | jq -r 'if has("isDiscontinued") then (.isDiscontinued | tostring) else "" end')
        latest_name=$(echo "$cycle_json" | jq -r '.latest.name // "—"')
        latest_date=$(echo "$cycle_json" | jq -r '.latest.date // "—"')
        release_date=$(echo "$cycle_json" | jq -r '.releaseDate')

        local status
        status=$(classify_status "$is_maintained" "$is_eol" "$is_eoas" "$is_eoes" "$is_discontinued")

        echo "Product: ${label} (${product})"
        echo "Version: ${version} (cycle: ${cycle_name})"
        echo "Data generated: ${generated_at}"
        echo ""
        echo "  Status:              ${status}"
        echo "  Release date:        ${release_date}"
        echo "  LTS:                 $([[ "$is_lts" == "true" ]] && echo "yes" || echo "no")"
        echo "  Maintained:          $([[ "$is_maintained" == "true" ]] && echo "yes" || echo "no")"
        echo "  End-of-life:         $([[ "$is_eol" == "true" ]] && echo "yes (past EOL)" || echo "no")"
        echo "  EOL date:            $(format_date "$eol_from")"

        if [[ -n "$is_eoas" ]]; then
            local eoas_val
            if [[ "$is_eoas" == "true" ]]; then eoas_val="ended"; else eoas_val="active"; fi
            echo "  Active support:      ${eoas_val}"
            echo "  EOAS date:           $(format_date "$eoas_from")"
        fi

        if [[ -n "$is_eoes" ]]; then
            local eoes_val
            if [[ "$is_eoes" == "true" ]]; then eoes_val="ended"; elif [[ "$is_eoes" == "false" ]]; then eoes_val="active"; else eoes_val="not eligible"; fi
            echo "  Extended support:    ${eoes_val}"
            echo "  EOES date:           $(format_date "$eoes_from")"
        fi

        if [[ "$is_discontinued" == "true" ]]; then
            echo "  Discontinued:        yes"
        fi

        echo "  Latest in cycle:     ${latest_name} (${latest_date})"
    else
        echo "jq is not installed — showing raw JSON."
        echo "$json"
    fi
}

# Show the latest release cycle for a product.
show_latest() {
    local product="$1"
    local json
    json=$(fetch "${API_BASE}/products/${product}/releases/latest")

    if have_jq; then
        local label generated_at
        # Fetch product label separately for display.
        local product_json
        product_json=$(fetch "${API_BASE}/products/${product}") || product_json=""
        label=$(echo "$product_json" | jq -r '.result.label // "Unknown"')
        generated_at=$(echo "$json" | jq -r '.generated_at')

        local cycle_name is_maintained is_lts is_eol eol_from latest_name latest_date release_date

        cycle_name=$(echo "$json" | jq -r '.result.name')
        is_maintained=$(echo "$json" | jq -r '.result.isMaintained')
        is_lts=$(echo "$json" | jq -r '.result.isLts')
        is_eol=$(echo "$json" | jq -r '.result.isEol')
        eol_from=$(echo "$json" | jq -r '.result.eolFrom // "—"')
        latest_name=$(echo "$json" | jq -r '.result.latest.name // "—"')
        latest_date=$(echo "$json" | jq -r '.result.latest.date // "—"')
        release_date=$(echo "$json" | jq -r '.result.releaseDate')

        echo "Product: ${label} (${product})"
        echo "Latest release cycle: ${cycle_name}"
        echo "Data generated: ${generated_at}"
        echo ""
        echo "  Release date:   ${release_date}"
        echo "  LTS:            $([[ "$is_lts" == "true" ]] && echo "yes" || echo "no")"
        echo "  Maintained:     $([[ "$is_maintained" == "true" ]] && echo "yes" || echo "no")"
        echo "  End-of-life:    $([[ "$is_eol" == "true" ]] && echo "yes" || echo "no")"
        echo "  EOL date:       $(format_date "$eol_from")"
        echo "  Latest version: ${latest_name} (${latest_date})"
    else
        echo "jq is not installed — showing raw JSON."
        echo "$json"
    fi
}

# Show a specific release cycle.
show_release() {
    local product="$1"
    local cycle="$2"
    local json
    json=$(fetch "${API_BASE}/products/${product}/releases/${cycle}")

    if have_jq; then
        echo "$json" | jq '.result'
    else
        echo "jq is not installed — showing raw JSON."
        echo "$json"
    fi
}

# Search for products by name or label.
search_products() {
    local term="$1"
    local json
    json=$(fetch "${API_BASE}/products")

    if have_jq; then
        local generated_at total
        generated_at=$(echo "$json" | jq -r '.generated_at')
        total=$(echo "$json" | jq -r '.total')

        echo "Search term: ${term}"
        echo "Total products: ${total}"
        echo "Data generated: ${generated_at}"
        echo ""

        local results
        results=$(echo "$json" | jq -r --arg t "${term}" '
            .result[]
            | select((.name | ascii_downcase | contains($t | ascii_downcase))
                  or (.label | ascii_downcase | contains($t | ascii_downcase)))
            | [.name, .label, .category] | @tsv
        ')

        if [[ -z "$results" ]]; then
            echo "No products found matching '${term}'."
            echo ""
            echo "Browse all products at https://endoflife.date/api/v1/products"
        else
            printf "%-25s  %-30s  %-15s\n" "Name (slug)" "Label" "Category"
            printf '%0.s-' {1..75}; echo
            while IFS=$'\t' read -r name label category; do
                printf "%-25s  %-30s  %-15s\n" "$name" "$label" "$category"
            done <<< "$results"
        fi
    else
        echo "jq is not installed — showing raw JSON."
        echo "$json"
    fi
}

# --- Main argument parsing ---

if [[ $# -eq 0 ]]; then
    print_usage
    exit 0
fi

case "${1}" in
    --help|-h)
        print_usage
        exit 0
        ;;
    --search)
        [[ $# -lt 2 ]] && die "--search requires a search term"
        search_products "$2"
        ;;
    --latest)
        [[ $# -lt 2 ]] && die "--latest requires a product name"
        show_latest "$2"
        ;;
    --release)
        [[ $# -lt 3 ]] && die "--release requires a product name and a release cycle name"
        show_release "$2" "$3"
        ;;
    *)
        if [[ $# -eq 1 ]]; then
            show_product "$1"
        elif [[ $# -eq 2 ]]; then
            check_version "$1" "$2"
        else
            print_usage
            exit 1
        fi
        ;;
esac
