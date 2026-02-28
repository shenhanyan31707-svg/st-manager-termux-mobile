#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PORT="${PORT:-3456}"
URL="http://127.0.0.1:${PORT}/api/stats"

RESPONSE="$(curl -fsS --max-time 10 "$URL")" || {
  echo "healthcheck failed: cannot reach $URL"
  exit 1
}

if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq -e '.success == true' >/dev/null || {
    echo "healthcheck failed: success is not true"
    exit 1
  }
else
  echo "$RESPONSE" | grep -q '"success":true' || {
    echo "healthcheck failed: success is not true"
    exit 1
  }
fi

echo "healthcheck ok"
