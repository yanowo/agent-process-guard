#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${PROCESS_GUARD_RUN_DIR:-.agent-run}"
PID_DIR="$RUN_DIR/pids"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$PID_DIR" ]; then
  echo "No managed PID directory found"
  exit 0
fi

found=0
for f in "$PID_DIR"/*.pid; do
  [ -e "$f" ] || continue
  found=1
  name="$(basename "$f" .pid)"
  "$SCRIPT_DIR/stop-managed-process.sh" --name "$name" || true
done

if [ "$found" -eq 0 ]; then
  echo "No managed processes found"
fi
