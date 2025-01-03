#!/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# facets array
declare -A FACETS=(
    ["ip"]="IP addresses (excludes internal IPs)"
    ["domain"]="Subdomains and related domains"
    ["port"]="Open ports"
    ["vuln"]="Known vulnerabilities"
    ["http.title"]="Web page titles"
    ["http.component"]="Web technologies"
)

USER_AGENTS=(
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Firefox/122.0"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64) Firefox/122.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15) Firefox/122.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Edge/120.0.2210.133"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Edge/120.0.2210.133"
    "Mozilla/5.0 (X11; Linux x86_64) Edge/120.0.2210.133"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.2210.133"
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2_1 like Mac OS X) Version/17.2 Mobile/15E148 Safari/604.1"
    "Mozilla/5.0 (iPad; CPU OS 17_2_1 like Mac OS X) Version/17.2 Mobile/15E148 Safari/604.1"
)

usage() {
    # indian flag colors
    SAFFRON='\033[38;5;208m'  # indian saffron
    WHITE='\033[37m'          # indian white
    INDGREEN='\033[38;5;28m'  # indian green
    
    echo ""
    echo ""
    echo -e "   ${SAFFRON}┌─┐┬ ┬┌─┐┌─┐"
    echo -e "   ${WHITE}└─┐├─┤├┤ ├┤"
    echo -e "   ${INDGREEN}└─┘┴ ┴└─┘└    ${WHITE}by ${YELLOW}\e]8;;https://github.com/1hehaq\a@1hehaq\e]8;;\a${NC}" 
    echo

    echo -e "${GREEN}Usage: $0 [OPTIONS] -q <query>${NC}"
    echo
    echo "Options:"
    echo "  -q    Query string (required)"
    echo "  -f    Facet type (default: ip)"
    echo "  -l    Limit results (default: 100)"
    echo "  -h    Show this help message"
    echo
    echo "Available facets:"
    for facet in "${!FACETS[@]}"; do
        echo -e "  ${YELLOW}$facet${NC}: ${FACETS[$facet]}"
    done
    echo
    exit 1
}

error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

validate_facet() {
    local facet=$1
    [[ -z "${FACETS[$facet]}" ]] && error_exit "Invalid facet: $facet\nUse -F to list available facets"
}

check_dependencies() {
    local deps=("curl" "jq" "grep" "sort")
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || error_exit "$dep is required but not installed"
    done
}

parse_url() {
    local query=$1
    local facet=$2
    local limit=$3
    
    [[ -z "$query" ]] && error_exit "Query parameter is required"
    
    local encoded_query
    encoded_query=$(echo "$query" | jq -sRr @uri) || error_exit "Failed to encode query"
    
    echo "https://www.shodan.io/search/facet?query=${encoded_query}&facet=${facet}&limit=${limit}"
}

validate_query() {
    local query="$1"
    local facet="${2:-ip}" #default = ip

    if [[ "$query" =~ ^[[:space:]]*$ ]]; then
        error_exit "empty query provided"
    fi

    if [[ ! "$query" =~ ^[a-zA-Z0-9:\"\ \.\-\_\&\|\!\(\)\{\}\[\]\^\~\*\?\:\\]+$ ]]; then
    # if [[ ! "$query" =~ ^[a-zA-Z0-9:\"\ \.\-\_]+$ ]]; then
        echo -e "${RED}error: invalid characters found in query${NC}" >&2
        exit 1
    fi

    if [[ "$query" =~ facet: ]]; then
        echo -e "${RED}error: use -f option to specify facet${NC}" >&2
        exit 1
    fi

    local quote_count
    quote_count=$(echo "$query" | grep -o '"' | wc -l)
    if (( quote_count % 2 != 0 )); then
        echo -e "${YELLOW}Warning:${NC} unmatched quotes detected. attempting to fix..." >&2
        query="${query%\"}\""
    fi

    # query=$(echo "$query" | sed 's/[\&\|\!\(\)\{\}\[\]\^\~\*\?\:\\]/\\&/g')
    echo -e "${GREEN}Fixed query: $query${NC}" >&2
}

check_response() {
    local response="$1"
    
    if echo "$response" | grep -q "wildcard searches are not supported"; then
        error_exit "Error: wildcard searches are not supported"
    fi
    
    if echo "$response" | grep -q "no information available"; then
        echo "Note: no information available"
        exit 0
    fi

    if echo "$response" | grep -q "search request has timed out or your query was invalid"; then
        error_exit "Error: search request timed out or invalid query"
    fi
    
    if echo "$response" | grep -q "no results found"; then
        echo "Note: no results found"
        exit 0
    fi
}

extract_facets() {
    local html="$1"
    local facet_type="$2"

    if [[ "$facet_type" == "domain" ]]; then
        echo "$html" | grep -oP '<a href="/search\?query=.*?domain%3A%22\K[^"]+(?=%22"|")' | sed 's/%22$//'
    elif [[ "$facet_type" == "port" ]]; then
        echo "$html" | grep -oP '<a href="/search\?query=.*?port%3A\K[0-9]+(?=")' | sort -n
    elif [[ "$facet_type" == "vuln" ]]; then
        echo "$html" | grep -oP '<a href="/search\?query=.*?vuln%3A%22\K[^"]+(?=%22")' | sort
    elif [[ "$facet_type" == "http.component" ]]; then
        echo "$html" | grep -oP '<a href="/search\?query=.*?http\.component%3A%22\K[^"]+(?=%22")' | sort
    elif [[ "$facet_type" == "http.title" ]]; then
        echo "$html" | grep -oP '<a href="/search\?query=.*?http\.title%3A%22\K[^"]+(?=%22")' | sort | urldecode

    else
        echo "$html" | grep -oP ">${facet_type}:\K[^<]+" || \
        echo "$html" | grep -oP "query=${facet_type}:\K[^&]+" || \
        echo "$html" | grep -oP ">${facet_type}:\"?\K[^\"<]+"
    fi
}

urldecode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.unquote(sys.stdin.read()))" 
}

main() {
    check_dependencies

    local query=""
    local facet="ip"
    local limit=100

    # parse cmd
    while getopts "q:f:l:h" opt; do
        case $opt in
            q) query="$OPTARG" ;;
            f) facet="$OPTARG" 
               validate_facet "$facet" ;;
            l) limit="$OPTARG"
               [[ ! "$limit" =~ ^[0-9]+$ ]] && error_exit "limit must be a number" ;;
            h) usage ;;
            # help) usage ;;
            *) usage ;;
        esac
    done

    [[ -z "$query" ]] && error_exit "query parameter (-q) is required"
    
    validate_query "$query" "$facet"

    local UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}
    local url
    url=$(parse_url "$query" "$facet" "$limit")

    #verbose mode
    [[ $verbose == true ]] && echo -e "${GREEN}Querying: $url${NC}" >&2

    local html
    html=$(curl -s -A "$UA" \
        -H "Accept: text/html,application/xhtml+xml" \
        -H "Accept-Language: en-US,en;q=0.9" \
        --compressed "$url") || error_exit "failed to fetch data from Shodan"

    check_response "$html"

    local results=$(extract_facets "$html" "$facet")
    if [[ -n "$results" ]]; then
        echo "$results"
    else
        echo "no $facet found" >&2
    fi
}

main "$@"
