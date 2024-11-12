#!/bin/env bash

[[ $# -ne 2 || $1 != "-q" ]] && { echo "Usage: $0 -q query"; exit 1; }

query=$2
encoded_query=$(echo "$query" | jq -sRr @uri)
url="https://www.shodan.io/search/facet?query=${encoded_query}&facet=ip"

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

UA=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}

curl -s -A "$UA" \
    -H "Accept: text/html,application/xhtml+xml" \
    -H "Accept-Language: en-US,en;q=0.9" \
    --compressed "$url" | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
    grep -v '^0\.\|^127\.\|^169\.254\.\|^172\.\(1[6-9]\|2[0-9]\|3[0-1]\)\.\|^192\.168\.\|^10\.\|^224\.\|^240\.\|^281\.\|^292\.' | \
    sort -u
