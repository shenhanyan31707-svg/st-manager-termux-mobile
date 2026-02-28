#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_PATH="${DATA_PATH:-/storage/emulated/0/SillyTavern/default-user}"
HOST="${HOSTNAME:-127.0.0.1}"
PORT="${PORT:-3456}"

echo "[1/7] Install Termux base packages"
pkg update -y
pkg upgrade -y
pkg install -y nodejs-lts git curl jq tmux termux-api termux-services lsof cronie

echo "[2/7] Setup Android shared storage permission"
if command -v termux-setup-storage >/dev/null 2>&1; then
  termux-setup-storage || true
fi

echo "[3/7] Prepare SillyTavern data folders"
mkdir -p "$DATA_PATH/characters" "$DATA_PATH/worlds" "$DATA_PATH/chats"

cat >"$APP_DIR/app-config.json" <<EOF
{
  "dataPath": "$DATA_PATH"
}
EOF

echo "[4/7] Install Node dependencies for mobile runtime"
cd "$APP_DIR"
rm -rf node_modules
npm install --omit=dev

echo "[5/7] Apply executable permissions"
chmod +x install-termux.sh
chmod +x scripts/*.sh
chmod +x termux/runit/st-manager/run termux/runit/st-manager/log/run

echo "[6/7] Start service and run healthcheck"
HOSTNAME="$HOST" PORT="$PORT" NODE_ENV=production DATA_ROOT="$DATA_PATH" bash scripts/start.sh
sleep 2
HOSTNAME="$HOST" PORT="$PORT" bash scripts/healthcheck.sh

echo "[7/7] Enable runit supervision (optional but recommended)"
if command -v sv-enable >/dev/null 2>&1; then
  sv-enable || true
fi
if command -v sv >/dev/null 2>&1; then
  bash scripts/install-runit-service.sh || true
fi

echo
echo "Install complete."
echo "URL: http://127.0.0.1:${PORT}"
echo "Status: bash $APP_DIR/scripts/status.sh"
echo "Stop:   bash $APP_DIR/scripts/stop.sh"
