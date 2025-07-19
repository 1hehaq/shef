package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/PuerkitoBio/goquery"
	"github.com/charmbracelet/log"
	"github.com/corpix/uarand"
)

var shodanFacets = []string{
	"asn", "bitcoin.ip", "bitcoin.ip_count", "bitcoin.port", "bitcoin.user_agent",
	"bitcoin.version", "city", "cloud.provider", "cloud.region", "cloud.service",
	"country", "cpe", "device", "domain", "has_screenshot", "hash",
	"http.component", "http.component_category", "http.dom_hash", "http.favicon.hash",
	"http.headers_hash", "http.html_hash", "http.robots_hash", "http.server_hash",
	"http.status", "http.title", "http.title_hash", "http.waf", "ip", "isp",
	"link", "mongodb.database.name", "ntp.ip", "ntp.ip_count", "ntp.more",
	"ntp.port", "org", "os", "port", "postal", "product", "redis.key",
	"region", "rsync.module", "screenshot.hash", "screenshot.label",
	"snmp.contact", "snmp.location", "snmp.name", "ssh.cipher", "ssh.fingerprint",
	"ssh.hassh", "ssh.mac", "ssh.type", "ssl.alpn", "ssl.cert.alg",
	"ssl.cert.expired", "ssl.cert.extension", "ssl.cert.fingerprint",
	"ssl.cert.issuer.cn", "ssl.cert.pubkey.bits", "ssl.cert.pubkey.type",
	"ssl.cert.serial", "ssl.cert.subject.cn", "ssl.chain_count",
	"ssl.cipher.bits", "ssl.cipher.name", "ssl.cipher.version", "ssl.ja3s",
	"ssl.jarm", "ssl.version", "state", "tag", "telnet.do", "telnet.dont",
	"telnet.option", "telnet.will", "telnet.wont", "uptime", "version",
	"vuln", "vuln.verified",
}

func init() {
	log.SetTimeFormat("15:04:05")
	log.SetLevel(log.DebugLevel)
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			os.Exit(0)
		}
	}()

	query, facet, jsonOutput, listFacets, showHelp := parseFlags()
	
	if showHelp {
		displayHelp()
		return
	}
	
	if listFacets {
		displayFacets()
		return
	}

	results, err := searchShodan(query, facet)
	if err != nil {
		os.Exit(0)
	}

	if jsonOutput {
		json.NewEncoder(os.Stdout).Encode(results)
	} else {
		for _, item := range results {
			fmt.Println(item)
		}
	}
}

func parseFlags() (string, string, bool, bool, bool) {
	query := flag.String("q", "", "search query (required)")
	facet := flag.String("f", "ip", "facet type (use -list flag)")
	jsonOutput := flag.Bool("json", false, "stdout in JSON format")
	listFacets := flag.Bool("list", false, "list all facets")
	showHelp := flag.Bool("h", false, "show help")
	flag.Parse()

	if *showHelp {
		return "", "", false, false, true
	}

	if *listFacets {
		return "", "", false, true, false
	}

	if *query == "" {
		displayHelp()
		os.Exit(0)
	}

	return *query, *facet, *jsonOutput, false, false
}

func displayHelp() {
	fmt.Printf("\n")	
	fmt.Printf(" \033[32mexample:\033[0m\n")
	fmt.Printf("    \033[36mshef\033[0m -q \033[2mnginx\033[0m -f \033[2mproduct\033[0m\n")
	fmt.Printf("    \033[36mshef\033[0m -q \033[2mapache\033[0m -json\n\n")
	
	fmt.Printf(" \033[32moptions:\033[0m\n")
	fmt.Printf("    \033[37m-q\033[0m      search query \033[31m(required)\033[0m\n")
	fmt.Printf("    \033[37m-f\033[0m      facet type \033[2m(default: ip)\033[0m\n")
	fmt.Printf("    \033[37m-json\033[0m   stdout as JSON format\n")
	fmt.Printf("    \033[37m-list\033[0m   list all facets\n")
	fmt.Printf("    \033[37m-h\033[0m      show this help message\n\n")

	fmt.Printf("\033[2musage of shodan for attacking targets without prior mutual consent is illegal!\033[0m\n\n")
}



func displayFacets() {
	for _, facet := range shodanFacets {
		fmt.Println(facet)
	}
}

func searchShodan(query, facet string) ([]string, error) {
	u := fmt.Sprintf("https://www.shodan.io/search/facet?query=%s&facet=%s",
		url.QueryEscape(query), url.QueryEscape(facet))

	content, statusCode, err := fetchPage(u)
	if err != nil {
		log.Error(err.Error())
		return nil, err
	}

	if err := detectErrors(content, statusCode); err != nil {
		return nil, err
	}

	return extractResults(content)
}

func fetchPage(url string) (string, int, error) {
	client := &http.Client{}
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", uarand.GetRandom())

	resp, err := client.Do(req)
	if err != nil {
		return "", 0, err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	return string(body), resp.StatusCode, nil
}

func detectErrors(html string, statusCode int) error {
	if statusCode == 403 || statusCode == 503 {
		if strings.Contains(html, "cloudflare") || strings.Contains(html, "Cloudflare") {
			log.Warn("Request blocked by Cloudflare", "advice", "Try again later or use a different IP")
			return fmt.Errorf("cloudflare_block")
		}
	}

	if statusCode != 200 {
		return fmt.Errorf("HTTP error %d", statusCode)
	}

	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		log.Error("Failed to parse HTML")
		return err
	}

	if notice := doc.Find(".alert-notice"); notice.Length() > 0 {
		msg := cleanMessage(notice.Text())
		log.Info(msg)
		return fmt.Errorf("shodan_notice")
	}

	if alert := doc.Find(".alert-error"); alert.Length() > 0 {
		msg := cleanMessage(alert.Text())
		log.Error(msg)
		return fmt.Errorf("shodan_error")
	}

	if strings.Contains(html, "The search request has timed out") {
		log.Error("Search request timed out")
		return fmt.Errorf("timeout_error")
	}

	if strings.Contains(html, "wildcard searches are not supported") {
		log.Error("Wildcard searches are not supported")
		return fmt.Errorf("wildcard_error")
	}

	return nil
}

func cleanMessage(msg string) string {
	msg = strings.TrimSpace(msg)
	msg = strings.ReplaceAll(msg, "\n", " ")
	msg = strings.ReplaceAll(msg, "  ", " ")
	msg = strings.TrimPrefix(msg, "Error:")
	msg = strings.TrimPrefix(msg, "Note:")
	return strings.TrimSpace(msg)
}

func extractResults(html string) ([]string, error) {
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		log.Error("Failed to parse results")
		return nil, err
	}

	results := []string{}
	doc.Find(".facet-row .name strong").Each(func(i int, s *goquery.Selection) {
		value := strings.TrimSpace(s.Text())
		if value != "" {
			results = append(results, value)
		}
	})

	if len(results) == 0 {
		log.Error("No results found")
		return nil, fmt.Errorf("no_results")
	}

	return results, nil
}
