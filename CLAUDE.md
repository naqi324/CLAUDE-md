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
- Date: 2026-02-21
- Work state: Reduced approval interruptions and added error self-correction logging to global Claude config.
- Decisions:
  - Analyzed 3 approval log files to identify 5 categories of unnecessary interruptions.
  - Added `Write`, `Edit`, `NotebookEdit` and 24 Bash patterns to `~/.claude/settings.json` allow list.
  - Added 10 safety deny entries for destructive home-dir/system operations.
  - Replaced restrictive Permissions section with tiered auto-approve policy in both global and project CLAUDE.md.
  - Added Error Self-Correction section with persistent `~/.claude/error-log.md` for cross-session learning.
- Next steps:
  - Validate reduced interruptions in a fresh session.
  - Monitor error-log.md growth and pattern summarization.
