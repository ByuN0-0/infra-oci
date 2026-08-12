package main

import (
	"context"
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"
)

const accessAssertionHeader = "Cf-Access-Jwt-Assertion"

type accessClaims struct {
	Issuer   string          `json:"iss"`
	Audience json.RawMessage `json:"aud"`
	Expires  int64           `json:"exp"`
	Email    string          `json:"email"`
}

type accessVerifier struct {
	issuer   string
	audience string
	jwksURL  string
	client   *http.Client
	now      func() time.Time

	mu        sync.RWMutex
	keys      map[string]*rsa.PublicKey
	cacheTime time.Time
}

type jwksDocument struct {
	Keys []struct {
		KeyID     string `json:"kid"`
		KeyType   string `json:"kty"`
		Algorithm string `json:"alg"`
		Modulus   string `json:"n"`
		Exponent  string `json:"e"`
	} `json:"keys"`
}

func newAccessVerifier(issuer, audience string, client *http.Client) *accessVerifier {
	issuer = strings.TrimRight(issuer, "/")
	if client == nil {
		client = &http.Client{Timeout: 5 * time.Second}
	}
	return &accessVerifier{
		issuer:   issuer,
		audience: audience,
		jwksURL:  issuer + "/cdn-cgi/access/certs",
		client:   client,
		now:      time.Now,
		keys:     make(map[string]*rsa.PublicKey),
	}
}

func (v *accessVerifier) verify(ctx context.Context, token string) (string, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", errors.New("invalid JWT format")
	}

	var header struct {
		Algorithm string `json:"alg"`
		KeyID     string `json:"kid"`
	}
	if err := decodeJWTPart(parts[0], &header); err != nil {
		return "", fmt.Errorf("decode JWT header: %w", err)
	}
	if header.Algorithm != "RS256" || header.KeyID == "" {
		return "", errors.New("JWT must use RS256 with a key ID")
	}

	key, err := v.key(ctx, header.KeyID, false)
	if err != nil {
		key, err = v.key(ctx, header.KeyID, true)
		if err != nil {
			return "", err
		}
	}

	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return "", errors.New("invalid JWT signature encoding")
	}
	digest := sha256.Sum256([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(key, crypto.SHA256, digest[:], signature); err != nil {
		return "", errors.New("invalid JWT signature")
	}

	var claims accessClaims
	if err := decodeJWTPart(parts[1], &claims); err != nil {
		return "", fmt.Errorf("decode JWT claims: %w", err)
	}
	if subtle.ConstantTimeCompare([]byte(strings.TrimRight(claims.Issuer, "/")), []byte(v.issuer)) != 1 {
		return "", errors.New("invalid JWT issuer")
	}
	if !audienceContains(claims.Audience, v.audience) {
		return "", errors.New("invalid JWT audience")
	}
	if claims.Expires <= v.now().Unix() {
		return "", errors.New("expired JWT")
	}
	email := strings.ToLower(strings.TrimSpace(claims.Email))
	if email == "" || len(email) > 254 {
		return "", errors.New("JWT email is missing")
	}
	return email, nil
}

func decodeJWTPart(part string, destination any) error {
	decoded, err := base64.RawURLEncoding.DecodeString(part)
	if err != nil {
		return err
	}
	return json.Unmarshal(decoded, destination)
}

func audienceContains(raw json.RawMessage, expected string) bool {
	var single string
	if json.Unmarshal(raw, &single) == nil {
		return subtle.ConstantTimeCompare([]byte(single), []byte(expected)) == 1
	}
	var multiple []string
	if json.Unmarshal(raw, &multiple) != nil {
		return false
	}
	for _, audience := range multiple {
		if subtle.ConstantTimeCompare([]byte(audience), []byte(expected)) == 1 {
			return true
		}
	}
	return false
}

func (v *accessVerifier) key(ctx context.Context, keyID string, force bool) (*rsa.PublicKey, error) {
	v.mu.RLock()
	key := v.keys[keyID]
	fresh := v.now().Sub(v.cacheTime) < time.Hour
	v.mu.RUnlock()
	if key != nil && fresh && !force {
		return key, nil
	}
	if err := v.refresh(ctx); err != nil {
		return nil, err
	}
	v.mu.RLock()
	defer v.mu.RUnlock()
	key = v.keys[keyID]
	if key == nil {
		return nil, errors.New("JWT signing key not found")
	}
	return key, nil
}

func (v *accessVerifier) refresh(ctx context.Context) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, v.jwksURL, nil)
	if err != nil {
		return err
	}
	response, err := v.client.Do(request)
	if err != nil {
		return fmt.Errorf("fetch Access JWKS: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return fmt.Errorf("fetch Access JWKS: HTTP %d", response.StatusCode)
	}
	var document jwksDocument
	if err := json.NewDecoder(io.LimitReader(response.Body, 1<<20)).Decode(&document); err != nil {
		return fmt.Errorf("decode Access JWKS: %w", err)
	}
	keys := make(map[string]*rsa.PublicKey)
	for _, item := range document.Keys {
		if item.KeyType != "RSA" || item.KeyID == "" || (item.Algorithm != "" && item.Algorithm != "RS256") {
			continue
		}
		modulus, err := base64.RawURLEncoding.DecodeString(item.Modulus)
		if err != nil {
			continue
		}
		exponentBytes, err := base64.RawURLEncoding.DecodeString(item.Exponent)
		if err != nil || len(exponentBytes) == 0 || len(exponentBytes) > 4 {
			continue
		}
		exponent := 0
		for _, current := range exponentBytes {
			exponent = exponent<<8 | int(current)
		}
		if exponent < 3 {
			continue
		}
		keys[item.KeyID] = &rsa.PublicKey{N: new(big.Int).SetBytes(modulus), E: exponent}
	}
	if len(keys) == 0 {
		return errors.New("Access JWKS contained no usable RSA keys")
	}
	v.mu.Lock()
	v.keys = keys
	v.cacheTime = v.now()
	v.mu.Unlock()
	return nil
}
