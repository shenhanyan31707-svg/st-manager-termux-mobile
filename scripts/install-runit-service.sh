#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_SRC="$APP_DIR/termux/runit/st-manager"
SERVICE_ROOT="${PREFIX:-/data/data/com.termux/files/usr}/var/service"
SERVICE_DST="$SERVICE_ROOT/st-manager"

if [ ! -d "$SERVICE_ROOT" ]; then
  echo "termux-services is not ready. run: pkg install termux-services"
  exit 1
fi

if [ ! -d "$SERVICE_SRC" ]; then
  echo "missing service template: $SERVICE_SRC"
  exit 1
fi

mkdir -p "$HOME/apps/st-manager/logs/runit"

if [ -d "$SERVICE_DST" ]; then
  backup_dir="${SERVICE_DST}.bak.$(date +%s)"
  mv "$SERVICE_DST" "$backup_dir"
  echo "old service moved to $backup_dir"
fi

cp -r "$SERVICE_SRC" "$SERVICE_DST"
chmod +x "$SERVICE_DST/run" "$SERVICE_DST/log/run"

sv up st-manager || true
sv status st-manager || true

echo "runit service installed at $SERVICE_DST"
