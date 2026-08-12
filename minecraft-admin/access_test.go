package main

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestAccessVerifier(t *testing.T) {
	privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	keyID := "test-key"
	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.URL.Path != "/cdn-cgi/access/certs" {
			http.NotFound(writer, request)
			return
		}
		exponent := big.NewInt(int64(privateKey.PublicKey.E)).Bytes()
		_ = json.NewEncoder(writer).Encode(map[string]any{"keys": []map[string]string{{
			"kid": keyID,
			"kty": "RSA",
			"alg": "RS256",
			"n":   base64.RawURLEncoding.EncodeToString(privateKey.PublicKey.N.Bytes()),
			"e":   base64.RawURLEncoding.EncodeToString(exponent),
		}}})
	}))
	defer server.Close()

	now := time.Unix(2_000_000_000, 0)
	baseClaims := map[string]any{"iss": server.URL, "aud": []string{"admin-audience"}, "exp": now.Add(time.Hour).Unix(), "email": "Admin@Example.com"}
	tests := []struct {
		name    string
		claims  map[string]any
		wantErr bool
	}{
		{name: "valid", claims: cloneClaims(baseClaims)},
		{name: "expired", claims: withClaim(baseClaims, "exp", now.Add(-time.Minute).Unix()), wantErr: true},
		{name: "issuer", claims: withClaim(baseClaims, "iss", "https://wrong.example.com"), wantErr: true},
		{name: "audience", claims: withClaim(baseClaims, "aud", []string{"wrong"}), wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			verifier := newAccessVerifier(server.URL, "admin-audience", server.Client())
			verifier.now = func() time.Time { return now }
			token := signTestJWT(t, privateKey, keyID, test.claims)
			email, err := verifier.verify(context.Background(), token)
			if (err != nil) != test.wantErr {
				t.Fatalf("verify() error = %v, wantErr %v", err, test.wantErr)
			}
			if !test.wantErr && email != "admin@example.com" {
				t.Fatalf("email = %q", email)
			}
		})
	}
}

func signTestJWT(t *testing.T, key *rsa.PrivateKey, keyID string, claims map[string]any) string {
	t.Helper()
	header, _ := json.Marshal(map[string]string{"alg": "RS256", "kid": keyID, "typ": "JWT"})
	payload, _ := json.Marshal(claims)
	unsigned := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	digest := sha256.Sum256([]byte(unsigned))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return unsigned + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func cloneClaims(source map[string]any) map[string]any {
	result := make(map[string]any, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}

func withClaim(source map[string]any, key string, value any) map[string]any {
	result := cloneClaims(source)
	result[key] = value
	return result
}
