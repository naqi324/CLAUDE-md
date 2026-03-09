# Preferences
- Commit messages: imperative mood, atomic (one logical change per commit)
- Work on main branch by default; only create feature branches when explicitly requested or for large multi-session efforts
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

# Search

## Local Search (QMD)
- **Always use QMD MCP tools first** when searching for or locating content across the local machine. QMD indexes: git repos, Obsidian vault, OneDrive work files, Desktop, and Downloads.
- Use `mcp__qmd__query` for all QMD searches. Compose sub-queries by type:
  - `type: "lex"` — BM25 keyword search for exact term/phrase lookups.
  - `type: "vec"` — semantic vector search for conceptual/meaning-based queries.
  - `type: "hyde"` — hypothetical document search (write what the answer looks like, 50-100 words).
  - `type: "expand"` — auto-expand via LLM (max 1 per query) for unknown vocabulary.
  - Combine multiple sub-queries for best results (e.g., lex + vec).
- Use `mcp__qmd__get` and `mcp__qmd__multi_get` to retrieve full document content from QMD results.
- Fall back to Glob, Grep, or Bash find **only** when:
  - Searching within the current project's working tree for code-level patterns (function definitions, imports, variable references) where line-level precision matters.
  - QMD returned no results and the content is expected to exist in the current project.
  - The task requires filesystem-level operations (listing directory structure, checking file existence).
- **Obsidian handoff**: When QMD results come from the `obsidian` collection (paths under the Obsidian vault or collection field is `obsidian`), use the `obsidian-cli` skill (Skill tool, `skill="obsidian-cli"`) for all subsequent read, edit, create, and task operations on those notes. Do not use raw file Read/Write/Edit on Obsidian vault files. If Obsidian is not running, use `mcp__qmd__get` for read-only access and inform the user that edits require Obsidian to be running.
- Collections: `git` (source code/repos), `obsidian` (personal knowledge vault), `onedrive_hearst` (Hearst work files), `desktop` (staging), `downloads` (reference material).

## Web Search (Brave + Exa)
- **Use Brave Search and Exa MCP tools** for any task requiring current web information, external documentation, or content not indexed by QMD.
- Use `mcp__brave-search__brave_web_search` for general web queries, current events, and broad information retrieval.
- Use `mcp__brave-search__brave_news_search` for recent news and time-sensitive information.
- Use `mcp__exa__web_search_exa` for semantic/meaning-based web search — especially useful for finding conceptually related content even when exact keywords differ.
- Use `mcp__exa__get_code_context_exa` for finding code examples, library documentation, API references, and programming solutions.
- Use `mcp__exa__company_research_exa` for business intelligence, company info, and competitive research.
- **Search hierarchy for tasks requiring information lookup:**
  1. QMD first (local docs, code, notes)
  2. If not found locally or the query requires current/external info → Brave web search or Exa (pick based on query type)
  3. Fall back to built-in `WebFetch` for fetching specific known URLs
- **Parallel search**: When a task clearly needs both local and web results, run QMD and Brave/Exa searches in parallel.

## Google Workspace (Drive + Docs + Sheets + Slides + Calendar)
- Single server: `google` (@piotr-agier/google-drive-mcp) — 94 tools covering Drive, Docs, Sheets, Slides, Calendar.
- **Auth**: One-time browser OAuth; tokens persist at `~/.config/google-drive-mcp/tokens.json` with auto-refresh.
- **Drive**: `search` to find files, `createTextFile`/`createFolder` for new content, `downloadFile` to download, `listFolder` to browse.
- **Docs**: `createGoogleDoc` for new documents, `readGoogleDoc`/`getGoogleDocContent` to read, `updateGoogleDoc`/`insertText` to edit.
- **Sheets**: `createGoogleSheet` for new sheets, `getGoogleSheetContent` to read, `updateGoogleSheet`/`appendSpreadsheetRows` to write.
- **Slides**: `createGoogleSlides` for new presentations, `getGoogleSlidesContent` to read, `updateGoogleSlides` to edit.
- **Calendar**: `getCalendarEvents`/`createCalendarEvent` for scheduling, `listCalendars` for discovery.
- **Rules**: Never guess file IDs — always search first. Always read before modifying. Use `create_*` tools for new files.
- **Search integration**: When a task references docs/spreadsheets that might be in Google Drive, search Drive in parallel with QMD.

# Codex MCP
- Claude Code reads MCP server definitions from `~/.claude.json`, not `~/.claude/settings.json`.
- The global `codex` MCP server is routed through `/Users/naqi.khan/git/rewriter-skill/scripts/codex-mcp-safe-proxy.mjs`, which forwards to `codex mcp-server` and strips Claude-supplied OpenAI `model` overrides that are unsupported under ChatGPT-backed Codex login.
- When using `mcp__codex__codex` or `mcp__codex__codex-reply`, omit explicit OpenAI `model` overrides unless they have been verified to work with the current `codex login status`.
- Default Codex behavior should come from `~/.codex/config.toml`; on this machine that remains `model = "gpt-5.4"` with `model_reasoning_effort = "xhigh"`.
- If Codex MCP fails with a model-related error, check `codex login status` and `claude mcp get codex` before retrying.

# Workflow
- Present a plan before architectural changes and wait for approval
- Run existing linters, formatters, and tests before proposing changes
- When uncertain, present options with tradeoffs rather than guessing

# Git Workflow

## Session Start
- Check if CWD is a git repo. If not, run `git init`, create a safe `.gitignore` (covering .env*, *.pem, *.key, *.pfx, credentials.json, service-account*.json, token.json), and make an initial commit.
- Verify `.gitignore` covers secrets before the first commit in any new repo.
- If no remote exists, ask the user: "No remote configured. Want me to create a GitHub repo? (`gh repo create`)"
- Use `gh auth status` to confirm GitHub CLI is authenticated before any `gh` commands.

## During Session
- Work on `main` branch. Only create feature branches when explicitly requested or for large multi-session efforts.
- Commit frequently with meaningful imperative-mood messages.
- Push to `origin main` after each logical commit if remote exists.

## Session Exit (automated)
- A Stop hook (`auto-git-commit.sh`) automatically commits any uncommitted changes and pushes to remote main on session exit. This is a safety net — prefer making explicit commits with good messages during the session.

## Remote Repository
- Never auto-create a GitHub remote — always prompt the user first.
- Use `gh repo create --private --source=. --push` for new repos (default to private).
- Use `gh repo create --public --source=. --push` only when user explicitly requests public.

# Research Tasks

## Pre-Flight (mandatory)

Before starting ANY task involving research, analysis, report generation, or document creation:

1. **Size the task.** Estimate: How many sources/searches will this need? How many sections in the output? Will the final artifact exceed ~200 lines? If YES to any → use the file-based pattern below from the start.
2. **Default to file-based.** When uncertain about size, write artifacts to `.claude/` rather than holding findings in context. The cost of unnecessary files is near zero; the cost of running out of context is session failure.
3. **Mid-task escalation.** If already working and the task grows beyond expectations (3+ searches done, draft exceeding ~150 lines, or context feeling heavy), STOP. Write current progress to `.claude/research-{topic}.md` before continuing.

## Execution

1. **Break work into file-based steps.** Each step writes a durable artifact to `.claude/` in the project (or `~/.claude/` for non-project work):
   - `research-{topic}.md` — findings, sources, key data
   - `analysis-{topic}.md` — decisions, trade-offs, architecture
   - `plan-{topic}.md` — numbered steps with verification criteria
   - Keep artifacts concise (<200 lines each). Summarize, don't dump raw output.

2. **Write incrementally, not at the end.** After each logical phase completes, write its artifact to disk before starting the next phase. Never accumulate all findings in conversation context.

3. **Resume from artifacts on interruption.** If a session starts and `.claude/research-*.md` or `.claude/analysis-*.md` files exist from prior work, read them first and resume from the next incomplete step. Do not re-run completed phases.

4. **Use sub-agents for parallel research.** When multiple independent questions need answers, launch Explore agents in parallel. Each agent returns a summary; write combined findings to a single artifact file. If research feeds a large document, hand off to the "Document Generation" pattern below.

5. **Compact proactively.** When context usage feels high, write current progress to an artifact file, then suggest `/compact` or `/llm-history`. After compaction, read the artifact to restore working state.

6. **Clean up when done.** After the task completes and results are committed or delivered, remove interim `.claude/research-*` and `.claude/analysis-*` files. Keep only `progress.md` and final deliverables.

# Document Generation

When generating a document with multiple sections (reports, specs, guides, proposals, documentation):

1. **Create an outline first.** Write `.claude/draft-outline.md` with: document title, ordered section list (numbered `01`-`NN`), 1-2 sentence scope per section, and target output path. If sections have dependencies (e.g., Architecture depends on Requirements), note `depends_on: [NN]` in the outline.

2. **Launch parallel section writers.** For each section, launch an Agent (subagent_type: general-purpose) in a **single message** for max concurrency. Each agent receives: the full outline, any research artifacts (`.claude/research-*.md`), and its assigned section number/title. Each agent **writes its section to `.claude/draft-sections/{NN}-{slug}.md` using the Write tool** — it must not return full content in its response, only a brief completion summary. For sections with dependencies, launch them after their dependencies complete, passing completed dependency files as additional context.

3. **Assemble incrementally, not all at once.** Never read all sections into context simultaneously. Write the first section to the output file, then append subsequent sections one at a time using Edit. This prevents context overflow during assembly.

4. **Handle failures.** If an agent fails, retry only that section. Never re-run successful sections. After assembly, make a single coherence editing pass if needed.

5. **Resume on interruption.** If `.claude/draft-outline.md` and `.claude/draft-sections/` exist, read both. Generate only missing or empty section files. Never restart from scratch.

6. **Clean up.** After successful assembly and delivery, delete `.claude/draft-outline.md` and `.claude/draft-sections/`. The final document is the deliverable.

7. **Chain with research.** For research-heavy documents, complete the "Research Tasks" pattern first, then feed those artifacts as input context to each section writer.

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
- Date: 2026-03-07
- Work state: Added a Codex MCP safety proxy so Claude Code can use Codex reliably under the current ChatGPT-backed Codex login.
- Decisions:
  - Confirmed Claude Code MCP server config lives in `~/.claude.json`, not `~/.claude/settings.json`.
  - Repointed the global `codex` server to `/Users/naqi.khan/git/rewriter-skill/scripts/codex-mcp-safe-proxy.mjs`.
  - Proxy strips Claude-supplied OpenAI `model` overrides before forwarding to `codex mcp-server`, preserving standalone Codex defaults in `~/.codex/config.toml`.
  - Documented that explicit Codex model overrides should be omitted in Claude Code unless re-verified against the current `codex login status`.
- Next steps:
  - Restart any already-running Claude desktop session if it has cached the old MCP command.
  - If Codex auth changes away from ChatGPT login, re-test whether the proxy is still required.
