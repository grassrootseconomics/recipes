#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot4}"
EXPORT_MODE="${EXPORT_MODE:-release}"
WEB_DIR="${WEB_DIR:-web}"

cd "$ROOT_DIR/client"
mkdir -p "$WEB_DIR"

case "$EXPORT_MODE" in
  debug)
    "$GODOT_BIN" --headless --export-debug Web "$WEB_DIR/index.html"
    ;;
  release)
    "$GODOT_BIN" --headless --export-release Web "$WEB_DIR/index.html"
    ;;
  *)
    echo "EXPORT_MODE must be 'debug' or 'release'." >&2
    exit 2
    ;;
esac

cp "$ROOT_DIR/CNAME" "$WEB_DIR/CNAME"
touch "$WEB_DIR/.nojekyll"

# Godot's PWA service worker can keep serving stale index.pck/index.html while
# iterating locally. Recipes is not relying on offline PWA caching yet, so keep
# the export cache-neutral until a production cache strategy is intentional.
rm -f "$WEB_DIR/index.service.worker.js" "$WEB_DIR/index.offline.html"

if [[ "$WEB_DIR" = /* ]]; then
  DISPLAY_WEB_DIR="$WEB_DIR"
else
  DISPLAY_WEB_DIR="client/$WEB_DIR"
fi

cat <<EOF
Web export written to $DISPLAY_WEB_DIR

Serve it locally:
  python3 scripts/serve-web.py --root $DISPLAY_WEB_DIR --port 8081

Production domain:
  https://$(cat "$ROOT_DIR/CNAME")
EOF
