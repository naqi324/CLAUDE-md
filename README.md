# Claude Code Global Settings

This repository is the tracked mirror for the live global Claude Code configuration on this machine.

## Mirror Contract

These files are intended to stay in sync with the live `~/.claude` surfaces:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `.claude/settings.json` -> `~/.claude/settings.json`

The hook scripts live in this repo under `.claude/hooks/`, and the mirrored `settings.json` points Claude Code at these repo paths directly. That means the repo checkout itself is part of the runtime configuration.

## Repo Contents

- `CLAUDE.md` - tracked mirror of the live global Claude instructions
- `.claude/settings.json` - tracked mirror of the live global Claude settings
- `.claude/hooks/` - versioned hook scripts executed from repo paths
- `.claude/skills-manifest.json` - canonical global Claude skill link targets
- `.state/progress.md` - rolling session progress log
- `scripts/check-config-parity.sh` - verifies repo/live mirror parity and hook target existence
- `scripts/reconcile-skills.sh` - repairs `~/.claude/skills` symlinks from the manifest
- `scripts/check-skills-health.sh` - validates skill links and required frontmatter
- `scripts/setup-trust.sh` - suppresses the workspace trust prompt

## Setup On A New Machine

1. Clone the repo to the same path used by the mirrored settings:

   ```bash
   git clone <repository-url> ~/git/system/CLAUDE-md
   ```

2. Copy the mirrored config surfaces into `~/.claude`:

   ```bash
   cp ~/git/system/CLAUDE-md/CLAUDE.md ~/.claude/CLAUDE.md
   cp ~/git/system/CLAUDE-md/.claude/settings.json ~/.claude/settings.json
   ```

3. Optionally copy local overrides:

   ```bash
   cp ~/git/system/CLAUDE-md/.claude/settings.local.json ~/.claude/settings.local.json
   ```

4. Keep the repo checkout at `~/git/system/CLAUDE-md` unless you also update the hook paths in `~/.claude/settings.json`. The runtime settings point at repo hook scripts such as `/Users/naqi.khan/git/system/CLAUDE-md/.claude/hooks/inject-datetime.sh`.

5. Optionally trust your workspace root to suppress Claude's startup trust prompt:

   ```bash
   chmod +x ~/git/system/CLAUDE-md/scripts/setup-trust.sh
   ~/git/system/CLAUDE-md/scripts/setup-trust.sh
   ```

## Keeping Repo And Live Config In Sync

When you change the global config:

1. Edit the repo copy for tracked assets and hook scripts.
2. Sync the mirrored files into `~/.claude`:

   ```bash
   cp ~/git/system/CLAUDE-md/CLAUDE.md ~/.claude/CLAUDE.md
   cp ~/git/system/CLAUDE-md/.claude/settings.json ~/.claude/settings.json
   ```

3. Verify parity before committing:

   ```bash
   cd ~/git/system/CLAUDE-md
   ./scripts/check-config-parity.sh
   ./scripts/check-skills-health.sh
   ```

4. If you intentionally edited the live files first, copy them back into the repo before commit so the mirror remains true.

## MCP Permission Policy

This repo uses a static MCP permission policy rather than a hook-based classifier.

Default read-only MCP rule:

- Safe-by-default verbs: `get_`, `list_`, `search_`, `find_`
- Not safe-by-default: `create_`, `update_`, `edit_`, `delete_`, `send_`, `add_`, `remove_`, `upload_`, `download_`, `open_`, `join_`, `mark_`, `set_`, `archive_`, `pin_`, `unpin_`, `complete_`, `reply_`, `share_`, `move_`, `copy_`, `rename_`, `convert_`

Current policy intent:

- Whole-server wildcards remain allowed for `qmd`, `mail`, `browser-mcp`, `atlassian`, `brave-search`, `exa`, `google`, and `codex`
- Partially gated namespaces should use explicit read-only allow entries only
- Slack is the reference partially gated namespace: non-admin `search_*`, `list_*`, `get_*`, and `find_*` are allowed; admin reads and all state-changing actions remain gated
- When you launch Claude inside an MCP repo, project-level `.claude/settings.json` or `.claude/settings.local.json` files can carry stale exact-tool allowlists that lag behind the global safe-read baseline
- Permission changes require a fresh Claude shell session before the new allowlist is loaded into the startup permission snapshot

Audit command:

```bash
cd ~/git/system/CLAUDE-md
./scripts/audit-mcp-readonly-policy.py
```

The audit reads installed MCP servers from `~/.claude.json`, inspects both repo and live settings mirrors, and reports:

- whole-server approvals
- covered read-only tools in partially gated namespaces
- intentionally gated tools
- uncovered safe read-only tools that may deserve new allow entries
- drift warnings when a known MCP repo has a project-local override that is narrower than the global safe-read baseline

## Skills Reconciliation

This repo includes a manifest-driven workflow for global Claude custom skills.

Commands:

```bash
cd ~/git/system/CLAUDE-md
./scripts/reconcile-skills.sh
./scripts/check-skills-health.sh
```

This keeps `~/.claude/skills` symlinks aligned with the canonical local repositories.

## Security Notes

Never commit files containing:

- API keys or tokens
- credentials or passwords
- private environment variables
- `.env` files

This repo is designed to track safe configuration and hook code, not secrets.
