#!/usr/bin/env bash
set -euo pipefail

if ! command -v mmdc >/dev/null 2>&1; then
  echo "mmdc not found. Install Mermaid CLI first: npm i -g @mermaid-js/mermaid-cli"
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for src in "$DIR"/*.mmd; do
  base="${src%.mmd}"
  mmdc -i "$src" -o "${base}.svg" -t neutral -b transparent
  mmdc -i "$src" -o "${base}.png" -t neutral -b white -w 2200
  echo "Generated: ${base}.svg and ${base}.png"
done
