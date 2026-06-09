#!/usr/bin/env bash
set -euo pipefail

TARGET="both"
SCOPE="user"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat >&2 <<'USAGE'
Usage:
  install.sh [--target codex|claude|both] [--scope user|project]

Examples:
  scripts/install.sh --target both --scope user
  scripts/install.sh --target codex --scope project
  scripts/install.sh --target claude --scope project
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$TARGET" in codex|claude|both) ;; *) echo "Invalid target: $TARGET" >&2; exit 2 ;; esac
case "$SCOPE" in user|project) ;; *) echo "Invalid scope: $SCOPE" >&2; exit 2 ;; esac

copy_skill() {
  local dest_root="$1"
  local dest="$dest_root/process-guard"
  mkdir -p "$dest_root"
  rm -rf "$dest"
  mkdir -p "$dest"
  tar -C "$SOURCE_DIR" \
    --exclude='./.git' \
    --exclude='./.agent-run' \
    --exclude='./.codex-run' \
    --exclude='./.agents' \
    --exclude='./.claude' \
    --exclude='*.zip' \
    -cf - . | tar -C "$dest" -xf -
  echo "Installed process-guard to $dest"
}

if [ "$TARGET" = "codex" ] || [ "$TARGET" = "both" ]; then
  if [ "$SCOPE" = "user" ]; then
    copy_skill "$HOME/.agents/skills"
  else
    copy_skill ".agents/skills"
  fi
fi

if [ "$TARGET" = "claude" ] || [ "$TARGET" = "both" ]; then
  if [ "$SCOPE" = "user" ]; then
    copy_skill "$HOME/.claude/skills"
  else
    copy_skill ".claude/skills"
  fi
fi
