#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'

usage() {
    echo "shef - extract/scrape IPs from shodan"
    echo "Follow @1hehaq on Github & 𝕏"
    echo
    echo "Usage:"
    echo "  $0 -q {query} optional: -p {pages} -api {api_key}"
    echo
    echo "Options:"
    echo "  -q    Search query (required)"
    echo "  -p    Number of pages to scrape (default: 1)"
    echo "  -api  Shodan API key (optional, required for multiple pages)"
    exit 1
}

scrape_web() {
    local query=$1
    local encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    USER_AGENTS=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        "Mozilla/5.0 (X11; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Safari/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_5_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:91.0) Gecko/20100101 Firefox/91.0"
        "Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
        "Mozilla/5.0 (iPad; CPU OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Mobile/15E148 Safari/604.1"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.164 Safari/537.36 Edg/91.0.864.71"
        "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:91.0) Gecko/20100101 Firefox/91.0"
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36 OPR/78.0.4093.147"
        "Mozilla/5.0 (Android 11; Mobile; rv:91.0) Gecko/91.0 Firefox/91.0"
        "Mozilla/5.0 (Linux; Android 11; SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.159 Mobile Safari/537.36"
    )
    UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}
    
    response=$(curl -s -A "$UA" "https://www.shodan.io/search?query=${encoded_query}&page=1")
    if [[ -n "$response" ]]; then
        echo "$response" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort -u
    fi
}

scrape_api() {
    local query=$1
    local page=$2
    local api_key=$3
    local encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    response=$(curl -s "https://api.shodan.io/shodan/host/search?key=${api_key}&query=${encoded_query}&page=${page}")
    
    if [[ "$response" == *"error"* ]]; then
        echo -e "${RED}Error: Invalid API key or rate limit exceeded${NC}" >&2
        return 1
    fi
    
    if [[ -n "$response" ]]; then
        echo "$response" | grep -oE '"ip_str":"([0-9]{1,3}\.){3}[0-9]{1,3}"' | cut -d'"' -f4 | sort -u
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -q) QUERY="$2"; shift 2 ;;
        -p) PAGES="$2"; shift 2 ;;
        -api) API_KEY="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
done

[[ -z "$QUERY" ]] && usage
[[ -z "$PAGES" ]] && PAGES=1

if [[ $PAGES -gt 1 && -z "$API_KEY" ]]; then
    echo -e "${RED}Error: API key required for fetching multiple pages${NC}" >&2
    echo -e "${RED}Continuing with page 1 only...${NC}" >&2
    PAGES=1
fi

temp_file=$(mktemp)
trap 'rm -f $temp_file' EXIT

if [[ -n "$API_KEY" ]]; then
    for ((page=1; page<=PAGES; page++)); do
        scrape_api "$QUERY" "$page" "$API_KEY" >> "$temp_file"
        if [[ $? -ne 0 ]]; then
            break
        fi
        [[ $page -lt $PAGES ]] && sleep 2
    done
else
    scrape_web "$QUERY" >> "$temp_file"
fi

if [[ -s "$temp_file" ]]; then
    sort -u "$temp_file"
fi
