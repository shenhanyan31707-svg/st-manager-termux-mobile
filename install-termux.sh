#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="$(basename "$SCRIPT_DIR")"
DEFAULT_APP_DIR="$HOME/apps/$APP_NAME"
HOST="${HOSTNAME:-127.0.0.1}"
PORT="${PORT:-3456}"
DATA_PATH_INPUT="${DATA_PATH:-}"
DATA_PATH=""

copy_to_termux_home() {
  local src="$1"
  local dst="$2"
  local tmp="${dst}.tmp.$$"

  mkdir -p "$(dirname "$dst")"
  rm -rf "$tmp"
  mkdir -p "$tmp"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude 'node_modules' --exclude 'logs' --exclude '.git' "$src"/ "$tmp"/
  else
    tar -C "$src" --exclude='./node_modules' --exclude='./logs' --exclude='./.git' -cf - . | tar -C "$tmp" -xf -
  fi

  rm -rf "$dst"
  mv "$tmp" "$dst"
}

try_prepare_data_path() {
  local p="$1"
  [ -n "$p" ] || return 1
  mkdir -p "$p/characters" "$p/worlds" "$p/chats" 2>/dev/null || return 1
  touch "$p/.st_manager_rwtest" 2>/dev/null || return 1
  rm -f "$p/.st_manager_rwtest" || true
  DATA_PATH="$p"
  return 0
}

resolve_data_path() {
  if [ -n "$DATA_PATH_INPUT" ]; then
    if try_prepare_data_path "$DATA_PATH_INPUT"; then
      return 0
    fi
    echo "ERROR: DATA_PATH is not accessible: $DATA_PATH_INPUT"
    echo "Tip: use /storage/emulated/0/SillyTavern/default-user"
    exit 1
  fi

  for candidate in \
    "/storage/emulated/0/SillyTavern/default-user" \
    "/storage/emulated/0/SillyTavern/data/default-user"; do
    if try_prepare_data_path "$candidate"; then
      return 0
    fi
  done

  for mount in /storage/*-*; do
    [ -d "$mount" ] || continue
    for candidate in \
      "$mount/SillyTavern/default-user" \
      "$mount/SillyTavern/data/default-user"; do
      if try_prepare_data_path "$candidate"; then
        return 0
      fi
    done
  done

  echo "ERROR: unable to find writable SillyTavern data path"
  echo "Set it manually: DATA_PATH=/storage/emulated/0/SillyTavern/default-user bash install-termux.sh"
  exit 1
}

if [[ "$SCRIPT_DIR" == /storage/* ]]; then
  echo "[0/8] Shared storage detected, relocating project to $DEFAULT_APP_DIR"
  copy_to_termux_home "$SCRIPT_DIR" "$DEFAULT_APP_DIR"
  echo "Relocation complete. Re-running installer from Termux private directory."
  exec bash "$DEFAULT_APP_DIR/install-termux.sh"
fi

APP_DIR="$SCRIPT_DIR"

echo "[1/8] Install Termux base packages"
pkg update -y
pkg upgrade -y
pkg install -y nodejs-lts git curl jq tmux termux-api termux-services lsof cronie rsync

echo "[2/8] Setup Android shared storage permission"
if command -v termux-setup-storage >/dev/null 2>&1; then
  termux-setup-storage || true
fi

echo "[3/8] Resolve writable data path"
resolve_data_path
echo "Using DATA_PATH=$DATA_PATH"

cat >"$APP_DIR/app-config.json" <<EOF
{
  "dataPath": "$DATA_PATH"
}
EOF

echo "[4/8] Install Node dependencies for mobile runtime"
cd "$APP_DIR"
rm -rf node_modules
npm install --omit=dev

echo "[5/8] Apply executable permissions"
chmod +x install-termux.sh
chmod +x scripts/*.sh
chmod +x termux/runit/st-manager/run termux/runit/st-manager/log/run

echo "[6/8] Start service and run healthcheck"
HOSTNAME="$HOST" PORT="$PORT" NODE_ENV=production DATA_ROOT="$DATA_PATH" bash scripts/start.sh
sleep 2
HOSTNAME="$HOST" PORT="$PORT" bash scripts/healthcheck.sh

echo "[7/8] Enable runit supervision (optional but recommended)"
if command -v sv-enable >/dev/null 2>&1; then
  sv-enable || true
fi
if command -v sv >/dev/null 2>&1; then
  bash scripts/install-runit-service.sh || true
fi

echo "[8/8] Done"

echo
echo "Install complete."
echo "URL: http://127.0.0.1:${PORT}"
echo "APP_DIR: $APP_DIR"
echo "DATA_PATH: $DATA_PATH"
echo "Status: bash $APP_DIR/scripts/status.sh"
echo "Stop:   bash $APP_DIR/scripts/stop.sh"
