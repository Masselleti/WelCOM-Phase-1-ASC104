#!/bin/zsh

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PORT=8104
URL="http://localhost:${PORT}/index.html"
LOG_FILE="/tmp/welcom_phase1_asc104_server.log"

cd "$APP_DIR" || exit 1

if ! /usr/bin/curl -fsI "$URL" >/dev/null 2>&1; then
  /usr/bin/nohup /usr/bin/env python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$APP_DIR" >"$LOG_FILE" 2>&1 &
  sleep 1
fi

if [ -d "/Applications/Google Chrome.app" ]; then
  /usr/bin/open -a "Google Chrome" "$URL"
else
  /usr/bin/open "$URL"
fi

echo "WelCOM Phase 1 ASC104 is open at $URL"
echo "Server log: $LOG_FILE"
echo "You can close this Terminal window."
