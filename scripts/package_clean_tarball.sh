#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-/tmp/observabilidade-stack.tar.gz}"

mkdir -p "$(dirname "$OUTPUT_PATH")"

# Avoid AppleDouble metadata files when packaging from macOS.
COPYFILE_DISABLE=1 tar \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='._*' \
  -czf "$OUTPUT_PATH" \
  -C "$(dirname "$ROOT_DIR")" \
  "$(basename "$ROOT_DIR")"

echo "Tarball created at: $OUTPUT_PATH"
