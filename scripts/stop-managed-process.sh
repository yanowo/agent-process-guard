#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

NAME=""
GRACE_SECONDS=5

usage() {
  echo "Usage: stop-managed-process.sh --name name [--grace seconds]" >&2
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
    --name) need_value "$@"; NAME="$2"; shift 2 ;;
    --grace) need_value "$@"; GRACE_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$NAME" ]; then
  usage
  exit 2
fi

stop_managed_process "$NAME" "$GRACE_SECONDS"
