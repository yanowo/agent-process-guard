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
  if is_alive "$pid"; then
    status="running"
  fi
  log="$LOG_DIR/${name}.log"
  port=""
  health=""
  meta="$META_DIR/${name}.env"
  if [ -f "$meta" ]; then
    while IFS='=' read -r key value; do
      case "$key" in
        PORT) port="$value" ;;
        HEALTH_URL) health="$value" ;;
        LOG) log="$value" ;;
      esac
    done < "$meta"
  fi
  printf '%s\tPID=%s\t%s\tlog=%s' "$name" "${pid:-unknown}" "$status" "$log"
  [ -n "$port" ] && printf '\tport=%s' "$port"
  [ -n "$health" ] && printf '\thealth=%s' "$health"
  printf '\n'
done

if [ "$found" -eq 0 ]; then
  echo "No managed processes found"
fi
