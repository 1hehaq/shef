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

declare -A SEARCH_FILTERS=(
    ["port"]="Port number (e.g., port:80)"
    ["org"]="Organization (e.g., org:\"Microsoft\")"
    ["hostname"]="Hostname (e.g., hostname:example.com)"
    ["product"]="Product name (e.g., product:nginx)"
    ["vuln"]="CVE ID (e.g., vuln:CVE-2014-0160)"
    ["http.title"]="HTTP title (e.g., http.title:\"Index of\")"
    ["http.component"]="Web technologies (e.g., http.component:\"WordPress\")"
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
    echo -e "${SAFFRON}███████╗██╗  ██╗███████╗███████╗"
    echo -e "██╔════╝██║  ██║██╔════╝██╔════╝"
    echo -e "${WHITE}███████╗███████║█████╗  █████╗  "
    echo -e "╚════██║██╔══██║██╔══╝  ██╔══╝  "
    echo -e "${INDGREEN}███████║██║  ██║███████╗██║     "
    echo -e "╚══════╝╚═╝  ╚═╝╚══════╝╚═╝     ${NC}"
    echo -e "               ${WHITE}by ${YELLOW}\e]8;;https://github.com/1hehaq\a@1hehaq\e]8;;\a${NC}"
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
    echo "Query Examples:"
    echo -e "  ${GREEN}Basic search${NC}: apache"
    echo -e "  ${GREEN}With filter${NC}:  apache port:80 country:US"
    echo -e "  ${GREEN}Combined${NC}:     apache org:\"Microsoft\" os:\"Windows\""
    echo
    echo "Available Search Filters:"
    for filter in "${!SEARCH_FILTERS[@]}"; do
        echo -e "  ${RED}${filter}${NC}: ${SEARCH_FILTERS[$filter]}"
    done
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
    local issues=()

    if [[ "$query" =~ ^[[:space:]]*$ ]]; then
        error_exit "empty query provided"
    fi

    #check syntax errr
    if [[ "$query" =~ [^a-zA-Z0-9:\"\.\ \-_] ]]; then
        issues+=("found invalid characters: only alphanumeric, :, \", ., -, _ and spaces are allowed")
    fi

    local quote_count
    quote_count=$(echo "$query" | grep -o '"' | wc -l)
    if (( quote_count % 2 != 0 )); then
        issues+=("unmatched quotes: double quotes must be paired")
    fi

    for filter in "${!SEARCH_FILTERS[@]}"; do
        if [[ "$query" =~ $filter: ]]; then
            check_filter_syntax "$filter" "$query" issues
        fi
    done

    case $facet in
        "ip")
            if [[ "$query" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                issues+=("for direct IP search, consider using 'ip:' filter (e.g., ip:1.2.3.4)")
            fi
            ;;
        "port")
            if [[ "$query" =~ ^[0-9]+$ ]]; then
                issues+=("for port search, use 'port:' filter (e.g., port:80)")
            fi
            ;;
        "vuln")
            if [[ "$query" =~ ^CVE-[0-9]+-[0-9]+$ ]]; then
                issues+=("for CVE search, use 'vuln:' filter (e.g., vuln:CVE-2021-44228)")
            fi
            ;;
    esac

    if [ ${#issues[@]} -gt 0 ]; then
        echo -e "${YELLOW}query issues:${NC}"
        printf '%s\n' "${issues[@]}"
        echo -e "${GREEN}Tip: use -h to see available filters and syntax${NC}"
    fi
}

check_filter_syntax() {
    local filter="$1"
    local query="$2"
    local -n ref=$3
    local filter_value
    
    filter_value=$(echo "$query" | grep -oP "${filter}:\K([^\s\"]+|\"[^\"]+\")" | sed 's/^"\(.*\)"$/\1/')
    
    case $filter in
        "port")
            if ! [[ "$filter_value" =~ ^[0-9]+$ ]]; then
                ref+=("invalid port number: '$filter_value' (should be numeric)")
            elif (( filter_value > 65535 )); then
                ref+=("invalid port number: '$filter_value' (should be between 1-65535)")
            fi
            ;;
        "net")
            if ! [[ "$filter_value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
                ref+=("invalid network range: '$filter_value' (should be in CIDR notation, e.g., 192.168.0.0/16)")
            fi
            ;;
        "before"|"after")
            if ! [[ "$filter_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                ref+=("invalid date format: '$filter_value' (should be YYYY-MM-DD)")
            fi
            ;;
        "country")
            if ! [[ "$filter_value" =~ ^[A-Za-z]{2}$ ]]; then
                ref+=("invalid country code: '$filter_value' (should be 2-letter code, e.g., US)")
            fi
            ;;
        "ssl")
            if ! [[ "$filter_value" =~ ^(true|false)$ ]]; then
                ref+=("invalid ssl value: '$filter_value' (should be true or false)")
            fi
            ;;
        "http.status")
            if ! [[ "$filter_value" =~ ^[1-5][0-9]{2}$ ]]; then
                ref+=("invalid http status code: '$filter_value' (should be between 100-599)")
            fi
            ;;
    esac
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

main() {
    check_dependencies

    local query=""
    local facet="ip"
    local limit=100
    local json_output=false
    # local count_only=false    # Comment out
    local verbose=false

    # parse cmd
    while getopts "q:f:l:h" opt; do
        case $opt in
            q) query="$OPTARG" ;;
            f) facet="$OPTARG" 
               validate_facet "$facet" ;;
            l) limit="$OPTARG"
               [[ ! "$limit" =~ ^[0-9]+$ ]] && error_exit "limit must be a number" ;;
            h) usage ;;
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

    local response
    response=$(curl -s -A "$UA" \
        -H "Accept: text/html,application/xhtml+xml" \
        -H "Accept-Language: en-US,en;q=0.9" \
        --compressed "$url") || error_exit "Failed to fetch data from Shodan"

    check_response "$response"

    case $facet in
        "ip")
            if [[ -n "$response" ]]; then
                echo "$response" | \
                grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
                grep -v '^0\.\|^127\.\|^169\.254\.\|^172\.\(1[6-9]\|2[0-9]\|3[0-1]\)\.\|^192\.168\.\|^10\.\|^224\.\|^240\.' | \
                sort -u || echo "no public IPs found"
            fi
            ;;
        "domain")
            if [[ -n "$response" ]]; then
                echo "$response" | grep -oP 'domain":"[^"]+' | cut -d'"' -f3 | sort -u || echo "no domains found"
            fi
            ;;
        "port")
            if [[ -n "$response" ]]; then
                echo "$response" | grep -oP 'port":[0-9]+' | cut -d':' -f2 | sort -n -u || echo "no open ports found"
            fi
            ;;
        "vuln")
            if [[ -n "$response" ]]; then
                echo "$response" | grep -o 'CVE-[0-9]\{4\}-[0-9]\{4,\}' | sort -u || echo "no vulnerabilities found"
            fi
            ;;
        "http.title"|"http.component")
            if [[ -n "$response" ]]; then
                echo "$response" | grep -oP "${facet}\":\"[^\"]+\"" | cut -d'"' -f3 | sort -u || echo "no ${facet} found"
            fi
            ;;
    esac

    # if [[ $count_only == true ]]; then
    #     echo -e "\n${GREEN}Total results: $(echo "$response" | wc -l)${NC}"
    # fi
}

main "$@"
