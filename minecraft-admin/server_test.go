package main

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestCommandFor(t *testing.T) {
	tests := []struct {
		action   string
		username string
		want     string
		wantErr  bool
	}{
		{action: "whitelist.add", username: "icuL_", want: "whitelist add icuL_"},
		{action: "whitelist.remove", username: "Player123", want: "whitelist remove Player123"},
		{action: "ops.add", username: "Player_2", want: "op Player_2"},
		{action: "ops.remove", username: "Player_2", want: "deop Player_2"},
		{action: "ops.add", username: "a", wantErr: true},
		{action: "ops.add", username: "bad name", wantErr: true},
		{action: "console", username: "Player", wantErr: true},
	}
	for _, test := range tests {
		got, err := commandFor(test.action, test.username)
		if (err != nil) != test.wantErr || got != test.want {
			t.Fatalf("commandFor(%q, %q) = %q, %v", test.action, test.username, got, err)
		}
	}
}

func TestCSRF(t *testing.T) {
	form := url.Values{"csrf_token": {"valid-token-value-that-is-long-enough"}}
	request := httptest.NewRequest("POST", "/ops/add", strings.NewReader(form.Encode()))
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	request.AddCookie(&http.Cookie{Name: "mc_admin_csrf", Value: "valid-token-value-that-is-long-enough", Path: "/"})
	if !validCSRF(request) {
		t.Fatal("valid CSRF token was rejected")
	}

	badRequest := httptest.NewRequest("POST", "/ops/add", strings.NewReader("csrf_token=wrong-token-value-that-is-long-enough"))
	badRequest.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	badRequest.AddCookie(&http.Cookie{Name: "mc_admin_csrf", Value: "valid-token-value-that-is-long-enough", Path: "/"})
	if validCSRF(badRequest) {
		t.Fatal("invalid CSRF token was accepted")
	}
}
