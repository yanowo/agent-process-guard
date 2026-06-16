#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

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

need_value() {
  if [ "$#" -lt 2 ]; then
    echo "Missing value for $1" >&2
    usage
    exit 2
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout) need_value "$@"; TIMEOUT_SECONDS="$2"; shift 2 ;;
    --log-name) need_value "$@"; LOG_NAME="$2"; shift 2 ;;
    --) shift; break ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi

mkdir -p "$LOG_DIR"

if [ -n "$LOG_NAME" ]; then
  if ! [[ "$LOG_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Invalid log name: $LOG_NAME" >&2
    exit 2
  fi
  LOG="$LOG_DIR/${LOG_NAME}.once.log"
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
  RUN_CMD=("$@")
  if command -v setsid >/dev/null 2>&1; then
    RUN_CMD=(setsid "$@")
  fi

  if [ -n "$LOG" ]; then
    "${RUN_CMD[@]}" > >(tee "$LOG") 2> >(tee -a "$LOG" >&2) &
  else
    "${RUN_CMD[@]}" &
  fi
  pid=$!
  (
    sleep "$TIMEOUT_SECONDS"
    if pid_exists "$pid"; then
      echo "Command timed out after ${TIMEOUT_SECONDS}s. Terminating PID $pid" >&2
      kill_tree "$pid" 5
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
