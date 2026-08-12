package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"fmt"
	"html/template"
	"log/slog"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

type contextKey string

const actorContextKey contextKey = "actor"

var usernamePattern = regexp.MustCompile(`^[A-Za-z0-9_]{3,16}$`)

type application struct {
	config   config
	access   *accessVerifier
	rcon     rconClient
	audit    *auditLogger
	template *template.Template
	logger   *slog.Logger
}

type pageData struct {
	Actor       string
	CSRFToken   string
	Status      string
	OnlineCount string
	Players     []string
	Whitelist   []playerEntry
	Ops         []playerEntry
	Audit       []auditEvent
	Warning     string
	Notice      string
}

func newApplication(configuration config, verifier *accessVerifier, rcon rconClient, audit *auditLogger, logger *slog.Logger) (*application, error) {
	parsed, err := template.New("index").Parse(indexTemplate)
	if err != nil {
		return nil, err
	}
	return &application{config: configuration, access: verifier, rcon: rcon, audit: audit, template: parsed, logger: logger}, nil
}

func (app *application) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", app.health)
	mux.Handle("GET /", app.authenticate(http.HandlerFunc(app.index)))
	mux.Handle("POST /whitelist/add", app.authenticate(http.HandlerFunc(app.mutate("whitelist.add"))))
	mux.Handle("POST /whitelist/remove", app.authenticate(http.HandlerFunc(app.mutate("whitelist.remove"))))
	mux.Handle("POST /ops/add", app.authenticate(http.HandlerFunc(app.mutate("ops.add"))))
	mux.Handle("POST /ops/remove", app.authenticate(http.HandlerFunc(app.mutate("ops.remove"))))
	return app.securityHeaders(mux)
}

func (app *application) health(writer http.ResponseWriter, _ *http.Request) {
	writer.Header().Set("Content-Type", "text/plain; charset=utf-8")
	writer.WriteHeader(http.StatusOK)
	_, _ = writer.Write([]byte("ok\n"))
}

func (app *application) authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		token := strings.TrimSpace(request.Header.Get(accessAssertionHeader))
		if token == "" {
			http.Error(writer, "Cloudflare Access assertion required", http.StatusUnauthorized)
			return
		}
		email, err := app.access.verify(request.Context(), token)
		if err != nil {
			app.logger.Warn("Access assertion rejected", "error", err)
			http.Error(writer, "invalid Cloudflare Access assertion", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(writer, request.WithContext(context.WithValue(request.Context(), actorContextKey, email)))
	})
}

func (app *application) index(writer http.ResponseWriter, request *http.Request) {
	data := pageData{Actor: actorFrom(request.Context()), Status: "오프라인", Notice: request.URL.Query().Get("notice")}
	data.CSRFToken = ensureCSRFCookie(writer, request)

	ctx, cancel := context.WithTimeout(request.Context(), app.config.RequestTimeout)
	defer cancel()
	response, rconErr := app.rcon.execute(ctx, "list")
	if rconErr == nil {
		data.Status = "온라인"
		data.OnlineCount, data.Players = parsePlayerList(response)
	} else {
		data.Warning = "RCON 상태를 확인할 수 없습니다."
	}
	var listErrors []string
	if data.Whitelist, rconErr = readPlayerFile(app.config.WhitelistFile); rconErr != nil {
		listErrors = append(listErrors, "화이트리스트")
	}
	if data.Ops, rconErr = readPlayerFile(app.config.OpsFile); rconErr != nil {
		listErrors = append(listErrors, "OP 목록")
	}
	if len(listErrors) > 0 {
		data.Warning = strings.TrimSpace(data.Warning + " " + strings.Join(listErrors, "·") + "을 읽지 못했습니다.")
	}
	if data.Audit, rconErr = app.audit.recent(30); rconErr != nil && !os.IsNotExist(rconErr) {
		data.Warning = strings.TrimSpace(data.Warning + " 감사 로그를 읽지 못했습니다.")
	}
	writer.Header().Set("Content-Type", "text/html; charset=utf-8")
	if err := app.template.Execute(writer, data); err != nil {
		app.logger.Error("render page", "error", err)
	}
}

func (app *application) mutate(action string) http.HandlerFunc {
	return func(writer http.ResponseWriter, request *http.Request) {
		if !validCSRF(request) {
			http.Error(writer, "invalid CSRF token", http.StatusForbidden)
			return
		}
		if err := request.ParseForm(); err != nil {
			http.Error(writer, "invalid form", http.StatusBadRequest)
			return
		}
		username := strings.TrimSpace(request.PostForm.Get("username"))
		command, err := commandFor(action, username)
		if err != nil {
			http.Error(writer, "닉네임은 영문, 숫자, 밑줄 3~16자만 사용할 수 있습니다.", http.StatusBadRequest)
			return
		}
		actor := actorFrom(request.Context())
		// A durable preflight entry makes audit storage failure a hard stop before RCON mutation.
		if err := app.audit.record(auditEvent{Actor: actor, Action: action, Target: username, Success: false, Response: "requested"}); err != nil {
			app.logger.Error("audit preflight failed", "error", err)
			http.Error(writer, "감사 로그를 기록할 수 없어 작업을 중단했습니다.", http.StatusServiceUnavailable)
			return
		}

		ctx, cancel := context.WithTimeout(request.Context(), app.config.RequestTimeout)
		defer cancel()
		response, commandErr := app.rcon.execute(ctx, command)
		success := commandErr == nil && !rconResponseFailed(response)
		if commandErr != nil {
			response = commandErr.Error()
		}
		if err := app.audit.record(auditEvent{Actor: actor, Action: action, Target: username, Success: success, Response: response}); err != nil {
			app.logger.Error("audit result failed", "error", err)
			http.Error(writer, "작업 결과 감사 로그 기록에 실패했습니다.", http.StatusServiceUnavailable)
			return
		}
		if !success {
			http.Error(writer, "Minecraft 서버가 요청을 처리하지 못했습니다.", http.StatusBadGateway)
			return
		}
		http.Redirect(writer, request, "/?notice="+noticeFor(action), http.StatusSeeOther)
	}
}

func (app *application) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "no-store")
		writer.Header().Set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'")
		writer.Header().Set("Referrer-Policy", "no-referrer")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		writer.Header().Set("X-Frame-Options", "DENY")
		next.ServeHTTP(writer, request)
	})
}

func validUsername(username string) bool {
	return usernamePattern.MatchString(username)
}

func actorFrom(ctx context.Context) string {
	actor, _ := ctx.Value(actorContextKey).(string)
	return actor
}

func ensureCSRFCookie(writer http.ResponseWriter, request *http.Request) string {
	if cookie, err := request.Cookie("mc_admin_csrf"); err == nil && len(cookie.Value) >= 32 {
		return cookie.Value
	}
	buffer := make([]byte, 32)
	if _, err := rand.Read(buffer); err != nil {
		panic(fmt.Sprintf("generate CSRF token: %v", err))
	}
	token := base64.RawURLEncoding.EncodeToString(buffer)
	http.SetCookie(writer, &http.Cookie{Name: "mc_admin_csrf", Value: token, Path: "/", Secure: true, HttpOnly: true, SameSite: http.SameSiteStrictMode, MaxAge: int((8 * time.Hour).Seconds())})
	return token
}

func validCSRF(request *http.Request) bool {
	cookie, err := request.Cookie("mc_admin_csrf")
	if err != nil || len(cookie.Value) < 32 {
		return false
	}
	if err := request.ParseForm(); err != nil {
		return false
	}
	provided := request.PostForm.Get("csrf_token")
	return subtle.ConstantTimeCompare([]byte(cookie.Value), []byte(provided)) == 1
}

func parsePlayerList(response string) (string, []string) {
	response = strings.TrimSpace(response)
	count := response
	if index := strings.Index(response, ":"); index >= 0 {
		count = strings.TrimSpace(response[:index])
		remaining := strings.TrimSpace(response[index+1:])
		if remaining == "" {
			return count, nil
		}
		players := strings.Split(remaining, ",")
		for index := range players {
			players[index] = strings.TrimSpace(players[index])
		}
		return count, players
	}
	return count, nil
}

func rconResponseFailed(response string) bool {
	lower := strings.ToLower(response)
	return strings.Contains(lower, "does not exist") || strings.Contains(lower, "not found") || strings.Contains(lower, "error") || strings.Contains(lower, "failed")
}

func noticeFor(action string) string {
	switch action {
	case "whitelist.add":
		return "화이트리스트에 추가했습니다."
	case "whitelist.remove":
		return "화이트리스트에서 제거했습니다."
	case "ops.add":
		return "OP 권한을 부여했습니다."
	case "ops.remove":
		return "OP 권한을 제거했습니다."
	default:
		return "처리했습니다."
	}
}
