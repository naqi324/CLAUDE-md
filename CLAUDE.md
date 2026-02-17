# Global Guidelines

## Naming Conventions
- Use clear, descriptive names that reveal intent — avoid abbreviations and single-letter variables outside small loop scopes
- Files and folders: use kebab-case (e.g., `user-profile.ts`, `api-handlers/`) or match the dominant convention of the project's language/framework
- Match the existing project's naming style before introducing a new one
- Boolean variables/functions: prefix with `is`, `has`, `should`, `can`

## Folder Structure
- Group by feature or domain, not by file type, when the project grows beyond a handful of files
- Keep nesting shallow — max 3-4 levels deep; prefer flat structures
- Separate source code, tests, configuration, and documentation into distinct top-level directories
- Place shared utilities in a clearly named directory (e.g., `lib/`, `shared/`, `utils/`)

## Documentation
- Every project must have a root `README.md` covering: purpose, setup instructions, usage, and contribution guidelines
- Document "why", not "what" — code shows what it does; comments explain non-obvious reasoning
- Keep a `CHANGELOG.md` for projects with releases or versioned APIs
- Add inline comments only for complex logic, workarounds, or non-obvious business rules

## Version Control (Git)
- Write commit messages in imperative mood: "Add feature", "Fix bug", "Remove unused code"
- Keep commits atomic — one logical change per commit
- Use feature branches; never commit directly to `main` or `master`
- Write meaningful PR descriptions explaining what changed and why
- Do not commit secrets, credentials, or environment-specific config — use `.gitignore` and `.env` files

## Git Safety
- Before the first commit in any project, verify a .gitignore exists and covers secrets (.env*, *.key, *.pem, credentials*)
- Run `gitleaks detect` before pushing to verify no secrets are staged
- Never commit files matching: .env, .env.*, *.pem, *.key, *.p12, *.pfx, credentials.json, service-account*.json, *secret*, token.json
- If pre-commit hooks are not installed in a project, run `pre-commit install` to set them up
- When creating new projects, initialize with a comprehensive .gitignore appropriate for the language/framework
- Never force-push to any branch; never push directly to main or master
- When in doubt about whether a file contains sensitive data, ask before committing

## Code Quality
- Follow the principle of least surprise — write code that does what a reader would expect
- Prefer explicit over implicit; prefer simple over clever
- Handle errors explicitly — do not silently swallow exceptions
- Remove dead code rather than commenting it out; Git preserves history

## Permission Auto-Approval
- Read-only and viewing commands are auto-approved (e.g., `git log`, `git diff`, `cat`, `ls`, `stat`, `id`)
- This includes `git -C <path>` variants of all read-only git subcommands
- Mutating commands (e.g., `git commit`, `git push`, `mkdir`, `cp`) are auto-approved but should be used with care
- Destructive commands are denied (e.g., `git push --force`, `git reset --hard`, `rm -rf /`)

## Collaboration
- Before making large architectural changes, outline the plan and confirm with the user
- When modifying existing code, preserve the project's established patterns and style
- Run existing linters, formatters, and test suites before proposing changes
- When adding dependencies, prefer well-maintained libraries with active communities

## Session Continuity

Maintain session continuity so future sessions can resume where the last one left off. This uses two artifacts:

1. **`## Session Context` in the project's CLAUDE.md** — a quick-reference snapshot of the current working state (overwritten each session, ~10-20 lines max)
2. **`.claude/progress.md`** — a rolling detailed log with one entry per significant session

### When to Update
- At the end of meaningful work (not after trivial queries or quick lookups)
- Before a session ends if significant progress was made
- After completing a major task or reaching a decision point

### Session Context (CLAUDE.md section)
Update the `## Session Context` section at the bottom of the project's CLAUDE.md with:
- Last session date
- Brief summary of current work state (what was done, what's in progress)
- Key decisions made and their reasoning
- Open items, blockers, or next steps
- Always overwrite the previous content — this is current state, not history

### Progress Log (.claude/progress.md)
Append a new dated entry to `.claude/progress.md` with:
- Date and short title (e.g., `## 2026-02-16 -- Add authentication module`)
- Work summary: what was accomplished
- Decisions and reasoning: architectural choices, rejected alternatives
- Non-obvious tools or commands used
- Files created or significantly modified
- Explicit next steps for the next session

### What NOT to Log
- Routine file reads or standard git operations
- Obvious decisions any session would make identically
- Full command outputs or error traces (summarize instead)
- Exploratory dead ends (unless the dead end itself is informative)

### Growth Management
- Session Context: always overwritten, kept under 20 lines
- progress.md: when exceeding ~200 lines, summarize older entries into a `## Historical Summary` section at the top and remove the detailed entries that were summarized

## Session Context
- **Last session**: 2026-02-16
- **Current state**: Initial setup of session continuity protocol
- **Work done**: Added `## Session Continuity` instructions and `## Session Context` to CLAUDE.md; created `.claude/progress.md`; updated README.md with feature documentation
- **Decisions**: Two-tier approach (quick-reference in CLAUDE.md + detailed log in progress.md); progress.md tracked in git by default
- **Next steps**: Use this protocol in future sessions; refine instructions based on practical experience
