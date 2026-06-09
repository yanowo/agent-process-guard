#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="${PROCESS_GUARD_RUN_DIR:-.agent-run}"
PID_DIR="$RUN_DIR/pids"
META_DIR="$RUN_DIR/meta"

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
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    status="running"
  fi
  log="$RUN_DIR/logs/${name}.log"
  port=""
  health=""
  meta="$META_DIR/${name}.env"
  if [ -f "$meta" ]; then
    port="$(grep '^PORT=' "$meta" | sed 's/^PORT=//' || true)"
    health="$(grep '^HEALTH_URL=' "$meta" | sed 's/^HEALTH_URL=//' || true)"
    log="$(grep '^LOG=' "$meta" | sed 's/^LOG=//' || echo "$log")"
  fi
  printf '%s\tPID=%s\t%s\tlog=%s' "$name" "${pid:-unknown}" "$status" "$log"
  [ -n "$port" ] && printf '\tport=%s' "$port"
  [ -n "$health" ] && printf '\thealth=%s' "$health"
  printf '\n'
done

if [ "$found" -eq 0 ]; then
  echo "No managed processes found"
fi
