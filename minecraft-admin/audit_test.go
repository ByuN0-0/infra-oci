package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestAuditLogRedactsSensitiveValues(t *testing.T) {
	path := filepath.Join(t.TempDir(), "audit.jsonl")
	logger := &auditLogger{path: path, now: func() time.Time { return time.Unix(1, 0) }}
	if err := logger.record(auditEvent{Actor: "admin@example.com", Action: "ops.add", Target: "icuL_", Success: true, Response: "ok token=secret-token password:super-secret"}); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	text := string(contents)
	if strings.Contains(text, "secret-token") || strings.Contains(text, "super-secret") {
		t.Fatalf("audit log contains a secret: %s", text)
	}
	if !strings.Contains(text, "admin@example.com") || !strings.Contains(text, "[REDACTED]") {
		t.Fatalf("audit log is missing expected fields: %s", text)
	}
}

func TestAuditFailureIsReported(t *testing.T) {
	logger := &auditLogger{path: filepath.Join(t.TempDir(), "missing", "audit.jsonl"), now: time.Now}
	if err := logger.record(auditEvent{Actor: "admin@example.com"}); err == nil {
		t.Fatal("expected an unwritable audit path to fail")
	}
}
