<div align="center">
  
  ![shef](https://github.com/user-attachments/assets/fe2ff3ed-953c-427e-a9ca-04c629e1d10d)

</div>

> [!NOTE] 
> **shef extracts data from Shodan searches without API key. just what you need**

<br>

- Extract IPs, domains, and vulnerabilities
- Multiple facet support (ip, domain, port, vuln, http.*)
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
  -q    : Search query (required)
  -f    : Facet type (default: ip)
  -l    : Limit results (default: 100)
  -h    : Show help message
</pre>

<br>
<br>

`example commands`
```bash
# Get IPs running Apache
shef -q "apache" > apache_ips.txt

# Find subdomains of an organization
shef -q 'org:"Google LLC"' -f domain

# Get open ports of a product
shef -q "product:nginx" -f port

# Extract web technologies
shef -q "wordpress" -f http.component

# Find vulnerabilities
shef -q "product:jboss" -f vuln
```

`masshunting oneliner`
```bash
# Hunt for vulnerable services and verify
shef -q "product:apache" -f vuln | grep "CVE" | while read cve; do echo "[+] Checking $cve"; shef -q "vuln:$cve" -f ip | anew ips.txt | httpx -silent | nuclei -t cves/ -severity critical,high; done
```

<br>
<br>

`If you see no results or errors`
- Check your query syntax (use -h for help)
- Ensure you have curl installed
- Check your internet connection
- Note: Wildcard searches are not supported

<br>
<br>

> [!CAUTION] 
> **shef is not a tool for masshunting, it's a tool for extracting data from Shodan searches without API key.**

<br>
<br>
<br>
<p align="center">
Made with <3 by <a href="https://github.com/1hehaq" >@1hehaq</a>
<br>
Follow me on <a href="https://twitter.com/1hehaq">𝕏</a>
</p>
