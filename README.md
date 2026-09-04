# 🌐 Daytona + OpenClaw: Public Dashboard URL Guide

> **Make ANY sandbox's OpenClaw control UI reachable from your browser — even when sandbox egress is locked down to port 443 with SNI allowlist.**

Idiot-proof, copy-paste guide. Tested on Daytona sandbox `be9bd11a-16b5-4286-8b06-161c0855e40f` (gw-big). Works on any Daytona-managed environment where OpenClaw is installed.

---

## 🎯 What this solves

You want to open `http://<sandbox>:18789/` in your browser, but:

- ❌ Sandbox has no public IP
- ❌ Port 18789 is not exposed
- ❌ Egress from sandbox is restricted to port 443 with SNI allowlist
- ❌ Direct `curl https://<sandbox>:18789/` fails (HTTP 000 = blocked)

**This guide turns**: `http://localhost:18789` → `https://<random>.daytonaproxy01.net` (publicly reachable, browser-friendly).

---

## 🧠 The mental model (10-second version)

```
[your browser]  →  [daytonaproxy01.net]  →  [sandbox gateway :18789]
                     (Daytona reverse proxy)    (OpenClaw Control UI)
```

Daytona already runs a public-facing reverse proxy that tunnels to your sandbox's port 18789. You just need to:

1. Discover the proxy URL Daytona gave your sandbox
2. Whitelist it in `openclaw.json` (allowedOrigins)
3. Reload the gateway
4. Approve the device pairing (one-time, browser-side)

**Total time: 5 minutes once you know the steps.**

---

## 📋 Step-by-step

| # | Action | Tool |
|---|--------|------|
| 0 | Check you're on the **sandbox host** (where OpenClaw runs) | shell |
| 1 | Find your proxy URL | `cat` config or check sandbox labels |
| 2 | Backup + edit `openclaw.json` | `python3` script |
| 3 | Reload gateway (no restart) | `kill -USR1 <pid>` |
| 4 | Open URL in browser | your browser |
| 5 | Approve device pairing | `openclaw devices approve` |

**Details in [docs/STEP-BY-STEP.md](docs/STEP-BY-STEP.md).**

---

## 📁 What's in this repo

```
.
├── README.md                       ← you are here
├── docs/
│   ├── STEP-BY-STEP.md             ← detailed walkthrough
│   ├── TROUBLESHOOTING.md          ← every error I hit + fix
│   └── ARCHITECTURE.md             ← how Daytona proxy works
├── scripts/
│   ├── add-proxy-origin.sh         ← one-shot: backup + edit + reload
│   ├── reload-gateway.sh           ← SIGUSR1 reload helper
│   └── check-origins.py            ← audit which origins are allowed
├── screenshots/                    ← what each error looks like
└── examples/
    └── openclaw-snippet.json       ← exact JSON diff to apply
```

---

## 🚀 TL;DR — for the impatient

```bash
# 1. Find your proxy URL (Daytona exposes one per sandbox)
PROXY="https://18789-XXXXXX.daytonaproxy01.net"

# 2. Run the one-shot script
./scripts/add-proxy-origin.sh "$PROXY"

# 3. Open in browser
xdg-open "$PROXY"   # or just paste in Chrome

# 4. When browser asks for approval, run this on sandbox
openclaw devices approve <fingerprint-from-error>

# 5. Reload browser, paste auth token, done
```

---

## ⚠️ Hard-won lessons (read these)

- **Daytona rotates the proxy URL.** When that happens, repeat steps 1-3 with the new URL. Old URLs stop working.
- **Whitelist all 4 schemes:** `wss://`, `ws://`, `https://`, `http://` — the browser may upgrade HTTP→WS and that needs `wss://` explicitly.
- **Reload, don't restart.** `kill -USR1 <pid>` reloads config. Full restart breaks Telegram polling (duplicate poller error).
- **Device pairing is per-browser.** New browser/device = new approval. Approve on the sandbox host via `openclaw devices approve`.
- **`curl` HTTP 000 is normal.** The proxy URL is browser-only; direct egress from sandbox is intentionally blocked. Don't waste time debugging it.

---

## 🦋 Author & context

Built by **Glasswing 🦋** for **Jeetu Parmar** on 2026-09-04 during a real session (proxy rotated 4 times in 24 hours, finally nailed it).

If this saved you time, ⭐ the repo. If it broke, open an issue with the exact error.
