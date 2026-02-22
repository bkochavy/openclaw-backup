#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
BIN_DIR="$OPENCLAW_HOME/bin"
CONFIG_FILE="$OPENCLAW_HOME/backup.json"
TMP_REPO=""

SETUP_MODE=0
QUIET_MODE=0
CHECK_MODE=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--setup] [--quiet] [--check]

Flags:
  --setup   Run interactive setup wizard
  --quiet   Use defaults without prompts
  --check   Verify existing installation only
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --setup)
      SETUP_MODE=1
      ;;
    --quiet)
      QUIET_MODE=1
      ;;
    --check)
      CHECK_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

json_get() {
  local key="$1"
  local default_value="$2"
  python3 - "$CONFIG_FILE" "$key" "$default_value" <<'PY'
import json
import os
import sys

config_file, key, default_value = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(os.path.expanduser(config_file), "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception:
    print(default_value)
    sys.exit(0)

value = data
for part in key.split('.'):
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        print(default_value)
        sys.exit(0)

if value is None:
    print(default_value)
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(str(value))
PY
}

expand_path() {
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.abspath(os.path.expandvars(os.path.expanduser(sys.argv[1]))))
PY
}

gh_authenticated() {
  command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1
}

fetch_if_needed() {
  if [ -f "$SCRIPT_DIR/scripts/backup.sh" ]; then
    return 0
  fi

  require_cmd curl
  require_cmd tar

  TMP_REPO="$(mktemp -d)"
  trap 'rm -rf "$TMP_REPO"' EXIT
  curl -fsSL "https://codeload.github.com/bkochavy/openclaw-backup/tar.gz/main" | tar -xz -C "$TMP_REPO"
  SCRIPT_DIR="$(find "$TMP_REPO" -mindepth 1 -maxdepth 1 -type d | head -1)"

  if [ ! -f "$SCRIPT_DIR/scripts/backup.sh" ]; then
    echo "Failed to fetch openclaw-backup scripts." >&2
    exit 1
  fi
}

write_config() {
  local backup_dir="$1"
  local memory_backup_dir="$2"
  local github_repo="$3"
  local github_user="$4"
  local telegram_chat_id="$5"
  local include_skills="$6"

  mkdir -p "$OPENCLAW_HOME"
  python3 - "$CONFIG_FILE" "$backup_dir" "$memory_backup_dir" "$github_repo" "$github_user" "$telegram_chat_id" "$include_skills" <<'PY'
import json
import os
import sys

(
    config_file,
    backup_dir,
    memory_backup_dir,
    github_repo,
    github_user,
    telegram_chat_id,
    include_skills,
) = sys.argv[1:]

cfg = {
    "backup_dir": backup_dir,
    "memory_backup_dir": memory_backup_dir,
    "github_repo": github_repo,
    "github_user": github_user,
    "telegram_bot_token_env": "TELEGRAM_BOT_TOKEN_AVA",
    "telegram_chat_id": telegram_chat_id,
    "backup_schedule": "04:00",
    "include_skills": include_skills.lower() in {"1", "true", "yes", "y"},
    "include_scripts": True,
    "include_launchd": True,
    "include_agents": True,
    "redact_env_values": True,
    "critical_files": [
        "openclaw/openclaw.json",
        "workspace-config/AGENTS.md",
        "workspace-config/SOUL.md",
        "agents/main-auth-profiles.json",
    ],
}

os.makedirs(os.path.dirname(os.path.expanduser(config_file)), exist_ok=True)
with open(os.path.expanduser(config_file), "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
}

run_setup_wizard() {
  python3 - "$CONFIG_FILE" <<'PY'
import json
import os
import subprocess
import sys

config_file = os.path.expanduser(sys.argv[1])

def prompt(text, default=""):
    suffix = f" [{default}]" if default else ""
    value = input(f"{text}{suffix}: ").strip()
    return value if value else default

def prompt_yes_no(text, default=True):
    hint = "Y/n" if default else "y/N"
    while True:
        value = input(f"{text} ({hint}): ").strip().lower()
        if not value:
            return default
        if value in {"y", "yes"}:
            return True
        if value in {"n", "no"}:
            return False
        print("Please answer y or n.")

def gh_user_default():
    try:
        out = subprocess.check_output(["gh", "api", "user", "--jq", ".login"], text=True, stderr=subprocess.DEVNULL)
        return out.strip()
    except Exception:
        return ""

def gh_auth_ok():
    try:
        subprocess.check_call(["gh", "auth", "status", "-h", "github.com"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False

backup_dir = prompt("Where should system config be backed up?", "~/backups/openclaw-system")
repo_name = prompt("GitHub repo name for offsite backup?", "openclaw-system-backup")
default_user = gh_user_default()
github_user = prompt("GitHub username?", default_user)
telegram_chat_id = prompt("Telegram chat ID for failure alerts?", "")
include_skills = prompt_yes_no("Include skill files in backup?", True)

if repo_name and (not github_user or not gh_auth_ok()):
    print("Run 'gh auth login' first, then re-run install.sh --setup")
    sys.exit(2)

print("\nPreview")
print(f"- System backup dir: {backup_dir}")
print("- System backup includes: OpenClaw config, workspace files, agents, scripts, launchd/systemd")
print(f"- Include skills: {'yes' if include_skills else 'no'}")
if repo_name and github_user:
    print(f"- GitHub backup repo: github.com/{github_user}/{repo_name} (private)")
else:
    print("- GitHub backup repo: disabled")
print("- Memory backup: ~/backups/openclaw-memory (local only)")

if not prompt_yes_no("Confirm and write config?", True):
    print("Setup cancelled.")
    sys.exit(3)

cfg = {
    "backup_dir": backup_dir,
    "memory_backup_dir": "~/backups/openclaw-memory",
    "github_repo": repo_name,
    "github_user": github_user,
    "telegram_bot_token_env": "TELEGRAM_BOT_TOKEN_AVA",
    "telegram_chat_id": telegram_chat_id,
    "backup_schedule": "04:00",
    "include_skills": include_skills,
    "include_scripts": True,
    "include_launchd": True,
    "include_agents": True,
    "redact_env_values": True,
    "critical_files": [
        "openclaw/openclaw.json",
        "workspace-config/AGENTS.md",
        "workspace-config/SOUL.md",
        "agents/main-auth-profiles.json",
    ],
}

os.makedirs(os.path.dirname(config_file), exist_ok=True)
with open(config_file, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PY
}

write_quiet_config_if_needed() {
  local default_user=""
  if gh_authenticated; then
    default_user="$(gh api user --jq .login 2>/dev/null || true)"
  fi

  local repo_name=""
  if [ -n "$default_user" ]; then
    repo_name="openclaw-system-backup"
  fi

  write_config "~/backups/openclaw-system" "~/backups/openclaw-memory" "$repo_name" "$default_user" "" "true"
}

install_scripts() {
  mkdir -p "$BIN_DIR"
  cp "$SCRIPT_DIR/scripts/backup.sh" "$BIN_DIR/backup.sh"
  cp "$SCRIPT_DIR/scripts/backup-memory.sh" "$BIN_DIR/backup-memory.sh"

  cat > "$BIN_DIR/backup-apply" <<EOF2
#!/usr/bin/env bash
set -euo pipefail
OPENCLAW_HOME="\${OPENCLAW_HOME:-$OPENCLAW_HOME}"
OPENCLAW_BACKUP_CONFIG="\${OPENCLAW_BACKUP_CONFIG:-$CONFIG_FILE}"
"\$OPENCLAW_HOME/bin/backup.sh"
"\$OPENCLAW_HOME/bin/backup-memory.sh"
EOF2

  chmod +x "$BIN_DIR/backup.sh" "$BIN_DIR/backup-memory.sh" "$BIN_DIR/backup-apply"
}

ensure_github_repo() {
  local github_repo github_user
  github_repo="$(json_get github_repo "")"
  github_user="$(json_get github_user "")"

  if [ -z "$github_repo" ] || [ -z "$github_user" ]; then
    return 0
  fi

  if ! command -v gh >/dev/null 2>&1 || ! gh_authenticated; then
    echo "Run 'gh auth login' first, then re-run install.sh --setup" >&2
    exit 1
  fi

  if ! gh repo view "$github_user/$github_repo" >/dev/null 2>&1; then
    gh repo create "$github_user/$github_repo" --private --confirm >/dev/null
  fi
}

wire_launchd() {
  local schedule hour minute
  schedule="$(json_get backup_schedule "04:00")"
  if [[ ! "$schedule" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
    schedule="04:00"
  fi
  hour=$((10#${schedule%:*}))
  minute=$((10#${schedule#*:}))

  local template target
  template="$SCRIPT_DIR/templates/launchd/com.openclaw.daily-backup.plist.template"
  target="$HOME/Library/LaunchAgents/com.openclaw.daily-backup.plist"
  mkdir -p "$HOME/Library/LaunchAgents"

  python3 - "$template" "$target" "$OPENCLAW_HOME" "$hour" "$minute" <<'PY'
import pathlib
import sys

template, target, openclaw_home, hour, minute = sys.argv[1:]
text = pathlib.Path(template).read_text(encoding="utf-8")
text = text.replace("__OPENCLAW_HOME__", openclaw_home)
text = text.replace("__HOUR__", str(hour))
text = text.replace("__MINUTE__", str(minute))
pathlib.Path(target).write_text(text, encoding="utf-8")
PY

  launchctl unload "$target" >/dev/null 2>&1 || true
  launchctl load "$target" >/dev/null 2>&1 || true
}

wire_systemd() {
  local schedule on_calendar
  schedule="$(json_get backup_schedule "04:00")"
  if [[ ! "$schedule" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]; then
    schedule="04:00"
  fi
  on_calendar="*-*-* ${schedule}:00"

  local user_dir
  user_dir="$HOME/.config/systemd/user"
  mkdir -p "$user_dir"

  python3 - "$SCRIPT_DIR/templates/systemd/openclaw-backup.service" "$user_dir/openclaw-backup.service" "$OPENCLAW_HOME" <<'PY'
import pathlib
import sys

template, target, openclaw_home = sys.argv[1:]
text = pathlib.Path(template).read_text(encoding="utf-8")
text = text.replace("__OPENCLAW_HOME__", openclaw_home)
pathlib.Path(target).write_text(text, encoding="utf-8")
PY

  python3 - "$SCRIPT_DIR/templates/systemd/openclaw-backup.timer" "$user_dir/openclaw-backup.timer" "$on_calendar" <<'PY'
import pathlib
import sys

template, target, on_calendar = sys.argv[1:]
text = pathlib.Path(template).read_text(encoding="utf-8")
text = text.replace("__ONCALENDAR__", on_calendar)
pathlib.Path(target).write_text(text, encoding="utf-8")
PY

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable --now openclaw-backup.timer >/dev/null 2>&1 || true
  fi
}

run_check() {
  local failures=0
  local backup_dir

  echo "Running install check..."

  [ -f "$CONFIG_FILE" ] || { echo "- Missing config: $CONFIG_FILE"; failures=1; }
  [ -x "$BIN_DIR/backup.sh" ] || { echo "- Missing executable: $BIN_DIR/backup.sh"; failures=1; }
  [ -x "$BIN_DIR/backup-memory.sh" ] || { echo "- Missing executable: $BIN_DIR/backup-memory.sh"; failures=1; }
  [ -x "$BIN_DIR/backup-apply" ] || { echo "- Missing executable: $BIN_DIR/backup-apply"; failures=1; }

  backup_dir="$(expand_path "$(json_get backup_dir "~/backups/openclaw-system")")"
  [ -f "$backup_dir/backup-manifest.txt" ] || { echo "- Missing manifest: $backup_dir/backup-manifest.txt"; failures=1; }

  if [ "$(uname -s)" = "Darwin" ]; then
    [ -f "$HOME/Library/LaunchAgents/com.openclaw.daily-backup.plist" ] || { echo "- Missing launchd plist"; failures=1; }
  else
    [ -f "$HOME/.config/systemd/user/openclaw-backup.timer" ] || { echo "- Missing systemd timer"; failures=1; }
  fi

  if [ "$failures" -eq 0 ]; then
    echo "Check passed."
  else
    echo "Check failed."
  fi

  return "$failures"
}

run_first_backup() {
  OPENCLAW_BACKUP_CONFIG="$CONFIG_FILE" "$BIN_DIR/backup-apply"
}

print_summary() {
  local backup_dir memory_dir repo user schedule file_count repo_line
  backup_dir="$(expand_path "$(json_get backup_dir "~/backups/openclaw-system")")"
  memory_dir="$(expand_path "$(json_get memory_backup_dir "~/backups/openclaw-memory")")"
  repo="$(json_get github_repo "")"
  user="$(json_get github_user "")"
  schedule="$(json_get backup_schedule "04:00")"

  if [ -n "$repo" ] && [ -n "$user" ]; then
    repo_line="github.com/$user/$repo (private)"
  else
    repo_line="not configured"
  fi

  file_count="0"
  if [ -f "$backup_dir/backup-manifest.txt" ]; then
    file_count="$(awk '/^  [^:]+: [0-9]+ files$/ {sum += $2} END {print sum + 0}' "$backup_dir/backup-manifest.txt")"
  fi

  cat <<EOF2
✅ Backup configured.

System config -> $repo_line
Memory + notes -> $memory_dir (local only)
Schedule: daily at $schedule

First backup: done. $file_count files captured. SHA verified.
EOF2
}

main() {
  require_cmd bash
  require_cmd git
  require_cmd python3

  if [ "$CHECK_MODE" -eq 1 ]; then
    run_check
    exit $?
  fi

  fetch_if_needed
  install_scripts

  if [ "$SETUP_MODE" -eq 1 ] || [ ! -f "$CONFIG_FILE" ]; then
    if [ "$QUIET_MODE" -eq 1 ]; then
      write_quiet_config_if_needed
    else
      run_setup_wizard
    fi
  fi

  ensure_github_repo
  run_first_backup

  if [ "$(uname -s)" = "Darwin" ]; then
    wire_launchd
  else
    wire_systemd
  fi

  run_check
  print_summary
}

main "$@"
