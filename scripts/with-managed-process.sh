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
  if [ "$#" -gt 0 ] && [ "${START_ARGS[-1]}" != "--help" ]; then
    case "${START_ARGS[-1]}" in
      --name|--command|--port|--health-url|--ready-command|--ready-log-pattern|--timeout|--cwd|--grace)
        START_ARGS+=("$1")
        shift
        ;;
    esac
  fi
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
