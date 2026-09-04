# Step-by-Step: Make OpenClaw Dashboard Public

**Time needed:** 5-10 minutes (first time). 1 minute (after proxy rotates).

**Skill level:** Anyone who can copy-paste in a terminal.

---

## Pre-flight checklist

Before starting, confirm:

- [ ] You're logged into the **sandbox host** (where OpenClaw runs), not your local machine
- [ ] OpenClaw is installed and running
- [ ] You know the config path (default: `/home/daytona/.openclaw/openclaw.json` or `~/.openclaw/openclaw.json`)
- [ ] You have permission to edit that config and kill processes

Verify with:

```bash
which openclaw               # should print /usr/bin/openclaw or similar
ps aux | grep openclaw       # should show openclaw-gateway process
```

---

## Step 1: Find your Daytona proxy URL

Daytona assigns a public proxy URL to each sandbox's port 18789. The format is:

```
https://18789-<random-hash>.daytonaproxy01.net
```

Where to find it:

| Source | How |
|--------|-----|
| Daytona dashboard UI | Sandbox details page → "Ports" tab → click 18789 → "Public URL" |
| Daytona CLI | `daytona sandbox info <sandbox-id>` (look for `proxyUrls`) |
| Sandbox env var | `env | grep -i proxy` (sometimes exposed) |
| Ask the user | If you control the Daytona workspace, the user can copy from their dashboard |

**Once you have it, copy it.** Example:

```
https://18789-wztkrayaqjexo9g1.daytonaproxy01.net
```

> 💡 The hash part rotates when Daytona re-provisions the sandbox. Old URLs stop working — repeat the steps below with the new one.

---

## Step 2: Backup the config

Always backup before editing:

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%Y%m%d%H%M%S)
ls -la ~/.openclaw/openclaw.json*  # verify backup exists
```

---

## Step 3: Add the proxy URL to `allowedOrigins`

Open the config in your editor:

```bash
nano ~/.openclaw/openclaw.json
# or: vim, code, whatever you like
```

Find the `gateway.controlUi.allowedOrigins` array. It looks like:

```json
"controlUi": {
  "allowedOrigins": [
    "http://localhost:18789",
    "http://127.0.0.1:18789"
  ]
}
```

**Add 4 new entries** (replace `YOUR_HASH` with the hash from your proxy URL):

```json
"wss://18789-YOUR_HASH.daytonaproxy01.net",
"ws://18789-YOUR_HASH.daytonaproxy01.net",
"https://18789-YOUR_HASH.daytonaproxy01.net",
"http://18789-YOUR_HASH.daytonaproxy01.net"
```

Final array should look like:

```json
"allowedOrigins": [
  "http://localhost:18789",
  "http://127.0.0.1:18789",
  "wss://18789-wztkrayaqjexo9g1.daytonaproxy01.net",
  "ws://18789-wztkrayaqjexo9g1.daytonaproxy01.net",
  "https://18789-wztkrayaqjexo9g1.daytonaproxy01.net",
  "http://18789-wztkrayaqjexo9g1.daytonaproxy01.net"
]
```

**Save and exit.**

> ⚠️ Why all 4 schemes? The browser starts the request as `https://`, then the WebSocket upgrade request goes as `wss://`. If you only whitelist `https://`, the WebSocket handshake fails with CORS error.

---

## Step 4: Validate the JSON

Before reloading, make sure you didn't break the JSON:

```bash
python3 -c "import json; json.load(open('/home/daytona/.openclaw/openclaw.json'))" && echo "✓ JSON valid"
```

If you get a parse error, restore from backup:

```bash
cp ~/.openclaw/openclaw.json.bak.<timestamp> ~/.openclaw/openclaw.json
```

---

## Step 5: Reload the gateway (NO restart)

Find the gateway PID:

```bash
ps aux | grep openclaw-gateway | grep -v grep
# Output example:
# daytona  266477  ...  openclaw-gateway
```

Take note of the PID (e.g. `266477`). Send `SIGUSR1` to reload config without restarting:

```bash
kill -USR1 266477
sleep 2
ps -p 266477 -o pid,etime,cmd   # verify it's still alive
```

**Expected output:** process still listed, elapsed time continues incrementing. If it died, your JSON was bad — restore from backup and re-validate.

> ⚠️ **DO NOT use `kill -9` or full restart.** A full restart breaks Telegram polling (the gateway starts a second poller, you get "Telegram: another poller is already running" errors). `SIGUSR1` is the right way.

---

## Step 6: Open the URL in your browser

Paste your proxy URL into Chrome/Firefox/whatever:

```
https://18789-wztkrayaqjexo9g1.daytonaproxy01.net/
```

**Two possible outcomes:**

### A) Dashboard loads → you're done

It might ask for an auth token. If so, generate one with:

```bash
openclaw token issue
# or check ~/.openclaw/openclaw.json for "authToken" or similar
```

Paste the token, dashboard opens, life is good.

### B) "One-time approval required" error

This is the device pairing flow. The error message gives you the exact command:

```
This browser needs one-time approval from the Gateway host before it can use the Control UI.

Run openclaw devices list on the Gateway host.

Approve this request: openclaw devices approve 889f0534-f791-4e44-bf***.

Reconnect after the approval completes.
```

**Run the approve command on the sandbox host:**

```bash
openclaw devices approve 889f0534-f791-4e44-bf***
```

Wait for "approved" confirmation, then refresh the browser. Done.

---

## Step 7: (Optional) Verify in the dashboard

Once you're in:

- Check "Devices" tab → your browser should be listed as `operator` role with scopes `admin`, `read`, `write`, `approvals`, `pairing`
- Check "Sessions" tab → you should see your current session listed
- Try sending a test message through the chat UI

If all three work, the setup is complete.

---

## 🎉 Done

Your OpenClaw control UI is now publicly accessible at `https://18789-<hash>.daytonaproxy01.net/`. Bookmark it. If Daytona rotates the hash, repeat steps 1-5 with the new URL.

---

**Next:** read [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for fixes to every error I hit while building this. Read [ARCHITECTURE.md](ARCHITECTURE.md) if you want to understand what's actually happening under the hood.
