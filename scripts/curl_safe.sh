#!/bin/sh
set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <output_file> <url>" >&2
    exit 1
fi

outfile="$1"
url="$2"

tmpfile=$(mktemp)

cleanup() {
    rm -f "$tmpfile"
}
trap cleanup INT TERM

if curl -sSf --remove-on-error -L -o "$tmpfile" "$url"; then
    mv "$tmpfile" "$outfile"
    echo "Saved to $outfile"
else
    status=$?
    cleanup
    echo "Download failed" >&2
    exit "$status"
fi
