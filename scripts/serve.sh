#!/usr/bin/env bash
# Live-reloading preview of the handbook at http://127.0.0.1:8000
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -x .venv/bin/mkdocs ]]; then
  exec .venv/bin/mkdocs serve "$@"
fi

if ! command -v mkdocs >/dev/null 2>&1; then
  echo "mkdocs not found. Set up the toolchain first:" >&2
  echo "  python -m venv .venv && source .venv/bin/activate" >&2
  echo "  pip install -r requirements.txt" >&2
  exit 1
fi

exec mkdocs serve "$@"
