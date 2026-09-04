# Troubleshooting: Every Error I Hit + Fix

Real errors, in order I hit them, with the actual fix. If something breaks, search for the error message below.

---

## 🔴 "CORS: Origin not allowed" / "Blocked by allowedOrigins"

**Symptom:**

```
Access to fetch at 'https://...' from origin 'https://18789-...' has been blocked by CORS policy:
The 'Access-Control-Allow-Origin' header has a value that is not equal to the supplied origin.
```

**Fix:** Step 3 in [STEP-BY-STEP.md](STEP-BY-STEP.md). Your origin isn't in `allowedOrigins`. Add all 4 schemes (`wss://`, `ws://`, `https://`, `http://`).

**Verify after fix:**

```bash
python3 -c "
import json
cfg = json.load(open('/home/daytona/.openclaw/openclaw.json'))
origins = cfg.get('gateway', {}).get('controlUi', {}).get('allowedOrigins', [])
your_origin = 'wss://18789-wztkrayaqjexo9g1.daytonaproxy01.net'
print(f'Found: {your_origin in origins}')
"
```

If `False`, you forgot to add the `wss://` variant specifically. The browser upgrades to WebSocket using the `wss://` scheme, not `https://`.

---

## 🔴 "Invalid JSON" after editing

**Symptom:**

```bash
$ python3 -c "import json; json.load(open('openclaw.json'))"
Traceback (most recent call last):
  ...
json.decoder.JSONDecodeError: Expecting ',' delimiter: line 47
```

**Fix:** Restore from backup, redo edit more carefully:

```bash
cp ~/.openclaw/openclaw.json.bak.<timestamp> ~/.openclaw/openclaw.json
# re-edit, this time use a JSON-aware editor (code, vim with json plugin)
```

**Pro tip:** Use Python to do the edit instead of hand-editing:

```python
import json
with open('/home/daytona/.openclaw/openclaw.json') as f:
    cfg = json.load(f)
cfg['gateway']['controlUi']['allowedOrigins'].append('wss://YOUR_URL')
with open('/home/daytona/.openclaw/openclaw.json', 'w') as f:
    json.dump(cfg, f, indent=2)
```

---

## 🔴 "Gateway died after SIGUSR1"

**Symptom:** Process not found after reload.

**Fix:** Your JSON was probably bad. Check the gateway logs (usually stderr/journalctl) and the JSON. Restore from backup, validate, retry.

```bash
# Find gateway logs
journalctl -u openclaw --since "5 minutes ago"   # if systemd
# or
ls /var/log/openclaw*                            # if file logs
```

---

## 🔴 "Telegram: another poller is already running" after restart

**Symptom:** After `kill -9` or full restart, Telegram replies stop coming or you get duplicate-poller errors.

**Fix:** You should have used `SIGUSR1` for reload, not restart. If you already restarted and broke it:

```bash
# Find all running openclaw processes
ps aux | grep openclaw | grep -v grep
# Kill ALL except the one you want to keep (exact PID only — never pkill -f)
kill <old-pid>
# Wait for the duplicate poller error to clear
```

Going forward: **always use `kill -USR1 <pid>` for config reload.**

---

## 🔴 "This browser needs one-time approval"

**Symptom:** Browser shows the device pairing error message.

**Fix:** Step 6B in [STEP-BY-STEP.md](STEP-BY-STEP.md). Run the `openclaw devices approve <fingerprint>` command on the sandbox host.

**If the command fails with "not found":**

```bash
# The device might have already auto-approved and just need a refresh
openclaw devices list   # check if your fingerprint is there
# If yes, just refresh the browser
# If no, your gateway may have a different pairing flow — check the docs
```

---

## 🔴 Browser shows "504 Gateway Timeout" / "502 Bad Gateway"

**Symptom:** Proxy URL works (returns 5xx instead of refusing) but never reaches the gateway.

**Fix:** Your gateway is not running, or the port is wrong. Verify:

```bash
ps aux | grep openclaw-gateway | grep -v grep   # process exists
ss -tlnp | grep 18789                            # port 18789 listening
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18789/   # local health
```

If `curl` returns 200 locally but browser returns 502, the Daytona proxy can't reach your sandbox. Check Daytona sandbox status — it might be paused/stopped.

---

## 🔴 "curl https://<proxy-url> returns 000"

**Symptom:**

```bash
$ curl -s -o /dev/null -w "%{http_code}\n" https://18789-XXXX.daytonaproxy01.net/
000
```

**Fix:** **This is expected. Stop trying to curl it.** The proxy URL is browser-only — direct egress from your sandbox to its own public URL is blocked by Daytona's network policy. The proxy URL works only when accessed from outside (your browser).

If you want to test the proxy externally, use a different machine or a service like `https://webhook.site` (paste the URL, see if it pings). But the real test is: **just open it in a browser and see what happens.**

---

## 🔴 "Token invalid" / "Auth failed" in dashboard

**Symptom:** Dashboard loads, asks for token, you paste it, says invalid.

**Fix:** Regenerate the token:

```bash
openclaw token issue
# or
cat ~/.openclaw/openclaw.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('authToken'))"
```

If neither works, your gateway might not be using token auth — check the `auth` section of `openclaw.json`. Set one:

```json
"auth": {
  "token": "your-generated-token-here"
}
```

Reload with SIGUSR1.

---

## 🔴 Proxy URL rotated (was working, now 404)

**Symptom:** Same setup, same config, but the URL now 404s or returns "sandbox not found".

**Fix:** Daytona re-provisioned your sandbox. Get the new URL from the Daytona dashboard, repeat [STEP-BY-STEP.md](STEP-BY-STEP.md) steps 1-5 with the new URL. Old URL will never work again.

**Automation idea:** if this happens a lot, write a cron that runs `daytona sandbox info` every 5 min, parses the new proxy URL, and updates `allowedOrigins` automatically. (Not in scope for this guide, but doable.)

---

## 🟡 Everything works but dashboard is laggy

**Symptom:** Dashboard loads but chat / actions are slow.

**Possible causes:**

- Daytona proxy is geographically far from you → use a different sandbox region
- Sandbox is CPU-starved → check `top`, kill unnecessary processes
- WebSocket reconnecting constantly → check browser devtools network tab, look for 4xx/5xx

---

## 🟡 "device approved but browser still won't connect"

**Fix:** Hard refresh browser (Ctrl+Shift+R), or open in incognito. Browser cached the old error.

---

**Still stuck?** Open an issue with:

1. Exact error message (copy-paste)
2. Output of `ps aux | grep openclaw-gateway`
3. Output of `python3 -c "import json; print(json.load(open('/home/daytona/.openclaw/openclaw.json'))['gateway']['controlUi']['allowedOrigins'])"`
4. Output of `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:18789/` (from inside the sandbox)
