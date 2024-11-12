<h1 align="center">shef</h1>

> shef is shef, that cook for you

`shef extracts IPs from Shodan searches. just the IPs you need.`


- Extract IPs from Shodan searches
- Multi-page support with API
- Random User-Agent rotation
- Clean, pipe-friendly output
- Zero dependencies (just bash & curl)

`arguments`
<pre>
  -q   : Search query (required)
  -p   : Number of pages (optional, default: 1)
  -api : Shodan API key (optional, required for multiple pages)
</pre>

`example commands`

```bash
  ./shef.sh -q "apache" > apache_ips.txt # Search for apache servers
```
```bash
./shef.sh -q 'org:\"Google LLC\"' # Search with organization filter:
```
```bash
./shef.sh -q "port:443" | sort -u # Search with port filter:
```
```bash
./shef.sh -q "apache" -p 3 -api "YOUR_API_KEY" # Multi-page search with API
```

```bash
./shef.sh -q "apache" | xargs -I {} nmap -sV {} # Scan found IPs with nmap
```
```bash
./shef.sh -q "apache" | tee ips.txt | wc -l # Save to file and count results
```
```bash
./shef.sh -q "apache" | grep -v "^10\." > public_ips.txt # Filter and process results
```

`If you see no results`
- Check your query syntax
- Verify API key if using multiple pages
- Ensure you have curl installed
- Check your internet connection


<br>
<br>
<br>
<p align="center">
Made with <3 by <a href="https://github.com/1hehaq" >@1hehaq</a>
<br>
Follow me on <a href="https://twitter.com/1hehaq">𝕏</a>
</p>
