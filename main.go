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
	"github.com/blang/semver"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/log"
	"github.com/corpix/uarand"
	"github.com/rhysd/go-github-selfupdate/selfupdate"
)

const version = "2.2.0"

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
	showVersion := flag.Bool("v", false, "show version")
	update := flag.Bool("up", false, "update to latest version")
	flag.Parse()

	if *showVersion {
		displayVersion()
		os.Exit(0)
	}

	if *update {
		performUpdate()
		os.Exit(0)
	}

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
	cmdStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("14"))
	argStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	flagStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("15"))
	requiredStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("9"))
	successStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("10"))
	
	fmt.Println()
	fmt.Println(successStyle.Render(" example:"))
	fmt.Printf("    %s -q %s -f %s\n", cmdStyle.Render("shef"), argStyle.Render("hackerone.com"), argStyle.Render("ports"))
	fmt.Printf("    %s -q %s -json\n\n", cmdStyle.Render("shef"), argStyle.Render("apache"))
	
	fmt.Println(successStyle.Render(" options:"))
	fmt.Printf("    %s      search query %s\n", flagStyle.Render("-q"), requiredStyle.Render("(required)"))
	fmt.Printf("    %s      facet type %s\n", flagStyle.Render("-f"), argStyle.Render("(default: ip)"))
	fmt.Printf("    %s   stdout as JSON format\n", flagStyle.Render("-json"))
	fmt.Printf("    %s   list all facets\n", flagStyle.Render("-list"))
	fmt.Printf("    %s      show version\n", flagStyle.Render("-v"))
	fmt.Printf("    %s     update to latest version\n", flagStyle.Render("-up"))
	fmt.Printf("    %s      show this help message\n\n", flagStyle.Render("-h"))
	
	fmt.Println(argStyle.Render("usage of shodan for attacking targets without prior mutual consent is illegal!"))
	fmt.Println()
}

func displayVersion() {
	highlightStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("14"))
	dimStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	
	fmt.Println()
	fmt.Printf("%s %s\n", highlightStyle.Render("shef"), dimStyle.Render("v"+version))
	fmt.Println()
}

func performUpdate() {
	highlightStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("14"))
	errorStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("9")).Bold(true)
	successStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("10")).Bold(true)
	dimStyle := lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
	
	fmt.Println()
	fmt.Println(highlightStyle.Render("checking for updates..."))
	
	latest, found, err := selfupdate.DetectLatest("1hehaq/shef")
	if err != nil {
		fmt.Printf("%s %s\n", errorStyle.Render("✗"), dimStyle.Render("error checking for updates: "+err.Error()))
		fmt.Println()
		os.Exit(1)
	}
	
	if !found {
		fmt.Printf("%s %s\n", errorStyle.Render("✗"), dimStyle.Render("no releases found"))
		fmt.Println()
		os.Exit(1)
	}
	
	currentVersion := "v" + version
	v, err := semver.ParseTolerant(strings.TrimPrefix(currentVersion, "v"))
	if err != nil {
		fmt.Printf("%s %s\n", errorStyle.Render("✗"), dimStyle.Render("invalid version format: "+err.Error()))
		fmt.Println()
		os.Exit(1)
	}
	
	if !latest.Version.GT(v) {
		fmt.Printf("%s %s\n", successStyle.Render("✓"), dimStyle.Render("already up to date ("+currentVersion+")"))
		fmt.Println()
		return
	}
	
	exe, err := os.Executable()
	if err != nil {
		fmt.Printf("%s %s\n", errorStyle.Render("✗"), dimStyle.Render("could not locate executable: "+err.Error()))
		fmt.Println()
		os.Exit(1)
	}
	
	fmt.Printf("  %s → %s\n", dimStyle.Render(currentVersion), highlightStyle.Render(latest.Version.String()))
	fmt.Println()
	fmt.Print(dimStyle.Render("  updating... "))
	
	if err := selfupdate.UpdateTo(latest.AssetURL, exe); err != nil {
		fmt.Printf("%s\n", errorStyle.Render("failed"))
		fmt.Printf("  %s\n", dimStyle.Render("error: "+err.Error()))
		fmt.Println()
		os.Exit(1)
	}
	
	fmt.Printf("%s\n", successStyle.Render("done"))
	fmt.Println()
	fmt.Println(dimStyle.Render("  restart shef to use the new version"))
	fmt.Println()
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
