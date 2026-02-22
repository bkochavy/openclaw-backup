# openclaw-backup

Public, installable backup package for OpenClaw configuration and workspace state.

## Install

```bash
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

**Why memory stays local:** Your daily notes and session transcripts are private. They never leave the machine. Local git commits protect against local corruption.

### Restore from backup

#### 1) Full restore (new machine)

1. Install OpenClaw and GitHub CLI (`gh auth login`).
2. Clone your private backup repo into `~/backups/openclaw-system`.
3. Copy files back into `~/.openclaw`:
   - `openclaw/openclaw.json` -> `~/.openclaw/openclaw.json`
   - `workspace-config/*` -> `~/.openclaw/workspace/`
   - `agents/*` -> matching paths under `~/.openclaw/agents/`
4. Reinstall schedule with `./install.sh --check` (or rerun `./install.sh --setup`).

#### 2) Restore a single file

```bash
git -C ~/backups/openclaw-system show HEAD:workspace-config/SOUL.md > ~/.openclaw/workspace/SOUL.md
```

#### 3) Restore to a specific date

```bash
git -C ~/backups/openclaw-system log --oneline --since='30 days ago'
git -C ~/backups/openclaw-system checkout <commit_sha> -- workspace-config/AGENTS.md
```

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
