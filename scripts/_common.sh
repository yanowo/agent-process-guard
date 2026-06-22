#!/usr/bin/env bash
# Shared helpers for process-guard scripts.
# Source from a sibling script with:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/_common.sh"

# Run-dir layout. Single source of truth for where state lives on disk.
RUN_DIR="${PROCESS_GUARD_RUN_DIR:-.agent-run}"
LOG_DIR="$RUN_DIR/logs"
PID_DIR="$RUN_DIR/pids"
META_DIR="$RUN_DIR/meta"

# Guard that a value-taking flag ("$1") was actually given an argument ("$2").
# Relies on the sourcing script defining usage(), resolved by dynamic scoping
# at call time.
need_value() {
  if [ "$#" -lt 2 ]; then
    echo "Missing value for $1" >&2
    usage
    exit 2
  fi
}

# Does the given PID still exist from the kernel's point of view?
pid_exists() {
  local pid="$1"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

# Is the given PID a live, non-zombie process?
is_alive() {
  local pid="$1"
  pid_exists "$pid" || return 1

  if command -v ps >/dev/null 2>&1; then
    local state
    state="$(ps -o stat= -p "$pid" 2>/dev/null | tr -d ' ' || true)"
    case "$state" in
      Z*) return 1 ;;
    esac
  fi

  return 0
}

# Terminate a process and its descendants: TERM the group, recurse into
# children, then KILL anything still standing after the grace period.
kill_tree() {
  local target="$1" grace="${2:-5}"
  [ -n "$target" ] || return 0

  # Process-group termination first (start-managed-process uses setsid when available).
  kill -TERM -"$target" 2>/dev/null || true
  kill -TERM "$target" 2>/dev/null || true
  sleep "$grace"

  # Recurse into any children the group signal did not reach.
  if command -v pgrep >/dev/null 2>&1; then
    local child
    for child in $(pgrep -P "$target" 2>/dev/null || true); do
      kill_tree "$child" "$grace" || true
    done
  fi

  kill -KILL -"$target" 2>/dev/null || true
  kill -KILL "$target" 2>/dev/null || true
}

# Stop a managed process by name: terminate its tree and clear its state files.
stop_managed_process() {
  local name="$1" grace="${2:-5}"
  local pidfile="$PID_DIR/${name}.pid"
  local metafile="$META_DIR/${name}.env"

  if [ ! -f "$pidfile" ]; then
    echo "No PID file found for $name"
    return 0
  fi

  local pid
  pid="$(cat "$pidfile" 2>/dev/null || true)"
  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    echo "Invalid PID in $pidfile: $pid" >&2
    rm -f "$pidfile" "$metafile"
    return 1
  fi

  if pid_exists "$pid"; then
    kill_tree "$pid" "$grace"
    sleep 1
    if is_alive "$pid"; then
      echo "Warning: PID $pid for $name still appears alive after cleanup" >&2
    else
      echo "Stopped $name PID $pid"
    fi
  else
    echo "PID $pid for $name was not running"
  fi

  rm -f "$pidfile" "$metafile"
}
