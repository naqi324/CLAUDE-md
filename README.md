# Claude Code Global Settings

This repository contains global configuration files for Claude Code that can be synced across multiple machines.

## Contents

- `CLAUDE.md` - Global instructions and guidelines for Claude Code behavior
- `.claude/settings.json` - Global settings including permissions and model preferences
- `.claude/settings.local.json` - Local settings overrides (optional)
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

### scripts/setup-trust.sh
Configures Claude Code to trust a workspace directory (defaults to `$HOME`), suppressing the trust confirmation prompt on startup. Modifies `~/.claude.json` using `jq`. Safe to run multiple times. Requires `jq` (`brew install jq`).
