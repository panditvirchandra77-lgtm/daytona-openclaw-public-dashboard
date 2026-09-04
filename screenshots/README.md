# Screenshots: What Each Error Looks Like

> Real screenshot files would be binary — since this repo is text-first, I've drawn each error as ASCII so you know what to look for in your browser. If you want real screenshots, PR them in!

---

## 1. CORS error (origin not allowed)

**When:** You opened the URL but didn't add the `wss://` variant.

```
┌────────────────────────────────────────────────────────────────────────┐
│  Chrome  https://18789-wztkrayaqjexo9g1.daytonaproxy01.net/            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Access to fetch at 'wss://18789-wztkrayaqjexo9g1.daytonaproxy01.net' │
│  from origin 'https://18789-wztkrayaqjexo9g1.daytonaproxy01.net' has  │
│  been blocked by CORS policy: The 'Access-Control-Allow-Origin'        │
│  header has a value that is not equal to the supplied origin.          │
│                                                                        │
│  [Open DevTools]  [Learn more]                                        │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**Fix:** [STEP-BY-STEP.md](../docs/STEP-BY-STEP.md) step 3 — add the `wss://` variant.

---

## 2. Device pairing approval needed

**When:** Origin is allowed, but this is a new browser/device.

```
┌────────────────────────────────────────────────────────────────────────┐
│  Chrome  https://18789-wztkrayaqjexo9g1.daytonaproxy01.net/            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  This browser needs one-time approval from the Gateway host before     │
│  it can use the Control UI.                                            │
│                                                                        │
│  Run openclaw devices list on the Gateway host.                        │
│                                                                        │
│  Approve this request:                                                 │
│  openclaw devices approve 889f0534-f791-4e44-bf***                     │
│                                                                        │
│  Reconnect after the approval completes.                               │
│                                                                        │
│  [Raw error]  [Device pairing docs]                                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**Fix:** SSH into the sandbox, run the approve command, then refresh browser.

---

## 3. Auth token prompt (after approval)

**When:** Origin allowed + device approved, but no auth token yet.

```
┌────────────────────────────────────────────────────────────────────────┐
│  Chrome  https://18789-wztkrayaqjexo9g1.daytonaproxy01.net/            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│           ┌────────────────────────────────────────┐                   │
│           │      Enter Gateway Auth Token          │                   │
│           │                                        │                   │
│           │  ┌──────────────────────────────────┐  │                   │
│           │  │                                  │  │                   │
│           │  └──────────────────────────────────┘  │                   │
│           │                                        │                   │
│           │            [ Connect ]                 │                   │
│           │                                        │                   │
│           │  Generate with: openclaw token issue   │                   │
│           └────────────────────────────────────────┘                   │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

**Fix:** On the sandbox host: `openclaw token issue`, paste result, click Connect.

---

## 4. Dashboard loaded (success)

**When:** Everything works.

```
┌────────────────────────────────────────────────────────────────────────┐
│  Glasswing Control UI                            [⏻ Disconnect] [⚙]   │
├──────────────┬─────────────────────────────────────────────────────────┤
│              │                                                         │
│  Sessions    │  Welcome to OpenClaw                                   │
│  ──────────  │  ─────────────────────                                  │
│  • main      │                                                         │
│  • isolated  │  Connected via: wss://18789-wztkrayaqjexo9g1....       │
│              │  Device: 889f0534-f791-4e44-bf*** (operator)            │
│  Devices (4) │  Uptime: 4h 23m                                        │
│  ──────────  │                                                         │
│  • main-pc   │  Recent activity:                                      │
│  • phone-1   │  ✓ Telegram bot polling healthy                        │
│  • browser-1 │  ✓ 3 active sessions                                   │
│  • current   │                                                         │
│              │                                                         │
│  Models      │                                                         │
│  ──────────  │                                                         │
│  • deepseek  │                                                         │
│  • minimax   │                                                         │
│              │                                                         │
└──────────────┴─────────────────────────────────────────────────────────┘
```

🎉 You made it.
