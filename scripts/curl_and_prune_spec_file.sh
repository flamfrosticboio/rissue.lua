#!/usr/bin/env bash
set -euo pipefail

FILENAME="${1:-}"
URL="${2:-}"

if [ -z "$FILENAME" ] || [ -z "$URL" ]; then
  echo "Usage: $0 <filename> <url>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CURL_SAFE="$SCRIPT_DIR/curl_safe.sh"
PRUNE_GITHUB="$SCRIPT_DIR/prune_github_specfile.sh"

: "${REDOCLY_CONFIG:="$SCRIPT_DIR/../test/api/github/redocly.yaml"}"
export REDOCLY_CONFIG

if [ ! -f "$CURL_SAFE" ]; then
  echo "Error: $CURL_SAFE not found" >&2
  exit 1
fi

if [ ! -f "$PRUNE_GITHUB" ]; then
  echo "Error: $PRUNE_GITHUB not found" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TMPFILE="$TMP_DIR/$(basename "$FILENAME")"

echo "==> Fetching $URL -> $TMPFILE"
OUTFILE="$TMPFILE" "$CURL_SAFE" "$URL"

echo "==> Pruning $TMPFILE (config: $REDOCLY_CONFIG)"
"$PRUNE_GITHUB" "$TMPFILE"

echo "==> Moving pruned result to $FILENAME"
mv "$TMPFILE" "$FILENAME"

echo "Done. $FILENAME is ready."
