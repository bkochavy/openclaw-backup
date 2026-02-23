# openclaw-backup

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-compatible-orange)](https://openclaw.ai)

![openclaw-backup](https://raw.githubusercontent.com/bkochavy/openclaw-backup/main/.github/social-preview.png)

Your [OpenClaw](https://openclaw.ai) setup took weeks to dial in. The personality in `SOUL.md`, the delegation rules in `AGENTS.md`, auth profiles, custom skills, scheduled jobs — none of it is backed up by default. One bad update or careless edit and it's gone.

This backs everything up to a private GitHub repo every night, verifies the push succeeded, and alerts you via Telegram if it didn't.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bkochavy/openclaw-backup/main/install.sh | bash -- --setup
```

The installer walks you through setup, creates a private GitHub repo, wires up a daily schedule (launchd on macOS, systemd on Linux), and runs your first backup immediately.

Or clone and run manually:

```bash
git clone https://github.com/bkochavy/openclaw-backup.git
cd openclaw-backup && ./install.sh --setup
```

**Requirements:** `bash`, `git`, `python3` (pre-installed on most systems), and optionally `gh` ([GitHub CLI](https://cli.github.com)) for remote push. Without `gh`, backups run locally.

> **Linux VPS:** run `loginctl enable-linger <user>` so the systemd timer survives logout.

## For Humans

You spend weeks tuning your OpenClaw config. Then an update ships, something breaks, and you're rebuilding from memory. This runs at 4 AM every day — it commits a snapshot to a local git repo, pushes to a private GitHub remote, and verifies the SHA matches. If the push fails, it retries once, then sends a Telegram alert.

**What gets backed up:**

- **Config** — `openclaw.json` (secrets redacted), `.env` key names, agent auth and model profiles
- **Workspace** — `SOUL.md`, `AGENTS.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md`
- **Skills & scripts** — custom skill files and automation scripts (no `node_modules`)
- **System** — LaunchAgents/systemd units, cron jobs, identity and credential metadata
- **Memory** — `MEMORY.md`, daily notes, session summaries stay **local only** and are never pushed

**Restoring files:**

```bash
# Single file
git -C ~/backups/openclaw-system show HEAD:workspace-config/SOUL.md > ~/.openclaw/workspace/SOUL.md

# Browse history
git -C ~/backups/openclaw-system log --oneline

# Restore from a specific date
git -C ~/backups/openclaw-system show <sha>:workspace-config/AGENTS.md

# Full restore on a new machine
git clone https://github.com/yourname/openclaw-system-backup.git ~/backups/openclaw-system
```

## For Agents

Complete runbook for autonomous installation and operation. All paths assume default config.

### Install (non-interactive)

```bash
curl -fsSL https://raw.githubusercontent.com/bkochavy/openclaw-backup/main/install.sh | bash -- --quiet
```

`--quiet` uses sensible defaults with no prompts. Verify afterward:

```bash
~/.openclaw/workspace/projects/openclaw-backup/install.sh --check
```

### Operations

```bash
# Trigger manual backup
~/.openclaw/bin/backup-apply

# Check last backup manifest
cat ~/backups/openclaw-system/backup-manifest.txt

# Recent backup commits
git -C ~/backups/openclaw-system log --oneline -5

# Backup log (errors and push status)
cat /tmp/openclaw-backup.log

# Restore a file to its live location
git -C ~/backups/openclaw-system show HEAD:workspace-config/SOUL.md > ~/.openclaw/workspace/SOUL.md

# Diff against yesterday
git -C ~/backups/openclaw-system diff HEAD~1 -- workspace-config/AGENTS.md

# Diff against last week
git -C ~/backups/openclaw-system diff HEAD~7 -- workspace-config/SOUL.md
```

### Config reference

Config lives at `~/.openclaw/backup.json`:

| Field | Default | Purpose |
|-------|---------|---------|
| `backup_dir` | `~/backups/openclaw-system` | Local backup destination |
| `github_repo` | `""` | Remote repo name (created as private) |
| `github_user` | `""` | GitHub username for push |
| `backup_schedule` | `04:00` | Daily backup time (HH:MM) |
| `telegram_chat_id` | `""` | Chat ID for failure alerts |
| `include_skills` | `true` | Include custom skill files |
| `include_scripts` | `true` | Include automation scripts |
| `redact_env_values` | `true` | Strip values from `.env` files |

### Troubleshooting

If Telegram alerts fire or `backup-manifest.txt` shows `MISSING` entries:

1. Read `/tmp/openclaw-backup.log` for the failure reason
2. Check GitHub auth: `gh auth status`
3. Run manual backup: `~/.openclaw/bin/backup-apply`
4. Verify remote matches local:
   ```bash
   git -C ~/backups/openclaw-system rev-parse HEAD
   git -C ~/backups/openclaw-system ls-remote origin HEAD
   ```

## Secret handling

Tokens are never hardcoded. GitHub auth is fetched at runtime via `gh auth token`. Env files are redacted by default. The package does not sync secrets to external stores — add your own step to `scripts/backup.sh` if you need 1Password, AWS Secrets Manager, or Vault.

## Uninstall

```bash
./uninstall.sh
```

---

Built and battle-tested backing up a production [OpenClaw](https://openclaw.ai) setup. MIT licensed.
