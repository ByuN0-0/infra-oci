package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

type auditEvent struct {
	Time     time.Time `json:"time"`
	Actor    string    `json:"actor"`
	Action   string    `json:"action"`
	Target   string    `json:"target"`
	Success  bool      `json:"success"`
	Response string    `json:"rcon_response"`
}

type auditLogger struct {
	path string
	now  func() time.Time
	mu   sync.Mutex
}

var sensitiveAuditValue = regexp.MustCompile(`(?i)(token|password|secret)(\s*[=:]\s*)[^\s,;]+`)

func (logger *auditLogger) record(event auditEvent) error {
	logger.mu.Lock()
	defer logger.mu.Unlock()
	if event.Time.IsZero() {
		event.Time = logger.now().UTC()
	}
	event.Response = summarizeRCON(event.Response)
	encoded, err := json.Marshal(event)
	if err != nil {
		return err
	}
	file, err := os.OpenFile(logger.path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return fmt.Errorf("open audit log: %w", err)
	}
	defer file.Close()
	if _, err := file.Write(append(encoded, '\n')); err != nil {
		return fmt.Errorf("write audit log: %w", err)
	}
	if err := file.Sync(); err != nil {
		return fmt.Errorf("sync audit log: %w", err)
	}
	return nil
}

func (logger *auditLogger) recent(limit int) ([]auditEvent, error) {
	logger.mu.Lock()
	defer logger.mu.Unlock()
	file, err := os.Open(logger.path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	if limit < 1 {
		return nil, nil
	}
	events := make([]auditEvent, 0, limit)
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), 1<<20)
	for scanner.Scan() {
		var event auditEvent
		if json.Unmarshal(scanner.Bytes(), &event) != nil {
			continue
		}
		if len(events) == limit {
			copy(events, events[1:])
			events[len(events)-1] = event
		} else {
			events = append(events, event)
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read audit log: %w", err)
	}
	for left, right := 0, len(events)-1; left < right; left, right = left+1, right-1 {
		events[left], events[right] = events[right], events[left]
	}
	return events, nil
}

func summarizeRCON(value string) string {
	value = strings.Map(func(character rune) rune {
		if character < 0x20 && character != '\t' {
			return ' '
		}
		return character
	}, value)
	value = strings.Join(strings.Fields(value), " ")
	value = sensitiveAuditValue.ReplaceAllString(value, "$1$2[REDACTED]")
	const limit = 300
	if len(value) > limit {
		value = value[:limit] + "…"
	}
	return value
}
