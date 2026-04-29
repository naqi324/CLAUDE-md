# Claude Code Global Settings

This repository is the tracked mirror of the live global Claude Code configuration on this machine.

## Mirror Contract

These files stay in sync with the live `~/.claude` surfaces:

- `CLAUDE.md` -> `~/.claude/CLAUDE.md`
- `.claude/settings.json` -> `~/.claude/settings.json`

The mirrored `settings.json` points Claude Code at one repo-owned hook path:

- `.claude/hooks/ghostty-hook-title.sh` - refreshes the Ghostty pane title after tool use

That means the repo checkout itself is part of the runtime configuration.

## Authority Boundaries

`CLAUDE-md` owns only these live files:

- `~/.claude/CLAUDE.md`
- `~/.claude/settings.json`

Related Claude surfaces are intentionally owned elsewhere:

- `~/.claude/statusline.sh` - managed by `~/git/system/system-backup`
- `~/.claude/skills/` - managed by `~/git/system/system-backup/manifests/claude-sources.json`
- `~/.claude.json` - managed by the `system-backup` MCP merge workflow
- `~/Library/Application Support/Claude/claude_desktop_config.json` - managed by `system-backup`
- `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/` - validated by `system-backup` against the same custom-skill inventory
- `claude.ai` remote connectors - account-scoped and not managed from local config files
- `~/.config/personal-mac-bootstrap/ghostty-title.zsh` - managed by `system-backup`

## Repo Contents

- `CLAUDE.md` - tracked mirror of the live global Claude instructions
- `.claude/settings.json` - tracked mirror of the live global Claude settings
- `.claude/hooks/` - versioned runtime hook scripts
- `.state/progress.md` - rolling session progress log
- `scripts/check-config-parity.sh` - verifies repo/live mirror parity and validates referenced command targets
- `scripts/skill-manifest.py` - resolves the canonical skill manifest, with explicit legacy-manifest compatibility
- `scripts/reconcile-skills.sh` - repairs `~/.claude/skills` symlinks from the canonical manifest
- `scripts/check-skills-health.sh` - validates skill links, required frontmatter, and retired-name cleanup
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

4. Keep the repo checkout at `~/git/system/CLAUDE-md` unless you also update the runtime hook path in `~/.claude/settings.json`. The live settings point at `/Users/naqi.khan/git/system/CLAUDE-md/.claude/hooks/ghostty-hook-title.sh`.

5. Keep `~/git/system/system-backup` available if you want the skill and MCP wrapper commands in this repo to work. They default to the sibling canonical manifest and managed MCP templates owned there.

6. Optionally trust your workspace root to suppress Claude's startup trust prompt:

   ```bash
   chmod +x ~/git/system/CLAUDE-md/scripts/setup-trust.sh
   ~/git/system/CLAUDE-md/scripts/setup-trust.sh
   ```

## Keeping Repo And Live Config In Sync

When you change the global config:

1. Treat parity as the source of truth, not edit location. If the repo changed first, copy repo to live. If the live files changed first, copy live back into the repo before commit.
2. Sync the mirrored files into `~/.claude` when the repo is newer:

   ```bash
   cp ~/git/system/CLAUDE-md/CLAUDE.md ~/.claude/CLAUDE.md
   cp ~/git/system/CLAUDE-md/.claude/settings.json ~/.claude/settings.json
   ```

3. Or sync the live mirror back into the repo when `~/.claude` is newer:

   ```bash
   cp ~/.claude/CLAUDE.md ~/git/system/CLAUDE-md/CLAUDE.md
   cp ~/.claude/settings.json ~/git/system/CLAUDE-md/.claude/settings.json
   ```

4. Verify parity before committing:

   ```bash
   cd ~/git/system/CLAUDE-md
   ./scripts/check-config-parity.sh
   ./scripts/check-skills-health.sh
   ```

5. Commit only after the repo and live files match again.

## MCP Permission Policy

This repo uses a static MCP permission policy rather than a hook-based classifier.

Default read-only MCP rule:

- Safe-by-default verbs: `get_`, `list_`, `search_`, `find_`
- Not safe-by-default: `create_`, `update_`, `edit_`, `delete_`, `send_`, `add_`, `remove_`, `upload_`, `download_`, `open_`, `join_`, `mark_`, `set_`, `archive_`, `pin_`, `unpin_`, `complete_`, `reply_`, `share_`, `move_`, `copy_`, `rename_`, `convert_`

Current policy intent:

- Whole-server wildcards remain allowed for `qmd`, `browser-mcp`, `atlassian`, `brave`, `google`, and `codex`
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

These wrapper commands read the canonical manifest from `~/git/system/system-backup/manifests/claude-sources.json` by default. You can still pass an explicit legacy manifest path if needed.

Commands:

```bash
cd ~/git/system/CLAUDE-md
./scripts/reconcile-skills.sh
./scripts/check-skills-health.sh
```

This keeps `~/.claude/skills` symlinks aligned with the canonical local repositories while ensuring retired skill names do not linger.

## Security Notes

Never commit files containing:

- API keys or tokens
- credentials or passwords
- private environment variables
- `.env` files

This repo is designed to track safe configuration and hook code, not secrets.
