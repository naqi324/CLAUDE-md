# Preferences
- Commit messages: imperative mood, atomic (one logical change per commit)
- Use feature branches; never commit directly to main/master
- Remove dead code; never comment it out


# Permissions
- You have full permissions to read, write, edit, create, delete, move, copy, and execute files across my system without prompting, unless the operation is destructive and irreversible (e.g., deleting a git repo, wiping a database, rm -rf on home directories).
- Access any resources mentioned in this session and any websites you need without prompting.
- Restart, stop, or manage local processes and services (Claude Desktop, launchctl agents, dev servers) without prompting.
- Run any script in a project's `scripts/` directory without prompting.
- Execute localhost HTTP requests without prompting.
- Only prompt me for: irreversible destructive operations, actions with external cost/billing implications, or operations you are genuinely uncertain about.

## Autonomy Rules (reduce unnecessary questions)
- **Don't ask for implementation approach confirmation** -- when a plan has been approved, execute it. Make autonomous decisions on implementation details.
- **Don't ask for credentials interactively** -- provide setup instructions and wait for the user to supply them. Don't ask multiple rounds of format questions.
- **Don't ask about error handling strategy** -- when something fails, research alternatives and present a revised plan rather than asking "how do you want to proceed?"
- **Don't ask about scope/features** -- implement what was requested. If the user asked for "email access", build all of: search, read, send, reply. Don't ask which subset.
- **Autonomous testing** -- run tests, verify outputs, and iterate on fixes without asking "should I test this?"
- **Autonomous git operations** -- commit, push, create branches without asking. Only pause before force-push or destructive git operations.
- **Autonomous process management** -- restart services (Claude Desktop, dev servers, launchctl agents) without asking.
- **Prefer action over questions** -- when 2+ reasonable approaches exist and none is clearly wrong, pick the best one and go. Only ask when the choice is truly irreversible or has major cost implications.

# Search (QMD)
- **Always use QMD MCP tools first** when searching for or locating content across the local machine. QMD indexes: git repos, Obsidian vault, OneDrive work files, Desktop, and Downloads.
- Use `mcp__qmd__deep_search` for open-ended or exploratory queries (auto-expands, searches keyword + meaning, reranks).
- Use `mcp__qmd__search` for exact keyword/phrase lookups.
- Use `mcp__qmd__vector_search` for conceptual/semantic similarity when exact keywords may not match.
- Use `mcp__qmd__get` and `mcp__qmd__multi_get` to retrieve full document content from QMD results.
- Fall back to Glob, Grep, or Bash find **only** when:
  - Searching within the current project's working tree for code-level patterns (function definitions, imports, variable references) where line-level precision matters.
  - QMD returned no results and the content is expected to exist in the current project.
  - The task requires filesystem-level operations (listing directory structure, checking file existence).
- **Obsidian handoff**: When QMD results come from the `obsidian` collection (paths under the Obsidian vault or collection field is `obsidian`), use the `obsidian-cli` skill (Skill tool, `skill="obsidian-cli"`) for all subsequent read, edit, create, and task operations on those notes. Do not use raw file Read/Write/Edit on Obsidian vault files. If Obsidian is not running, use `mcp__qmd__get` for read-only access and inform the user that edits require Obsidian to be running.
- Collections: `git` (source code/repos), `obsidian` (personal knowledge vault), `onedrive_hearst` (Hearst work files), `desktop` (staging), `downloads` (reference material).

# Workflow
- Present a plan before architectural changes and wait for approval
- Run existing linters, formatters, and tests before proposing changes
- When uncertain, present options with tradeoffs rather than guessing

# Git Safety
- Never force-push to any branch
- Run `gitleaks detect` before pushing
- Never commit: .env*, *.pem, *.key, *.pfx, credentials.json, service-account*.json, token.json
- When unsure if a file contains secrets, ask before committing
- Verify .gitignore covers secrets before a project's first commit

# Session Continuity
- At end of meaningful work, update two artifacts in each project:
- `## Session Context` at bottom of project CLAUDE.md: overwrite with date, work state, decisions, next steps (max 20 lines)
- `.claude/progress.md`: append dated entry with title, summary, decisions, files modified, next steps
- Skip logging routine reads, obvious decisions, or full command output
- When progress.md exceeds ~200 lines, summarize older entries into a Historical Summary section

# LLM History (Session Context Preservation)
- Before ending a session where meaningful work was done, proactively run `/llm-history` to save session context to the Obsidian vault.
- When context window usage feels high or compaction has occurred, suggest saving with `/llm-history`.
- When resuming work on a project, check `/Users/naqi.khan/Documents/Obsidian/LLM History/` for recent context files matching the project.
- Hook-based auto-save (Stop and PreCompact) is a fallback — the `/llm-history` skill produces higher-quality output.
- When offering proactively, say: "Want me to save session context before we wrap up? (`/llm-history`)"

# Error Self-Correction
- When I correct a mistake you made, log it to `~/.claude/error-log.md` immediately
- Entry format:
  ```
  ## YYYY-MM-DD — <short error title>
  - **What went wrong**: <what you did incorrectly>
  - **Correction**: <what the user told you to do instead>
  - **Category**: <one of: wrong-command, wrong-file, wrong-assumption, misread-output, config-error, git-error, style-violation, other>
  - **Lesson**: <one-sentence rule to prevent recurrence>
  ```
- At the start of each session, read `~/.claude/error-log.md` and apply all lessons
- Before taking an action in a category with logged errors, check for applicable lessons first
- When error-log.md exceeds ~100 entries, summarize older entries into a "Patterns" section at the top and remove individual entries older than 30 days

## Session Context
- Date: 2026-02-25
- Work state: Added 59 MCP tool auto-approvals to global settings for Mail, Playwright, and Atlassian servers.
- Decisions:
  - Auto-approved all Mail tools (8): list, search, read, expand, send, reply, download, list_folders.
  - Auto-approved all Playwright tools (22): full browser automation suite.
  - Auto-approved all Atlassian tools (29): Confluence CRUD, Jira CRUD, search, transitions, worklogs.
  - Write operations included per existing autonomy rules; CLAUDE.md instructions provide guardrails.
- Next steps:
  - Validate no approval prompts for MCP tools in a fresh session.
  - Consider PreToolUse hook for auto-discovering new MCP tools (forward-compatible approach).
