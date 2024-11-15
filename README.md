<h1 align="center">shef</h1>

> shef is shef, that cook for you

`shef extracts IPs from Shodan searches. just the IPs you need.`


- Extract IPs from Shodan
- Random User-Agent rotation
- Clean, pipe-friendly output
- Zero dependencies (just bash & curl)


<br>
<br>

`installation`
> `oneliner`
```bash
git clone https://github.com/1hehaq/shef.git && cd shef && chmod +x shef.sh && sudo mv shef.sh /bin/shef && cd .. && rm -rf shef
```

<br>
<br>

`arguments`
<pre>
  -q   : Search query (required)
</pre>

<br>
<br>

`example commands`
```bash
shef -q "apache" > apache_ips.txt # Search for apache servers
```
```bash
shef -q 'org:\"Google LLC\"' # Search with organization filter
```
```bash
shef -q "port:443" | sort -u # Search with port filter
```
```bash
shef -q "apache" | xargs -I {} nmap -sV {} # Scan found IPs with nmap
```
```bash
shef -q "apache" | tee ips.txt | wc -l # Save to file and count results
```
```bash
shef -q "apache" | grep -v "^10\." > public_ips.txt # Filter and process results
```

<br>
<br>

`If you see no results`
- Check your query syntax
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
