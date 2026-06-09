#!/usr/bin/env bash
set -euo pipefail

TIMEOUT_SECONDS=120
LOG_NAME=""

usage() {
  cat >&2 <<'USAGE'
Usage:
  guarded-run.sh [--timeout seconds] [--log-name name] -- <command> [args...]

Examples:
  guarded-run.sh --timeout 120 -- npm test
  guarded-run.sh --timeout 180 --log-name build -- bash -lc 'pnpm build'
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout) TIMEOUT_SECONDS="$2"; shift 2 ;;
    --log-name) LOG_NAME="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi

RUN_DIR="${PROCESS_GUARD_RUN_DIR:-.agent-run}"
mkdir -p "$RUN_DIR/logs"

if [ -n "$LOG_NAME" ]; then
  if ! [[ "$LOG_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid log name: $LOG_NAME" >&2
    exit 2
  fi
  LOG="$RUN_DIR/logs/${LOG_NAME}.once.log"
else
  LOG=""
fi

run_command() {
  if [ -n "$LOG" ]; then
    "$@" > >(tee "$LOG") 2> >(tee -a "$LOG" >&2)
  else
    "$@"
  fi
}

if command -v timeout >/dev/null 2>&1; then
  run_command timeout --preserve-status --kill-after=5s "${TIMEOUT_SECONDS}s" "$@"
else
  if [ -n "$LOG" ]; then
    "$@" > >(tee "$LOG") 2> >(tee -a "$LOG" >&2) &
  else
    "$@" &
  fi
  pid=$!
  (
    sleep "$TIMEOUT_SECONDS"
    if kill -0 "$pid" 2>/dev/null; then
      echo "Command timed out after ${TIMEOUT_SECONDS}s. Terminating PID $pid" >&2
      kill "$pid" 2>/dev/null || true
      sleep 5
      kill -9 "$pid" 2>/dev/null || true
    fi
  ) &
  watcher=$!
  set +e
  wait "$pid"
  status=$?
  set -e
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  exit "$status"
fi
