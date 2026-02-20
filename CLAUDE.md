# Preferences
- Commit messages: imperative mood, atomic (one logical change per commit)
- Use feature branches; never commit directly to main/master
- Remove dead code; never comment it out


# Permissions
- You have full permissions to read, view, download, zip, unzip, retrieve, list, and analyze files across my system, and to access resources mentioned in this session and any other websites you need without prompting; only prompt me if you need to delete or edit a file.

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
