#!/bin/env bash

[[ $# -ne 2 || $1 != "-q" ]] && { echo "Usage: $0 -q query"; exit 1; }

query=$2
encoded_query=$(echo "$query" | jq -sRr @uri)
url="https://www.shodan.io/search/facet?query=${encoded_query}&facet=ip"

UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

curl -s -A "$UA" \
    -H "Accept: text/html,application/xhtml+xml" \
    -H "Accept-Language: en-US,en;q=0.9" \
    --compressed "$url" | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
    grep -v '^0\.\|^127\.\|^169\.254\.\|^172\.\(1[6-9]\|2[0-9]\|3[0-1]\)\.\|^192\.168\.\|^10\.\|^224\.\|^240\.\|^281\.\|^292\.' | \
    sort -u
