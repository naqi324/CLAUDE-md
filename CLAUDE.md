# CLAUDE-md

Claude Code configuration management repository. Contains hooks, settings, scripts, and CLAUDE.md files that define global Claude Code behavior.

## Session Context
- Date: 2026-03-18
- Work state: Optimizing global Claude Code config — compressing CLAUDE.md, wildcard permissions, eliminating duplication.
- Decisions:
  - Replaced 189 individual allow entries with 18 wildcard entries (e.g., `mcp__google__*`)
  - Removed redundant PreToolUse Bash hook (allow list already auto-approves)
  - Removed duplicate QMD mcpServers from settings.json (canonical def in ~/.claude.json)
  - Compressed global CLAUDE.md from 238 to ~96 lines while preserving 139/144 behavioral directives
  - Project CLAUDE.md stripped to project-specific content only (was 99% duplicate of global)
- Next steps:
  - Verify in fresh session that all tools auto-approve and behavioral rules hold
  - Commit all changes
