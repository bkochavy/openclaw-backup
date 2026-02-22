---
name: openclaw-backup
description: "Manage OpenClaw config backups. Use when: user wants to check backup status, restore a file, trigger manual backup, investigate a backup failure, or understand what is and isn't backed up."
---

# OpenClaw Backup Skill

## Command Reference

- Check latest manifest:
  ```bash
  cat ~/backups/openclaw-system/backup-manifest.txt
  ```
- Check recent backup commits:
  ```bash
  git -C ~/backups/openclaw-system log --oneline -10
  ```
- Trigger manual backup:
  ```bash
  ~/.openclaw/bin/backup-apply
  ```
- Check backup logs:
  ```bash
  tail -n 100 /tmp/openclaw-backup.log
  ```
- Verify installation:
  ```bash
  ./install.sh --check
  ```

## What Is Backed Up

| Area | Destination | Notes |
|------|-------------|-------|
| System config | Private GitHub repo | `openclaw.json`, workspace docs, agent auth/model files |
| Skills/scripts | Private GitHub repo | Controlled by `include_skills` / `include_scripts` |
| Launchd/systemd metadata | Private GitHub repo | Controlled by `include_launchd` |
| Memory/notes/sessions | Local-only git repo | Never pushed to remote |

## Restore From GitHub

- Restore one file:
  ```bash
  git -C ~/backups/openclaw-system show HEAD:workspace-config/AGENTS.md > ~/.openclaw/workspace/AGENTS.md
  ```
- Restore a full snapshot:
  ```bash
  git -C ~/backups/openclaw-system checkout <commit_sha>
  rsync -a ~/backups/openclaw-system/openclaw/ ~/.openclaw/
  rsync -a ~/backups/openclaw-system/workspace-config/ ~/.openclaw/workspace/
  ```

## Compare Config N Days Ago

```bash
git -C ~/backups/openclaw-system diff HEAD~7 -- workspace-config/SOUL.md
git -C ~/backups/openclaw-system diff HEAD~7 -- openclaw/openclaw.json
```

## If Telegram Alerts Fire

1. Read `/tmp/openclaw-backup.log` for push failure reason.
2. Verify network and GitHub auth with `gh auth status`.
3. Run manual backup: `~/.openclaw/bin/backup-apply`.
4. Confirm remote head:
   ```bash
   git -C ~/backups/openclaw-system rev-parse HEAD
   git -C ~/backups/openclaw-system ls-remote origin HEAD
   ```
5. If mismatch persists, inspect repo permissions and token scope.
