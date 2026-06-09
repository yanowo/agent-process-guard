#!/usr/bin/env bash
set -euo pipefail

NAME=""
GRACE_SECONDS=5

usage() {
  echo "Usage: stop-managed-process.sh --name name [--grace seconds]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --grace) GRACE_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$NAME" ]; then
  usage
  exit 2
fi

RUN_DIR="${PROCESS_GUARD_RUN_DIR:-.agent-run}"
PIDFILE="$RUN_DIR/pids/${NAME}.pid"
METAFILE="$RUN_DIR/meta/${NAME}.env"

if [ ! -f "$PIDFILE" ]; then
  echo "No PID file found for $NAME"
  exit 0
fi

pid="$(cat "$PIDFILE" 2>/dev/null || true)"
if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
  echo "Invalid PID in $PIDFILE: $pid" >&2
  rm -f "$PIDFILE" "$METAFILE"
  exit 1
fi

is_alive() {
  kill -0 "$1" 2>/dev/null
}

kill_tree() {
  local target="$1"
  [ -n "$target" ] || return 0

  kill -TERM -"$target" 2>/dev/null || true
  kill -TERM "$target" 2>/dev/null || true
  sleep "$GRACE_SECONDS"

  if command -v pgrep >/dev/null 2>&1; then
    local children
    children="$(pgrep -P "$target" 2>/dev/null || true)"
    if [ -n "$children" ]; then
      for child in $children; do
        kill_tree "$child" || true
      done
    fi
  fi

  kill -KILL -"$target" 2>/dev/null || true
  kill -KILL "$target" 2>/dev/null || true
}

if is_alive "$pid"; then
  kill_tree "$pid"
  sleep 1
  if is_alive "$pid"; then
    echo "Warning: PID $pid for $NAME still appears alive after cleanup" >&2
  else
    echo "Stopped $NAME PID $pid"
  fi
else
  echo "PID $pid for $NAME was not running"
fi

rm -f "$PIDFILE" "$METAFILE"
