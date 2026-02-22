#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
BIN_DIR="$OPENCLAW_HOME/bin"

CHECK_MODE=0
for arg in "$@"; do
  case "$arg" in
    --check)
      CHECK_MODE=1
      ;;
    -h|--help)
      echo "Usage: ./uninstall.sh [--check]"
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg" >&2
      exit 1
      ;;
  esac
done

check_status() {
  local failures=0
  [ ! -e "$BIN_DIR/backup.sh" ] || { echo "- Still present: $BIN_DIR/backup.sh"; failures=1; }
  [ ! -e "$BIN_DIR/backup-memory.sh" ] || { echo "- Still present: $BIN_DIR/backup-memory.sh"; failures=1; }
  [ ! -e "$BIN_DIR/backup-apply" ] || { echo "- Still present: $BIN_DIR/backup-apply"; failures=1; }

  if [ "$(uname -s)" = "Darwin" ]; then
    [ ! -e "$HOME/Library/LaunchAgents/com.openclaw.daily-backup.plist" ] || { echo "- Launchd plist still present"; failures=1; }
  else
    [ ! -e "$HOME/.config/systemd/user/openclaw-backup.service" ] || { echo "- Systemd service still present"; failures=1; }
    [ ! -e "$HOME/.config/systemd/user/openclaw-backup.timer" ] || { echo "- Systemd timer still present"; failures=1; }
  fi

  if [ "$failures" -eq 0 ]; then
    echo "Uninstall check passed."
  else
    echo "Uninstall check failed."
  fi

  return "$failures"
}

if [ "$CHECK_MODE" -eq 1 ]; then
  check_status
  exit $?
fi

rm -f "$BIN_DIR/backup.sh" "$BIN_DIR/backup-memory.sh" "$BIN_DIR/backup-apply"

if [ "$(uname -s)" = "Darwin" ]; then
  PLIST="$HOME/Library/LaunchAgents/com.openclaw.daily-backup.plist"
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  rm -f "$PLIST"
else
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now openclaw-backup.timer >/dev/null 2>&1 || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  rm -f "$HOME/.config/systemd/user/openclaw-backup.service"
  rm -f "$HOME/.config/systemd/user/openclaw-backup.timer"
fi

echo "OpenClaw backup uninstall complete."
