# openclaw-backup

> OpenClaw updates can wipe your config. This backs it up to a private GitHub repo every night.

Your `SOUL.md`, `AGENTS.md`, auth profiles, custom skills, scheduled jobs -- months of
tuning. OpenClaw has no built-in backup. One bad update or accidental edit and it's gone.

This runs daily at 4 AM, commits everything to a private GitHub repo, verifies the push
succeeded, and alerts you via Telegram if it didn't. Memory and daily notes stay local only.

Built and battle-tested backing up a production OpenClaw setup.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-compatible-orange)](https://openclaw.ai)

Public, installable backup package for OpenClaw configuration and workspace state.

## Install

```bash
# Option 1: one-liner (interactive setup)
curl -fsSL https://raw.githubusercontent.com/bkochavy/openclaw-backup/main/install.sh | bash -- --setup

# Option 2: clone and run
git clone https://github.com/bkochavy/openclaw-backup.git
cd openclaw-backup
./install.sh --setup
```

Quick defaults:

```bash
./install.sh --quiet
```

Check installation:

```bash
./install.sh --check
```

## 👤 For Humans

**The problem:** OpenClaw updates can corrupt your config. A bad edit to `openclaw.json` can break your whole setup. Your `SOUL.md`, auth profiles, custom skills, and scheduled jobs can disappear. OpenClaw does not back this up automatically.

**What this backs up:**

| Category | Where | What |
|----------|-------|------|
| OpenClaw config | GitHub (private) | `openclaw.json` (secrets redacted), auth profiles |
| Workspace files | GitHub (private) | `SOUL.md`, `AGENTS.md`, `USER.md`, `TOOLS.md`, `HEARTBEAT.md` |
| Skills | GitHub (private) | All custom skill files (no `node_modules`) |
| Scripts | GitHub (private) | Custom automation scripts |
| LaunchAgents | GitHub (private) | OpenClaw-related plist files |
| Memory / notes | Local only | `MEMORY.md`, daily notes, session summaries |

### Restore from backup

**Single file:**

```bash
git -C ~/backups/openclaw-system show HEAD:workspace-config/SOUL.md > ~/.openclaw/workspace/SOUL.md
```

**Full restore (new machine):**

```bash
git clone https://github.com/yourname/openclaw-system-backup.git ~/backups/openclaw-system
# Then copy files back manually or run:
bash ~/.openclaw/workspace/projects/openclaw-backup/scripts/restore.sh  # if available
```

**Restore to a specific date:**

```bash
git -C ~/backups/openclaw-system log --oneline  # find the commit
git -C ~/backups/openclaw-system show <sha>:workspace-config/AGENTS.md
```

**Why memory stays local:** Your daily notes and session transcripts are private. They never leave the machine. Local git commits protect against local corruption.

## 🤖 For Agents

Runbook:

- Check last backup:
  ```bash
  cat ~/backups/openclaw-system/backup-manifest.txt
  ```
- Verify push:
  ```bash
  git -C ~/backups/openclaw-system log --oneline -5
  ```
- Trigger manual backup:
  ```bash
  ~/.openclaw/bin/backup-apply
  ```
- Check backup log:
  ```bash
  cat /tmp/openclaw-backup.log
  ```
- Restore a file:
  ```bash
  git -C ~/backups/openclaw-system show HEAD:workspace-config/SOUL.md
  ```
- Compare to yesterday:
  ```bash
  git -C ~/backups/openclaw-system diff HEAD~1 -- workspace-config/AGENTS.md
  ```

## Secret handling

The backup script never hardcodes tokens. It fetches GitHub auth at runtime with:

```bash
GH_TOKEN="$(gh auth token 2>/dev/null || true)"
```

The package intentionally does not sync secrets to third-party stores. Add your own step if needed.

Patterns you can add to `scripts/backup.sh`:

- 1Password item update
- AWS Secrets Manager write
- Vault KV sync

Keep those steps private to your environment.

## Uninstall

```bash
./uninstall.sh
```
