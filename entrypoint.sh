#!/usr/bin/env bash
# nb-vpn entrypoint: start the NetBird daemon, optionally auto-connect, then
# launch the web UI. Modeled on the BlueOS-ZeroTier extension entrypoint.
set -Eeuo pipefail

NETBIRD_BIN="netbird"
CONFIG_DIR="/var/lib/netbird"
CONFIG_FILE="${NB_CONFIG:-$CONFIG_DIR/config.json}"

mkdir -p "$CONFIG_DIR"

log() { echo "=> $*"; }

service_pid=""
on_exit() {
  log "Shutting down NetBird daemon..."
  [ -n "$service_pid" ] && kill -TERM "$service_pid" 2>/dev/null || true
  exit 0
}
trap on_exit INT TERM

# 1. Start the NetBird daemon in the background, pointed at the persisted config.
log "Starting NetBird daemon (netbird service run --config=$CONFIG_FILE)"
"$NETBIRD_BIN" service run --config="$CONFIG_FILE" &
service_pid=$!

# 2. Wait for the daemon socket to become responsive.
log "Waiting for daemon to become live..."
for _ in $(seq 1 30); do
  if "$NETBIRD_BIN" status --check live >/dev/null 2>&1; then
    log "Daemon is live"
    break
  fi
  sleep 1
done

# 3. Write the healthcheck (daemon liveness -> healthy after install, even
#    before the VPN is configured).
cat >/healthcheck.sh <<'EOF'
#!/bin/bash
netbird status --check live >/dev/null 2>&1 || exit 1
EOF
chmod +x /healthcheck.sh

# 4. Launch the web UI (always available so the operator can configure/connect).
log "Starting web UI on :9131"
( cd /web && python main.py ) &

# 5. Bring up NetBird. `netbird up` reads NB_SETUP_KEY / NB_MANAGEMENT_URL from
#    the environment when set, and otherwise reconnects using the persisted
#    registration. On a brand-new install with no key it fails fast (no TTY, so
#    it can't prompt) — harmless; the operator connects via the web UI. Non-fatal.
log "Bringing up NetBird (uses NB_SETUP_KEY / NB_MANAGEMENT_URL if set, else persisted login)"
if timeout 90 "$NETBIRD_BIN" up; then
  log "NetBird is up"
else
  log "NetBird not connected yet — configure it via the web UI"
fi

log "Ready"
wait "$service_pid"
