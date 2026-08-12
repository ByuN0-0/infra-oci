package main

import (
	"fmt"
	"os"
	"strings"
	"time"
)

type config struct {
	ListenAddress    string
	AccessIssuer     string
	AccessAudience   string
	RCONAddress      string
	RCONPasswordFile string
	WhitelistFile    string
	OpsFile          string
	AuditFile        string
	RequestTimeout   time.Duration
}

func loadConfig() (config, error) {
	teamDomain := strings.TrimSpace(os.Getenv("CLOUDFLARE_ACCESS_TEAM_DOMAIN"))
	if teamDomain == "" {
		return config{}, fmt.Errorf("CLOUDFLARE_ACCESS_TEAM_DOMAIN is required")
	}
	if !strings.HasPrefix(teamDomain, "https://") {
		teamDomain = "https://" + teamDomain
	}
	teamDomain = strings.TrimRight(teamDomain, "/")

	audience := strings.TrimSpace(os.Getenv("CLOUDFLARE_ACCESS_AUDIENCE"))
	if audience == "" {
		return config{}, fmt.Errorf("CLOUDFLARE_ACCESS_AUDIENCE is required")
	}

	return config{
		ListenAddress:    envOr("LISTEN_ADDRESS", "127.0.0.1:8081"),
		AccessIssuer:     teamDomain,
		AccessAudience:   audience,
		RCONAddress:      envOr("RCON_ADDRESS", "127.0.0.1:25575"),
		RCONPasswordFile: envOr("RCON_PASSWORD_FILE", "/run/secrets/rcon-password"),
		WhitelistFile:    envOr("WHITELIST_FILE", "/minecraft-data/whitelist.json"),
		OpsFile:          envOr("OPS_FILE", "/minecraft-data/ops.json"),
		AuditFile:        envOr("AUDIT_FILE", "/audit/audit.jsonl"),
		RequestTimeout:   5 * time.Second,
	}, nil
}

func envOr(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}
