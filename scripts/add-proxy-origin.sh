#!/bin/bash
# add-proxy-origin.sh
# One-shot: backup openclaw.json, add proxy URL to allowedOrigins (all 4 schemes), reload gateway
#
# Usage:
#   ./add-proxy-origin.sh https://18789-wztkrayaqjexo9g1.daytonaproxy01.net
#
# What it does:
#   1. Backs up current openclaw.json with timestamp
#   2. Validates the URL format
#   3. Adds 4 origin variants to allowedOrigins (wss://, ws://, https://, http://)
#   4. Validates the resulting JSON
#   5. Reloads the gateway with SIGUSR1 (no restart)
#   6. Verifies gateway is still alive
#
# Requirements:
#   - python3
#   - openclaw-gateway running
#   - You can kill the gateway process (same user or root)

set -euo pipefail

# --- Config ---
CONFIG_PATH="${OPENCLAW_CONFIG:-$HOME/.openclaw/openclaw.json}"
PROXY_URL="${1:-}"

# --- Colors for output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helpers ---
die() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }
ok()  { echo -e "${GREEN}✓ $1${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $1${NC}"; }

# --- Preflight ---
[ -z "$PROXY_URL" ] && die "Usage: $0 <proxy-url>

Example:
  $0 https://18789-wztkrayaqjexo9g1.daytonaproxy01.net

Get the URL from your Daytona dashboard (Sandbox → Ports → 18789 → Public URL)."

# Validate URL format
[[ "$PROXY_URL" =~ ^https?://18789-[a-z0-9]+\.daytonaproxy01\.net/?$ ]] || \
  die "URL doesn't match expected pattern: https://18789-<hash>.daytonaproxy01.net/

Got: $PROXY_URL"

[ -f "$CONFIG_PATH" ] || die "Config not found: $CONFIG_PATH

Set OPENCLAW_CONFIG env var or use the default path."

ok "Config found: $CONFIG_PATH"
ok "Proxy URL: $PROXY_URL"

# --- Step 1: Backup ---
BACKUP_PATH="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
ok "Backup created: $BACKUP_PATH"

# --- Step 2: Compute all 4 origin variants ---
# Strip trailing slash for consistency
BASE_URL="${PROXY_URL%/}"

# Extract the host (https://18789-HASH.daytonaproxy01.net -> 18789-HASH.daytonaproxy01.net)
HOST=$(echo "$BASE_URL" | sed -E 's|^https?://||')

ORIGINS_JSON=$(python3 -c "
import json
base = '$BASE_URL'
host = base.replace('https://', '').replace('http://', '')
variants = [
    f'wss://{host}',
    f'ws://{host}',
    f'https://{host}',
    f'http://{host}',
]
print(json.dumps(variants))
")

ok "Will add 4 variants for host: $HOST"

# --- Step 3: Edit config (use Python for safe JSON manipulation) ---
python3 << EOF
import json, sys

config_path = "$CONFIG_PATH"
new_origins = json.loads('''$ORIGINS_JSON''')

with open(config_path) as f:
    cfg = json.load(f)

# Navigate to gateway.controlUi.allowedOrigins (create if missing)
if 'gateway' not in cfg:
    cfg['gateway'] = {}
if 'controlUi' not in cfg['gateway']:
    cfg['gateway']['controlUi'] = {}
if 'allowedOrigins' not in cfg['gateway']['controlUi']:
    cfg['gateway']['controlUi']['allowedOrigins'] = []

origins = cfg['gateway']['controlUi']['allowedOrigins']

# Dedupe: add only new ones
before_count = len(origins)
for variant in new_origins:
    if variant not in origins:
        origins.append(variant)
after_count = len(origins)

# Write back
with open(config_path, 'w') as f:
    json.dump(cfg, f, indent=2)

print(f"Origins before: {before_count}")
print(f"Origins after:  {after_count}")
print(f"Added: {after_count - before_count} new variant(s)")
EOF

ok "Config updated"

# --- Step 4: Validate JSON ---
python3 -c "import json; json.load(open('$CONFIG_PATH'))" || \
  die "JSON validation failed! Restoring from backup: $BACKUP_PATH
$ cp $BACKUP_PATH $CONFIG_PATH"
ok "JSON valid"

# --- Step 5: Find gateway PID and send SIGUSR1 ---
GATEWAY_PID=$(pgrep -f 'openclaw-gateway' | head -1)

if [ -z "$GATEWAY_PID" ]; then
  die "openclaw-gateway process not found! Config updated but not reloaded.
Manually run: kill -USR1 <pid>"
fi

ok "Gateway PID: $GATEWAY_PID"
warn "Sending SIGUSR1 to reload config (NOT a full restart)..."

kill -USR1 "$GATEWAY_PID"
sleep 2

# --- Step 6: Verify gateway still alive ---
if kill -0 "$GATEWAY_PID" 2>/dev/null; then
  ok "Gateway still alive after reload"
else
  die "Gateway died after reload! Check your config.
Restore from: $BACKUP_PATH"
fi

# --- Summary ---
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Done!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo "  1. Open in your browser: $PROXY_URL"
echo "  2. If you get 'one-time approval' error, run on this host:"
echo "     openclaw devices approve <fingerprint-from-error>"
echo ""
echo "Backup location: $BACKUP_PATH"
echo ""
