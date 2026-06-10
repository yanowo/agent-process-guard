#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

NAME=""
COMMAND=""
PORT=""
HEALTH_URL=""
READY_COMMAND=""
READY_LOG_PATTERN=""
TIMEOUT_SECONDS=60
CWD=""
GRACE_SECONDS=5

usage() {
  cat >&2 <<'USAGE'
Usage:
  start-managed-process.sh --name name --command 'cmd' [options]

Options:
  --port port                    Wait for TCP listener on 127.0.0.1:port
  --health-url url               Wait for HTTP 2xx/3xx response
  --ready-command 'cmd'          Wait until this command exits 0
  --ready-log-pattern 'regex'    Wait until regex appears in the log
  --timeout seconds              Readiness timeout, default 60
  --cwd path                     Run command from a specific working directory
  --grace seconds                Grace period before force kill on failure, default 5
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --command) COMMAND="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --health-url) HEALTH_URL="$2"; shift 2 ;;
    --ready-command) READY_COMMAND="$2"; shift 2 ;;
    --ready-log-pattern) READY_LOG_PATTERN="$2"; shift 2 ;;
    --timeout) TIMEOUT_SECONDS="$2"; shift 2 ;;
    --cwd) CWD="$2"; shift 2 ;;
    --grace) GRACE_SECONDS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$NAME" ] || [ -z "$COMMAND" ]; then
  usage
  exit 2
fi

if ! [[ "$NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Invalid process name: $NAME" >&2
  exit 2
fi

if [ -n "$PORT" ] && ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Invalid port: $PORT" >&2
  exit 2
fi

mkdir -p "$LOG_DIR" "$PID_DIR" "$META_DIR"

LOG="$LOG_DIR/${NAME}.log"
PIDFILE="$PID_DIR/${NAME}.pid"
METAFILE="$META_DIR/${NAME}.env"

# Probe 127.0.0.1:port with a short-lived TCP connect (fallback when no CLI tool).
_tcp_connect() {
  python3 - "$1" "$2" <<'PY' >/dev/null 2>&1
import socket, sys
s = socket.socket()
s.settimeout(float(sys.argv[2]))
try:
    s.connect(("127.0.0.1", int(sys.argv[1])))
    sys.exit(0)
except Exception:
    sys.exit(1)
finally:
    s.close()
PY
}

port_listening() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$"
  else
    _tcp_connect "$port" 0.5
  fi
}

tcp_probe() {
  local port="$1"
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$port" >/dev/null 2>&1
  else
    _tcp_connect "$port" 1
  fi
}

http_probe() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 2 "$url" >/dev/null 2>&1
  else
    python3 - "$url" <<'PY' >/dev/null 2>&1
import sys, urllib.request
try:
    with urllib.request.urlopen(sys.argv[1], timeout=2) as r:
        sys.exit(0 if 200 <= r.status < 400 else 1)
except Exception:
    sys.exit(1)
PY
  fi
}

if [ -f "$PIDFILE" ]; then
  old_pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  if is_alive "$old_pid"; then
    echo "Managed process '$NAME' already running with PID $old_pid" >&2
    echo "Use scripts/stop-managed-process.sh --name $NAME before starting it again." >&2
    exit 1
  fi
  rm -f "$PIDFILE" "$METAFILE"
fi

if [ -n "$PORT" ] && port_listening "$PORT"; then
  echo "Port $PORT is already listening before starting '$NAME'." >&2
  echo "Refusing to kill unknown processes. Choose another port or stop the existing service explicitly." >&2
  exit 1
fi

: > "$LOG"

STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
RUN_CWD="${CWD:-$(pwd)}"

pushd "$RUN_CWD" >/dev/null
if command -v setsid >/dev/null 2>&1; then
  setsid bash -lc "$COMMAND" >> "$LOG" 2>&1 &
else
  bash -lc "$COMMAND" >> "$LOG" 2>&1 &
fi
pid=$!
popd >/dev/null

echo "$pid" > "$PIDFILE"
cat > "$METAFILE" <<META
NAME=$NAME
PID=$pid
PORT=$PORT
HEALTH_URL=$HEALTH_URL
LOG=$LOG
COMMAND=$COMMAND
CWD=$RUN_CWD
STARTED_AT=$STARTED_AT
META

has_readiness=0
if [ -n "$HEALTH_URL$PORT$READY_COMMAND$READY_LOG_PATTERN" ]; then
  has_readiness=1
fi

fail_exited_before_readiness() {
  echo "Process '$NAME' exited before readiness. Last logs:" >&2
  tail -120 "$LOG" >&2 || true
  wait "$pid" 2>/dev/null || true
  rm -f "$PIDFILE" "$METAFILE"
  exit 1
}

confirm_ready() {
  sleep 1
  is_alive "$pid"
}

if [ "$has_readiness" -eq 1 ]; then
  ready=0
  for _ in $(seq 1 "$TIMEOUT_SECONDS"); do
    if ! is_alive "$pid"; then
      fail_exited_before_readiness
    fi

    if [ -n "$HEALTH_URL" ] && http_probe "$HEALTH_URL" && confirm_ready; then
      ready=1
      break
    fi

    if [ -n "$PORT" ] && tcp_probe "$PORT" && confirm_ready; then
      ready=1
      break
    fi

    if [ -n "$READY_COMMAND" ] && bash -lc "$READY_COMMAND" >/dev/null 2>&1 && confirm_ready; then
      ready=1
      break
    fi

    if [ -n "$READY_LOG_PATTERN" ] && grep -E "$READY_LOG_PATTERN" "$LOG" >/dev/null 2>&1 && confirm_ready; then
      ready=1
      break
    fi

    if ! is_alive "$pid"; then
      fail_exited_before_readiness
    fi
    sleep 1
  done

  if [ "$ready" -ne 1 ]; then
    echo "Process '$NAME' did not become ready within ${TIMEOUT_SECONDS}s. Last logs:" >&2
    tail -120 "$LOG" >&2 || true
    kill_tree "$pid" "$GRACE_SECONDS"
    rm -f "$PIDFILE" "$METAFILE"
    exit 1
  fi
else
  sleep 2
  if ! is_alive "$pid"; then
    echo "Process '$NAME' exited immediately. Last logs:" >&2
    tail -120 "$LOG" >&2 || true
    rm -f "$PIDFILE" "$METAFILE"
    exit 1
  fi
  echo "Warning: no readiness check was provided. Process is alive but readiness is unverified." >&2
fi

echo "Started $NAME"
echo "PID: $pid"
echo "Log: $LOG"
[ -n "$PORT" ] && echo "Port: $PORT"
[ -n "$HEALTH_URL" ] && echo "Health URL: $HEALTH_URL"
exit 0
