#!/usr/bin/env bash
# Create a new handbook page from the standard template.
#
# Usage: ./scripts/new-page.sh part-04-production shader-jank "Shader Jank"
#
# Creates docs/<part>/<slug>.md. Adding it to the nav in mkdocs.yml is still
# manual and deliberate — nav order is an editorial decision, not a filesystem one.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <part-directory> <slug> <Page Title>" >&2
  echo "Example: $0 part-01-foundations keys \"Keys and Identity\"" >&2
  exit 1
fi

part="$1"
slug="$2"
shift 2
title="$*"
path="docs/${part}/${slug}.md"

if [[ ! -d "docs/${part}" ]]; then
  echo "No such part directory: docs/${part}" >&2
  echo "Existing parts:" >&2
  find docs -maxdepth 1 -type d -name 'part-*' -o -maxdepth 1 -type d -name 'appendix' \
    -o -maxdepth 1 -type d -name 'cheatsheets' | sed 's|^docs/|  |' >&2
  exit 1
fi

if [[ -e "$path" ]]; then
  echo "Refusing to overwrite existing page: $path" >&2
  exit 1
fi

cat > "$path" <<TEMPLATE
# ${title}

One or two sentences: what this page answers and who needs it.

## The recommendation

What to do, stated plainly, in the first paragraph.

## Why

The reasoning. Mechanism, not assertion.

## The cost

What this buys you and what it charges. Non-negotiable section — see the
[style guide](../style-guide.md).

## When not to use it

The cases where the recommendation is wrong.

## See also

-
TEMPLATE

echo "Created $path"
echo "Next: add it to the nav in mkdocs.yml"
