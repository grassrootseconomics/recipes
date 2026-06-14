#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export HOST="${HOST:-127.0.0.1}"
export PORT="${PORT:-3000}"

npm run build
node server/dist/index.js
