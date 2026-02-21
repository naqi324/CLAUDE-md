# Claude Code Global Settings

This repository contains global configuration files for Claude Code that can be synced across multiple machines.

## Contents

- `CLAUDE.md` - Global instructions and guidelines for Claude Code behavior
- `.claude/settings.json` - Global settings including permissions and model preferences
- `.claude/settings.local.json` - Local settings overrides (optional)
- `.claude/progress.md` - Rolling session progress log (session continuity)
- `scripts/setup-trust.sh` - Script to suppress workspace trust prompt

## Setup on a New Machine

To use these settings on a new machine:

1. Clone this repository:
   ```bash
   git clone <repository-url> ~/git/_personal/CLAUDE-md
   ```

2. Copy the files to your Claude Code config directory:
   ```bash
   cp ~/git/_personal/CLAUDE-md/CLAUDE.md ~/.claude/
   cp ~/git/_personal/CLAUDE-md/.claude/settings.json ~/.claude/
   ```

3. Optionally, copy local settings if needed:
   ```bash
   cp ~/git/_personal/CLAUDE-md/.claude/settings.local.json ~/.claude/
   ```

4. Enable workspace trust for your home directory (suppresses the startup trust prompt):
   ```bash
   chmod +x ~/git/_personal/CLAUDE-md/scripts/setup-trust.sh
   ~/git/_personal/CLAUDE-md/scripts/setup-trust.sh
   ```

   You can also trust additional directories:
   ```bash
   ~/git/_personal/CLAUDE-md/scripts/setup-trust.sh /path/to/directory
   ```

## Updating Settings

When you make changes to your local Claude Code settings that you want to persist:

1. Copy the updated files back to the repository:
   ```bash
   cp ~/.claude/CLAUDE.md ~/git/_personal/CLAUDE-md/
   cp ~/.claude/settings.json ~/git/_personal/CLAUDE-md/.claude/
   ```

2. Commit and push the changes:
   ```bash
   cd ~/git/_personal/CLAUDE-md
   git add .
   git commit -m "Update Claude settings"
   git push
   ```

## Security Note

This repository excludes sensitive files via `.gitignore`. Never commit files containing:
- API keys or tokens
- Credentials or passwords
- Private environment variables
- Any `.env` files

## Session Continuity

This configuration includes a **session continuity protocol** that enables Claude Code to maintain context across sessions. Each session automatically:

1. **Updates `## Session Context`** in the project's `CLAUDE.md` with a quick-reference snapshot of the current working state (last session date, work summary, key decisions, next steps). This section is overwritten each session.

2. **Appends to `.claude/progress.md`** with a detailed dated entry covering work accomplished, decisions and reasoning, files modified, and explicit next steps.

This means a new session can immediately understand where the last one left off without the user needing to re-explain context.

The behavioral instructions live in the `## Session Continuity` section of `CLAUDE.md`. The global `~/.claude/CLAUDE.md` contains these instructions so they apply to all projects. Each project then gets its own `## Session Context` section and `.claude/progress.md` file.

## Files Explained

### CLAUDE.md
Contains global instructions that Claude Code reads for all projects, including:
- Naming conventions
- Folder structure preferences
- Documentation standards
- Git workflow guidelines
- Code quality principles

### settings.json
Contains Claude Code configuration:
- Blocked commands and security rules
- Model preferences
- Permission settings
- Default modes

### settings.local.json
Optional local overrides that are machine-specific and may not need to be synced.

### .claude/progress.md
Rolling session progress log. Each significant session appends a dated entry with work summary, decisions, files modified, and next steps. When the file grows beyond ~200 lines, older entries are summarized into a Historical Summary section. Tracked in git by default.

### scripts/setup-trust.sh
Configures Claude Code to trust a workspace directory (defaults to `$HOME`), suppressing the trust confirmation prompt on startup. Modifies `~/.claude.json` using `jq`. Safe to run multiple times. Requires `jq` (`brew install jq`).

## Skills Reconciliation

This repo now includes a manifest-driven workflow for global Claude custom skills.

Manifest:

- `.claude/skills-manifest.json`

Commands:

```bash
cd ~/git/CLAUDE-md
./scripts/reconcile-skills.sh
./scripts/check-skills-health.sh
```

This ensures `~/.claude/skills` symlinks resolve to canonical local repositories.

After reconciliation, restart Claude Code sessions to refresh available skills.
