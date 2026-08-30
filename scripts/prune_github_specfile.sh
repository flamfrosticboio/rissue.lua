#!/usr/bin/env bash
set -euo pipefail

SPEC_FILE="$1"

if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
  echo "Error: pass a valid path to the spec .json file" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${REDOCLY_CONFIG:-$SCRIPT_DIR/redocly.yaml}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: redocly.yaml not found at $CONFIG_FILE" >&2
  echo "Place your filter-out config there, or set REDOCLY_CONFIG=/path/to/redocly.yaml" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BUNDLED="$TMP_DIR/bundled.json"
PRUNED="$TMP_DIR/pruned.json"

REDOCLY="$SCRIPT_DIR/../test/api/node_modules/.bin/redocly"

echo "==> Step 1: Dereferencing"
"$REDOCLY" bundle "$SPEC_FILE" -o "$BUNDLED" --dereferenced

echo "==> Step 2: Pruning paths (filter-out via config)"
"$REDOCLY" bundle "$BUNDLED" -o "$PRUNED" --config "$CONFIG_FILE"

echo "==> Step 3: Linting pruned spec"
"$REDOCLY" lint "$PRUNED" --config "$CONFIG_FILE"

echo "==> Replacing original file with pruned result"
cp "$PRUNED" "$SPEC_FILE"

echo "Done."
