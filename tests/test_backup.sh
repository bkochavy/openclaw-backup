#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
OPENCLAW_HOME="$SANDBOX/.openclaw"
SANDBOX_BACKUP="$SANDBOX/backups/system"
SANDBOX_MEMORY="$SANDBOX/backups/memory"
CONFIG_FILE="$OPENCLAW_HOME/backup.json"

cleanup() {
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

mkdir -p "$OPENCLAW_HOME/workspace" \
  "$OPENCLAW_HOME/workspace/skills/demo" \
  "$OPENCLAW_HOME/workspace/scripts" \
  "$OPENCLAW_HOME/agents/main/agent" \
  "$OPENCLAW_HOME/agents/main/qmd/sessions" \
  "$OPENCLAW_HOME/cron" \
  "$OPENCLAW_HOME/identity" \
  "$OPENCLAW_HOME/credentials"

cat > "$OPENCLAW_HOME/openclaw.json" <<'JSON'
{"ok":true,"token":"__OPENCLAW_REDACTED__"}
JSON

cat > "$OPENCLAW_HOME/.env" <<'ENV'
TEST_SECRET=value123
ENV

cat > "$OPENCLAW_HOME/workspace/AGENTS.md" <<'EOF_AGENTS'
# Agents
EOF_AGENTS

cat > "$OPENCLAW_HOME/workspace/SOUL.md" <<'EOF_SOUL'
# Soul
EOF_SOUL

cat > "$OPENCLAW_HOME/workspace/MEMORY.md" <<'EOF_MEMORY'
# Memory
EOF_MEMORY

cat > "$OPENCLAW_HOME/workspace/skills/demo/SKILL.md" <<'EOF_SKILL'
# Demo Skill
EOF_SKILL

cat > "$OPENCLAW_HOME/workspace/scripts/demo.sh" <<'EOF_SCRIPT'
#!/usr/bin/env bash
echo demo
EOF_SCRIPT

cat > "$OPENCLAW_HOME/agents/main/agent/auth-profiles.json" <<'EOF_AUTH'
{"profiles":[]}
EOF_AUTH

cat > "$OPENCLAW_HOME/agents/main/agent/models.json" <<'EOF_MODELS'
{"models":[]}
EOF_MODELS

cat > "$OPENCLAW_HOME/cron/jobs.json" <<'EOF_JOBS'
{"jobs":[]}
EOF_JOBS

cat > "$OPENCLAW_HOME/identity/default.json" <<'EOF_ID'
{"id":"default"}
EOF_ID

cat > "$OPENCLAW_HOME/credentials/default.json" <<'EOF_CREDS'
{"name":"default"}
EOF_CREDS

cat > "$CONFIG_FILE" <<EOF_CFG
{
  "backup_dir": "$SANDBOX_BACKUP",
  "memory_backup_dir": "$SANDBOX_MEMORY",
  "github_repo": "",
  "github_user": "",
  "telegram_bot_token_env": "TELEGRAM_BOT_TOKEN_AVA",
  "telegram_chat_id": "",
  "backup_schedule": "04:00",
  "include_skills": true,
  "include_scripts": true,
  "include_launchd": true,
  "include_agents": true,
  "redact_env_values": true,
  "critical_files": [
    "openclaw/openclaw.json",
    "workspace-config/AGENTS.md",
    "workspace-config/SOUL.md"
  ]
}
EOF_CFG

export OPENCLAW_HOME
export OPENCLAW_BACKUP_CONFIG="$CONFIG_FILE"

bash "$ROOT_DIR/scripts/backup.sh"

[ -f "$SANDBOX_BACKUP/backup-manifest.txt" ] || { echo "FAIL: manifest not written"; exit 1; }
[ -s "$SANDBOX_BACKUP/openclaw/openclaw.json" ] || { echo "FAIL: openclaw.json missing"; exit 1; }

if [ ! -f "$SANDBOX_BACKUP/workspace-config/AGENTS.md" ] && [ ! -f "$SANDBOX_BACKUP/workspace-config/SOUL.md" ]; then
  echo "FAIL: workspace-config expected files missing"
  exit 1
fi

secret_pattern='gh''p_|gh''o_|s''k-'
if grep -rE "$secret_pattern" "$SANDBOX_BACKUP" >/dev/null 2>&1; then
  echo "FAIL: secret-like token found in backup"
  exit 1
fi

bash "$ROOT_DIR/scripts/backup-memory.sh"

[ -d "$SANDBOX_MEMORY" ] || { echo "FAIL: memory backup directory missing"; exit 1; }
[ -f "$SANDBOX_MEMORY/MEMORY.md" ] || { echo "FAIL: memory backup missing MEMORY.md"; exit 1; }

bash -n "$ROOT_DIR/scripts/backup.sh" "$ROOT_DIR/scripts/backup-memory.sh" "$ROOT_DIR/install.sh"

echo "PASS"
