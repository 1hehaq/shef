<div align="center">
  <img src="https://github.com/user-attachments/assets/e87dd5b5-3135-4fed-8a9f-dc75671b85a6" alt="shef" width="955">
</div>

<br>
<br>
<br>


> [!NOTE] 
> **shef is a minimal tool for bringing facets into your terminal without any API key.**

<br>

- <sub> **supports All kind of shodan query (those which only supported on [facet](https://www.shodan.io/search/facet))** </sub>
- <sub> **extracts multiple [facets](https://www.shodan.io/search/facet) (Use `-list` flag to see all facet types)** </sub>
- <sub> **rotates random User-Agent** </sub>
- <sub> **clean and pipe friendly output** </sub>

<br>
<br>

<h4>Installation</h4>

```bash
go install github.com/1hehaq/shef@latest
```

<br>

<h6>setup autocomletion for facets & flags</h6>

```bash
wget https://raw.githubusercontent.com/1hehaq/shef/refs/heads/main/install.sh && sudo bash install.sh && rm install.sh
```

- <sub>**then try this**</sub>
  ```bash
  shef -q nginx -f <TAB>
  ```
  ```bash
  shef -q nginx -f http.<TAB>
  ```


<br>
<br>

<h4>Flags</h4>

<pre>
  -q    : search query (required)
  -f    : facet type (default: ip)
  -list : list all facet types
  -json : stdout in JSON format
  -h    : show help message
</pre>

<div align="center">
  <img width="3650" height="1838" alt="help" src="https://github.com/user-attachments/assets/c44839a6-f8ad-40dd-bb66-36a1b5423fd4" />
</div>

<br>
<br>

<h4>Example Commands</h4>

```bash
# get specific target's IPs and take web screenshots then view the images in terminal
shef -q org:tesla -f ip | sed 's/^/http:\/\//' | klik && yazi screenshots
```
[`klik`](https://github.com/1hehaq/hacks/blob/main/klik/main.go) [`yazi`](https://github.com/sxyazi/yazi)

<br>

```bash
# get related/own domains of the query, sometime it exposes internal portals (they shouldn't be same root domain)
shef -q hackerone.com -f domain # chain it with amass for getting more wide attack surfaces

# same for ports
shef -q hackerone.com -f port
```

<br>

```bash
# gets asn number(s) of the query then asn lookup with asnmap
asnmap -asn $(shef -q hackerone.com -f asn) # loop it if multiple asn numbers gets as shef's result
```
[`asnmap`](https://github.com/projectdiscovery/asnmap)

<br>

```bash
# gets relative domains and probe {title, IP, status code} then filter non 403 only (sometime, it shows real IPs, non WAF areas)
shef -q hackerone -f domain | httpx -sc -ip -title -silent | grep -vE '403|Cloudflare|Access Denied|Not Allowed'
```
[`httpx`](https://github.com/projectdiscovery/httpx)

<br>

```bash
# find known vulnerabilities of a product
shef -q "product:jboss" -f vuln
```

<br>
<br>

- **If you see no results or errors**
  - <sub> **verfiy your query** </sub>
  - <sub> **check your internet connection** </sub>
  - <sub> **use `-h` for guidance** </sub>

<br>
<br>

> [!CAUTION] 
> **never use `shef` for any illegal activites, I'm not responsible for your deeds with it. Do for justice.**

<br>
<br>
<br>

<h6 align="center">kindly for hackers</h6>

<div align="center">
  <a href="https://github.com/1hehaq"><img src="https://img.icons8.com/material-outlined/20/808080/github.png" alt="GitHub"></a>
  <a href="https://twitter.com/1hehaq"><img src="https://img.icons8.com/material-outlined/20/808080/twitter.png" alt="X"></a>
</div>
