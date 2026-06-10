#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_ARGS=()
CHECK_COMMAND=""
NAME=""

if [ "$#" -eq 0 ]; then
  cat >&2 <<'USAGE'
Usage:
  with-managed-process.sh --name name --command 'long-running cmd' [readiness options] -- 'check command'

Example:
  with-managed-process.sh --name web --command 'pnpm dev --port 3000' --port 3000 -- 'curl -fsS http://127.0.0.1:3000'
USAGE
  exit 2
fi

# Everything before `--` is forwarded verbatim to start-managed-process.sh (the
# single authority on its own flags); everything after `--` is the check command.
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--" ]; then
    shift
    CHECK_COMMAND="$*"
    break
  fi
  if [ "$1" = "--name" ]; then
    NAME="$2"
  fi
  START_ARGS+=("$1")
  shift
done

if [ -z "$NAME" ]; then
  echo "with-managed-process requires --name" >&2
  exit 2
fi

if [ -z "$CHECK_COMMAND" ]; then
  echo "with-managed-process requires a check command after --" >&2
  exit 2
fi

cleanup() {
  "$SCRIPT_DIR/stop-managed-process.sh" --name "$NAME" || true
}
trap cleanup EXIT INT TERM

"$SCRIPT_DIR/start-managed-process.sh" "${START_ARGS[@]}"
bash -lc "$CHECK_COMMAND"
