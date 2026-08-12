package main

const indexTemplate = `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Minecraft Admin</title>
  <style>
    :root { color-scheme: dark; --bg:#0d1117; --panel:#161b22; --line:#30363d; --text:#f0f6fc; --muted:#8b949e; --green:#3fb950; --red:#f85149; --blue:#58a6ff; }
    * { box-sizing:border-box; }
    body { margin:0; background:var(--bg); color:var(--text); font:15px/1.5 system-ui,-apple-system,sans-serif; }
    main { width:min(1080px,calc(100% - 32px)); margin:40px auto 80px; }
    header { display:flex; align-items:flex-end; justify-content:space-between; gap:20px; margin-bottom:24px; }
    h1,h2 { margin:0; } h1 { font-size:28px; } h2 { font-size:18px; margin-bottom:16px; }
    .muted { color:var(--muted); } .status { color:var(--green); font-weight:700; }
    .grid { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:16px; }
    .panel { background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:20px; }
    .wide { grid-column:1/-1; }
    .notice,.warning { border-radius:8px; padding:12px 14px; margin-bottom:16px; }
    .notice { background:#12261a; color:#7ee787; } .warning { background:#321c1d; color:#ff7b72; }
    ul { padding-left:20px; margin:10px 0 0; } .empty { color:var(--muted); }
    form { display:flex; gap:8px; margin-top:16px; }
    input { min-width:0; flex:1; padding:10px 12px; border:1px solid var(--line); border-radius:7px; background:var(--bg); color:var(--text); }
    button { border:0; border-radius:7px; padding:10px 14px; background:var(--blue); color:#07111f; font-weight:700; cursor:pointer; }
    button.danger { background:var(--red); color:white; }
    table { width:100%; border-collapse:collapse; } th,td { text-align:left; border-bottom:1px solid var(--line); padding:10px 6px; }
    td form { margin:0; justify-content:flex-end; } td button { padding:7px 10px; }
    @media (max-width:720px) { .grid { grid-template-columns:1fr; } header { align-items:flex-start; flex-direction:column; } }
  </style>
</head>
<body><main>
  <header><div><h1>Craft to Exile 2</h1><div class="muted">Minecraft 관리 페이지</div></div><div class="muted">{{.Actor}}</div></header>
  {{if .Notice}}<div class="notice">{{.Notice}}</div>{{end}}
  {{if .Warning}}<div class="warning">{{.Warning}}</div>{{end}}
  <section class="grid">
    <article class="panel"><h2>서버 상태</h2><div class="status">● {{.Status}}</div>{{if .OnlineCount}}<p>{{.OnlineCount}}</p>{{end}}</article>
    <article class="panel"><h2>접속자</h2>{{if .Players}}<ul>{{range .Players}}<li>{{.}}</li>{{end}}</ul>{{else}}<div class="empty">현재 접속자가 없습니다.</div>{{end}}</article>
    <article class="panel">
      <h2>화이트리스트</h2>
      {{if .Whitelist}}<table><tbody>{{range .Whitelist}}<tr><td>{{.Name}}</td><td><form method="post" action="/whitelist/remove"><input type="hidden" name="csrf_token" value="{{$.CSRFToken}}"><input type="hidden" name="username" value="{{.Name}}"><button class="danger" type="submit">제거</button></form></td></tr>{{end}}</tbody></table>{{else}}<div class="empty">등록된 계정이 없습니다.</div>{{end}}
      <form method="post" action="/whitelist/add"><input type="hidden" name="csrf_token" value="{{.CSRFToken}}"><input name="username" pattern="[A-Za-z0-9_]{3,16}" maxlength="16" placeholder="Minecraft 닉네임" required><button type="submit">추가</button></form>
    </article>
    <article class="panel">
      <h2>OP</h2>
      {{if .Ops}}<table><tbody>{{range .Ops}}<tr><td>{{.Name}} <span class="muted">Lv.{{.Level}}</span></td><td><form method="post" action="/ops/remove"><input type="hidden" name="csrf_token" value="{{$.CSRFToken}}"><input type="hidden" name="username" value="{{.Name}}"><button class="danger" type="submit">권한 제거</button></form></td></tr>{{end}}</tbody></table>{{else}}<div class="empty">등록된 OP가 없습니다.</div>{{end}}
      <form method="post" action="/ops/add"><input type="hidden" name="csrf_token" value="{{.CSRFToken}}"><input name="username" pattern="[A-Za-z0-9_]{3,16}" maxlength="16" placeholder="Minecraft 닉네임" required><button type="submit">OP 부여</button></form>
    </article>
    <article class="panel wide">
      <h2>최근 감사 로그</h2>
      {{if .Audit}}<table><thead><tr><th>시간</th><th>관리자</th><th>작업</th><th>대상</th><th>결과</th></tr></thead><tbody>{{range .Audit}}<tr><td>{{.Time}}</td><td>{{.Actor}}</td><td>{{.Action}}</td><td>{{.Target}}</td><td>{{if .Success}}성공{{else}}요청/실패{{end}}</td></tr>{{end}}</tbody></table>{{else}}<div class="empty">기록된 관리 작업이 없습니다.</div>{{end}}
    </article>
  </section>
</main></body></html>`
