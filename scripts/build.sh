#!/usr/bin/env bash
# Build the static site into site/ exactly as CI does.
#
# --strict turns broken links and unrecognised references into failures, which is
# the whole point of running this before pushing.
set -euo pipefail

cd "$(dirname "$0")/.."

MKDOCS="mkdocs"
[[ -x .venv/bin/mkdocs ]] && MKDOCS=".venv/bin/mkdocs"

if ! command -v "$MKDOCS" >/dev/null 2>&1 && [[ ! -x "$MKDOCS" ]]; then
  echo "mkdocs not found. See scripts/serve.sh for setup instructions." >&2
  exit 1
fi

"$MKDOCS" build --strict "$@"
echo "Site built into site/"
