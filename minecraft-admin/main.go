package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	configuration, err := loadConfig()
	if err != nil {
		logger.Error("load configuration", "error", err)
		os.Exit(1)
	}
	verifier := newAccessVerifier(configuration.AccessIssuer, configuration.AccessAudience, nil)
	rcon := &minecraftRCON{address: configuration.RCONAddress, passwordFile: configuration.RCONPasswordFile, timeout: configuration.RequestTimeout}
	audit := &auditLogger{path: configuration.AuditFile, now: time.Now}
	app, err := newApplication(configuration, verifier, rcon, audit, logger)
	if err != nil {
		logger.Error("initialize application", "error", err)
		os.Exit(1)
	}
	server := &http.Server{
		Addr:              configuration.ListenAddress,
		Handler:           app.routes(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	logger.Info("Minecraft admin listening", "address", configuration.ListenAddress)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error("serve HTTP", "error", err)
		os.Exit(1)
	}
}
