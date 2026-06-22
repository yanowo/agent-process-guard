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
  pid="$(cat "$f" 2>/dev/null || true)"
  status="stopped"
  if pid_exists "$pid"; then
    status="running"
  fi
  log="$LOG_DIR/${name}.log"
  port=""
  health=""
  meta="$META_DIR/${name}.env"
  if [ -r "$meta" ]; then
    # Single pass over the scalar fields. Stop at COMMAND, which is written last
    # and may span multiple lines, so it can't pollute the fields above it.
    {
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          COMMAND=*) break ;;
          PORT=*) port="${line#*=}" ;;
          HEALTH_URL=*) health="${line#*=}" ;;
          LOG=*) log="${line#*=}" ;;
        esac
      done < "$meta"
    } 2>/dev/null || true
  fi
  printf '%s\tPID=%s\t%s\tlog=%s' "$name" "${pid:-unknown}" "$status" "$log"
  [ -n "$port" ] && printf '\tport=%s' "$port"
  [ -n "$health" ] && printf '\thealth=%s' "$health"
  printf '\n'
done

if [ "$found" -eq 0 ]; then
  echo "No managed processes found"
fi
