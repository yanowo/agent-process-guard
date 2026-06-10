#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

if [ ! -d "$PID_DIR" ]; then
  echo "No managed PID directory found"
  exit 0
fi

found=0
for f in "$PID_DIR"/*.pid; do
  [ -e "$f" ] || continue
  found=1
  name="$(basename "$f" .pid)"
  stop_managed_process "$name" || true
done

if [ "$found" -eq 0 ]; then
  echo "No managed processes found"
fi
