# Preferences
- Commit messages: imperative mood, atomic
- Work on `main` by default
- Remove dead code; never comment it out
- Use `uv` as the default Python tooling path

# Workflow
- Present a plan before architectural changes
- Run tests or validations before claiming work is done
- Prefer `rg` and `rg --files` for search

# Git Safety
- Never force-push
- Never commit secrets
- Run `gitleaks detect` before pushing meaningful changes

# Local Environment
- Personal machine that also runs MCG enterprise tooling (Allego, Salesforce, Concur, LinkedIn, MS365 plugins)
- Keep personal and work config separated; never hardcode work secrets into shared or tracked files

# MCP Tool Preferences
- Atlassian: prefer `mcp__plugin_atlassian_atlassian__*` tools over `mcp__claude_ai_Atlassian__*`. Both resolve to the same `https://mcp.atlassian.com/v1/mcp` endpoint; the plugin is the canonical install via `claude-plugins-official`. This applies to subagents spawned via the `Agent` tool as well.

@RTK.md
