# Architecture: How Daytona Proxy + OpenClaw Fit Together

> Skip this if you just want to make it work. Read this if you want to understand *why* it works (and debug weird issues).

---

## The 30,000-foot view

```
┌──────────────────┐                              ┌──────────────────┐
│   Your browser   │                              │  Daytona proxy   │
│  (Chrome/etc.)   │  ──HTTPS/WSS─over-public─▶  │  *.daytonaproxy01│
│                  │  ◀────────────response────   │       .net       │
└──────────────────┘                              └────────┬─────────┘
                                                            │
                                            encrypted tunnel│
                                              (Daytona's    │
                                               internal VPN) │
                                                            ▼
                                                  ┌──────────────────┐
                                                  │  Your sandbox    │
                                                  │                  │
                                                  │  ┌────────────┐  │
                                                  │  │ openclaw-  │  │
                                                  │  │  gateway   │  │
                                                  │  │  :18789    │  │
                                                  │  └─────┬──────┘  │
                                                  │        │         │
                                                  │  ┌─────▼──────┐  │
                                                  │  │  control   │  │
                                                  │  │     UI     │  │
                                                  │  └────────────┘  │
                                                  │                  │
                                                  │  ┌────────────┐  │
                                                  │  │ Telegram/  │  │
                                                  │  │ other bots │  │
                                                  │  └────────────┘  │
                                                  └──────────────────┘
```

The browser talks to `*.daytonaproxy01.net` (public). Daytona has a persistent encrypted tunnel to each sandbox. The proxy routes incoming requests to the right sandbox's port 18789. The sandbox returns the response back through the tunnel.

---

## Why the sandbox needs `allowedOrigins` config

Browsers enforce CORS (Cross-Origin Resource Sharing). When your browser at origin `https://18789-X.daytonaproxy01.net` makes a request, the server (OpenClaw gateway) checks:

> "Is this origin in my allowed list?"

If not, it rejects the request with CORS error. The `allowedOrigins` config in OpenClaw is this allowlist.

**Why all 4 schemes?**

A single page load uses multiple schemes:

1. Initial HTML load → `https://`
2. WebSocket upgrade for live chat → `wss://`
3. (Sometimes) HTTP fallback → `http://`
4. (Sometimes) WS fallback → `ws://`

If you only allow `https://`, the page loads but the chat doesn't connect. Allow all 4 to be safe.

---

## Why `SIGUSR1` and not restart

OpenClaw's gateway has two responsibilities:

1. **Serve the control UI** (HTTP + WebSocket on port 18789)
2. **Run bots** (Telegram, Discord, etc. — long-poll or webhook)

A full restart kills both. When it comes back up, it re-initializes bots. Telegram specifically has a "poller" lock — if the old process's lock hasn't expired, the new process gets:

```
Error: Another poller is already running.
```

And the bot stops responding.

`SIGUSR1` tells the gateway "reload config, keep running." No restart, no bot re-init, no poller conflict.

---

## Why direct curl from the sandbox to its own proxy URL fails

Daytona sandboxes have strict egress rules:

- **Port 80:** Envoy returns 403 (HTML response, but blocked)
- **Port 443:** SNI allowlist. Each domain must be explicitly approved. Subdomains are NOT covered by parent allow (so allowing `daytonaproxy01.net` does NOT allow `18789-X.daytonaproxy01.net`).
- **SNI spoofing doesn't work:** The proxy routes by SNI. If you set SNI to `google.com` but connect to a Daytona proxy IP, you get a 301 redirect to the SNI domain (not the actual proxy).

The proxy URL is meant to be accessed from **outside** (your browser). Inside the sandbox, you should use `http://localhost:18789` directly.

---

## Why device pairing exists

When the browser first connects, the gateway has no idea who it is. The browser generates a device fingerprint and sends a pairing request. The user (on the sandbox host) has to manually approve it.

This prevents random people on the internet from accessing your gateway if they stumble on the proxy URL.

**Scopes assigned on approval:**

| Scope | Allows |
|-------|--------|
| `operator.read` | View dashboard, see sessions |
| `operator.write` | Send messages, modify sessions |
| `operator.admin` | Change config, restart gateway |
| `operator.approvals` | Approve other device pairings |
| `operator.pairing` | Re-trigger pairing flow |

The default "operator" role gets all 5, which is the standard trusted-user setup.

---

## The full request lifecycle

1. User opens `https://18789-X.daytonaproxy01.net/` in Chrome
2. Chrome resolves DNS → Daytona proxy IP
3. Chrome sends `GET /` with `Origin: https://18789-X.daytonaproxy01.net`
4. Daytona's edge proxy receives, checks: "is this sandbox still alive?"
   - Yes → forward to sandbox tunnel
   - No → return 502
5. Sandbox's openclaw-gateway receives, checks `allowedOrigins` for the Origin header
   - Match → serve the dashboard
   - No match → return CORS error
6. Dashboard HTML loads, JS runs, opens WebSocket to `wss://18789-X.daytonaproxy01.net/api/...`
7. WebSocket upgrade request goes through same proxy → same origin check (this is why we need `wss://` in allowedOrigins too)
8. WS connected, dashboard live, user can chat/control
9. When Telegram message arrives at the gateway, it broadcasts over the WS to all connected dashboards

---

## What changes when the proxy URL rotates

Daytona occasionally:

- Re-provisions the sandbox (new container)
- Updates the proxy mapping (new hash)
- Restarts the edge proxy

When this happens:

- Old URL → 404 or "sandbox not found"
- New URL → generated, shown in Daytona dashboard
- **Your config is now out of date** — old origin still in allowedOrigins but unreachable; new origin not in list

**Solution:** When you notice 404, ask Daytona dashboard for new URL, repeat [STEP-BY-STEP.md](STEP-BY-STEP.md) steps 1-5. Takes 1 minute.

**Pro tip:** Some setups expose the current URL via env var inside the sandbox. Check with `env | grep -i daytona` or `env | grep -i proxy`. If found, you can script the update.

---

## Network security implications

⚠️ Anyone with the proxy URL can attempt to access your dashboard. The pairing flow prevents random access, but:

- The URL is in browser history, server logs, screenshots, etc.
- Treat it like a public endpoint
- Rotate it periodically (force a new hash) if leaked
- Use strong auth tokens (32+ chars, random)

The 4-scheme allowedOrigins expansion does NOT increase attack surface — same origin, just protocol variants.

---

**Questions, corrections, missing details?** Open an issue or PR. The goal is to make this the canonical guide.
