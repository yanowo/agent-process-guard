#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

START_ARGS=()
CHECK_COMMAND=""
NAME=""
GRACE_SECONDS=5

usage() {
  cat >&2 <<'USAGE'
Usage:
  with-managed-process.sh --name name --command 'long-running cmd' [readiness options] -- 'check command'

Example:
  with-managed-process.sh --name web --command 'pnpm dev --port 3000' --port 3000 -- 'curl -fsS http://127.0.0.1:3000'
USAGE
}

if [ "$#" -eq 0 ]; then
  usage
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

  case "$1" in
    --name|--command|--port|--health-url|--ready-command|--ready-log-pattern|--timeout|--cwd|--grace)
      need_value "$@"
      if [ "$1" = "--name" ]; then
        NAME="$2"
      elif [ "$1" = "--grace" ]; then
        GRACE_SECONDS="$2"
      fi
      START_ARGS+=("$1" "$2")
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      START_ARGS+=("$1")
      shift
      ;;
  esac
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
  trap - EXIT INT TERM
  stop_managed_process "$NAME" "$GRACE_SECONDS" || true
}
trap cleanup EXIT INT TERM

"$SCRIPT_DIR/start-managed-process.sh" "${START_ARGS[@]}"
bash -lc "$CHECK_COMMAND"
