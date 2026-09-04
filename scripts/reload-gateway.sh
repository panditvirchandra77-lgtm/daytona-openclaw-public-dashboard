#!/bin/bash
# reload-gateway.sh
# Reload OpenClaw gateway config without restarting (uses SIGUSR1)
#
# Usage:
#   ./reload-gateway.sh
#
# Why SIGUSR1 and not restart?
#   - SIGUSR1: reload config in-place, no bot re-init
#   - Full restart: breaks Telegram poller lock, you get "another poller is already running"
#
# If the gateway has multiple instances (shouldn't, but just in case), this reloads the first one.

set -euo pipefail

GATEWAY_PID=$(pgrep -f 'openclaw-gateway' | head -1)

if [ -z "$GATEWAY_PID" ]; then
  echo "✗ openclaw-gateway process not found"
  echo ""
  echo "Is OpenClaw running?"
  echo "  systemctl status openclaw   # if systemd"
  echo "  ps aux | grep openclaw      # check manually"
  exit 1
fi

echo "Found gateway PID: $GATEWAY_PID"
echo "Sending SIGUSR1 (reload config, no restart)..."

kill -USR1 "$GATEWAY_PID"
sleep 2

if kill -0 "$GATEWAY_PID" 2>/dev/null; then
  echo "✓ Gateway still alive (config reloaded)"
  ps -p "$GATEWAY_PID" -o pid,etime,rss,cmd
else
  echo "✗ Gateway died! Check logs and restore config from backup if needed."
  exit 1
fi
