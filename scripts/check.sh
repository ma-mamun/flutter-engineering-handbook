#!/usr/bin/env bash
# Everything CI runs, in one command.
#
# The Dart steps are skipped when no Flutter SDK is present, so a docs-only
# contributor needs Python and nothing else. Skipping is reported, never silent.
set -euo pipefail

cd "$(dirname "$0")/.."

failed=0
step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\033[31mFAILED: %s\033[0m\n' "$1"; failed=1; }

step "Building docs (mkdocs build --strict)"
if ! ./scripts/build.sh >/dev/null; then
  fail "docs build"
else
  echo "ok"
fi

if command -v flutter >/dev/null 2>&1; then
  step "Installing Dart dependencies"
  (cd code && flutter pub get >/dev/null) || fail "flutter pub get"

  step "Checking formatting (dart format)"
  (cd code && dart format --output=none --set-exit-if-changed .) || fail "dart format"

  step "Analyzing (flutter analyze)"
  (cd code && flutter analyze) || fail "flutter analyze"

  step "Testing (flutter test)"
  (cd code && flutter test testing) || fail "flutter test"
else
  step "Dart checks"
  echo "SKIPPED — no Flutter SDK on PATH."
  echo "Install Flutter to run format, analyze, and test locally:"
  echo "  https://docs.flutter.dev/get-started/install"
fi

if (( failed )); then
  printf '\n\033[31mSome checks failed.\033[0m\n'
  exit 1
fi

printf '\n\033[32mAll checks passed.\033[0m\n'
