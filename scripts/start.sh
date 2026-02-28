#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$APP_DIR/logs"
PID_FILE="$APP_DIR/.st-manager.pid"
DATE_TAG="$(date +%F)"
CONFIG_FILE="$APP_DIR/app-config.json"

mkdir -p "$LOG_DIR"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "st-manager already running (pid=$(cat "$PID_FILE"))."
  exit 0
fi

rm -f "$PID_FILE"

export HOSTNAME="${ST_MANAGER_HOST:-127.0.0.1}"
export PORT="${PORT:-3456}"
export NODE_ENV="${NODE_ENV:-production}"

CONFIG_DATA_ROOT=""
if [ -f "$CONFIG_FILE" ] && command -v node >/dev/null 2>&1; then
  CONFIG_DATA_ROOT="$(node -e 'try{const fs=require("fs"); const p=JSON.parse(fs.readFileSync(process.argv[1], "utf8")).dataPath || ""; process.stdout.write(p)}catch{}' "$CONFIG_FILE" 2>/dev/null || true)"
fi

export DATA_ROOT="${DATA_ROOT:-${CONFIG_DATA_ROOT:-$HOME/.st-manager/data/default-user}}"

LOG_FILE="$LOG_DIR/app-$DATE_TAG.log"

(
  cd "$APP_DIR"
  nohup node server.js >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
)

sleep 1

if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "st-manager started (pid=$(cat "$PID_FILE"), host=$HOSTNAME, port=$PORT)"
  exit 0
fi

echo "st-manager failed to start, check $LOG_FILE"
exit 1
