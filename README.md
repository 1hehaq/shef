<div align="center">
  
  ![shef](https://github.com/user-attachments/assets/fe2ff3ed-953c-427e-a9ca-04c629e1d10d)

</div>

> [!NOTE] 
> **shef is a simple tool for extracting data from Shodan searches without requiring an API key. It provides exactly what you need for efficient data retrieval.**

<br>

- **`Extract IP addresses, domain names, and known vulnerabilities with ease`**
- **`Supports multiple facets including IP, domain, port, vulnerability, and HTTP components`**
- **`Utilizes random User-Agent rotation to mimic diverse browsing behavior`**
- **`Produces clean, pipe-friendly output suitable for further processing`**
- **`Requires minimal dependencies (only bash and curl)`**

<br>
<br>

**_Installation_**
> `oneliner`
```bash
git clone https://github.com/1hehaq/shef.git && cd shef && chmod +x shef.sh && sudo mv shef.sh /bin/shef && cd .. && rm -rf shef
```

<br>
<br>

**_Arguments_**
<pre>
  -q    : Search query (required)
  -f    : Facet type (default: ip)
  -l    : Limit results (default: 100)
  -h    : Show help message
</pre>

<br>
<br>

**_Example Commands_**
```bash
# Retrieve IP addresses associated with Apache servers
shef -q "apache" > apache_ips.txt

# Discover subdomains related to a specific organization
shef -q 'org:"Google LLC"' -f domain

# Identify open ports for a particular product
shef -q "product:nginx" -f port

# Extract web technologies in use
shef -q "wordpress" -f http.component

# Find known vulnerabilities for a product
shef -q "product:jboss" -f vuln
```

<br>
<br>

- **_If you see no results or errors_**
  - **`Verify the syntax of your query (use -h for guidance)`**
  - **`Ensure that curl is installed on your system`**
  - **`Check your internet connection for stability`**
  - **`Note: Wildcard searches are not supported`**

<br>
<br>

> [!CAUTION] 
> **shef is designed for responsible use in extracting data from Shodan searches without an API key. Please use it ethically.**

<br>
<br>
<br>

<div align="center">
<p>

<a href="https://x.com/1hehaq">**`Follow me on`**</a> - `𝕏`

</p>
</div>
