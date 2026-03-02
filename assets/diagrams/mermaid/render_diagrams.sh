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

# explains what the script does
# This script renders Mermaid diagrams from .mmd files to .svg and .png formats.
# It uses the Mermaid CLI tool (mmdc) to perform the rendering.
# The script checks if mmdc is installed, and if not, it prompts the user
# to install it. Then, it iterates over all .mmd files in the current directory,
# rendering each one to both .svg and .png formats with specified themes and backgrounds.
