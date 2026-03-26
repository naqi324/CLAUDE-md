# Preferences
- Commit messages: imperative mood, atomic (one logical change per commit)
- Work on main branch by default; only create feature branches when explicitly requested or for large multi-session efforts
- Remove dead code; never comment it out

# Custom Skills
- **mcg-docx** (`/mcg-docx`): Converts markdown files to MCG-branded Word documents using the bundled MCG template and a hardened OOXML-first pipeline. Located at `~/.claude/skills/mcg-docx/` (-> `~/git/skills/mcg-docx/`). Uses the shared office-skills toolchain plus `mcg-pptx` pack/validate helpers.
- **mcg-pptx** (`/mcg-pptx`): Creates MCG-branded PowerPoint presentations using the official MCG corporate template. Located at `~/.claude/skills/mcg-pptx/` (-> `~/git/pptx/`). Self-contained: all 15 scripts bundled in `scripts/`, template in `assets/`, layout catalog in `references/`. Uses the office-skills Python venv.
- **docx-edit** (`/docx-edit`): Edit existing .docx files in place by unpacking to XML, making targeted edits, and repacking. Preserves all formatting, styles, images, headers, footers, tracked changes. Located at `~/.claude/skills/docx-edit/` (-> `~/git/skills/docx-edit/`). Uses shared office-skills venv + pptx scripts for unpack/pack/validate.
- **skill-creator** (`/skill-creator`): Anthropic's official skill development toolkit. Create, eval, improve, and benchmark Claude Code skills. Located at `~/.claude/skills/skill-creator/` (-> `anthropic-skills/skills/skill-creator/`).
- **mcg-facts** (`/mcg-facts`): MCG Health domain knowledge registry. Provides verified facts about products, Synapse AI, AI position and policy, competitive landscape, partners, strategy, sales messaging, industry context, and market data. Located at `~/.claude/skills/mcg-facts-registry/` (-> `~/git/skills/mcg-facts-registry/`; managed Codex-visible copy publishes to `~/.agents/skills/mcg-facts`). Invoked with `/mcg-facts [topic]` where topic is: products, synapse, ai-position, competitive, partners, strategy, sales, industry, market, glossary, overview, or all. Auto-triggers on MCG-related tasks.
- **url-to-md** (`/url-to-md`): Converts any URL to clean markdown using Defuddle. Saves result with source URL in frontmatter to project directory. Located at `~/.claude/skills/url-to-md/` (-> `~/git/skills/url-to-md/`). Zero external deps (hosted API primary, npx fallback). Runs in fork context.
- **pdf-to-md** (`/pdf-to-md`): Convert PDF files to high-fidelity markdown using ODL (default, fast) or Marker (for complex PDFs with figures/tables/equations). Auto-detects backend via complexity analysis. Supports local files and URLs. Located at `~/.claude/skills/pdf-to-md/` (-> `~/git/skills/pdf-to-md/`). Dedicated venvs at `~/.cache/pdf-to-md/`. Runs in fork context.
- **deep-research** (`/deep-research`): Multi-round parallel research with adversarial challenge. Dispatches 3-5 agents per round to investigate from different angles, synthesizes into opinionated proposal, then challenges its own findings. Located at `~/.claude/skills/deep-research-skill/` (-> `~/git/skills/deep-research-skill/`; Codex copy at `~/.agents/skills/deep-research-skill`). Uses brave-search MCP + url-to-md + pdf-to-md.
- **browser** (`/browser`): Unified browser automation -- fresh Chromium launch + existing Chrome tab connection via CDP. Located at `~/.claude/skills/browser-skill/` (-> `~/git/skills/browser/`). Uses `browser-mcp` MCP server (24 tools with `browser_*` prefix). Two modes: `browser_launch` for clean-state tasks, `browser_connect` for existing logged-in sessions. Runs in fork context.
- **tripit-itinerary** (`/tripit-itinerary`): Creates formatted Google Doc itineraries from TripIt URLs or PDFs with flight durations, Google Maps links, and day-by-day structure. Located at `~/.claude/skills/tripit-itinerary/` (-> `~/git/skills/tripit-itinerary/`). No external deps -- uses Google Docs MCP tools.

# Permissions & Autonomy
- Full permissions for all file, process, and service operations without prompting. Run scripts, access resources/websites, manage services (Claude Desktop, launchctl, dev servers), execute localhost requests -- all without asking.
- Only prompt for: irreversible destructive ops, external cost/billing implications, or genuine uncertainty.
- Act autonomously: execute approved plans, run tests and iterate, commit/push/branch, restart services. Don't ask about implementation details, error handling strategy, scope/features, or credential formats.
- When multiple reasonable approaches exist and none is clearly wrong, pick the best one. Only ask when truly irreversible or high-cost.

# Search
- **Priority**: QMD first (local) -> Brave (web, default) -> WebFetch (known URLs). Run in parallel when both local+web needed.
- **QMD** (`mcp__qmd__query`): Default first step for ANY information need -- before web searches, before Grep, before asking the user. Indexes: git repos (4900+ files), Obsidian vault (830+ notes), OneDrive work files, Downloads.
  - Sub-queries: `lex` (BM25 keyword, supports `"exact phrases"` and `-negation`), `vec` (semantic), `hyde` (hypothetical doc, 50-100 words). Combine for best recall.
  - Always provide `intent` parameter. For unknown vocabulary, use a standalone natural-language query for auto-expansion.
  - Use `mcp__qmd__get`/`multi_get` for full content retrieval.
  - Obsidian results -> use `obsidian-cli` skill for edits. If Obsidian not running, `mcp__qmd__get` for read-only.
  - Fall back to Glob/Grep only for: in-project code patterns needing line precision, QMD returned nothing, or filesystem ops.
- **Brave** (default): `brave_web_search` (general), `brave_news_search` (current events). Use Brave for all web searches unless a specific Exa capability is needed.
- **Exa** (supplementary): `web_search_exa` (semantic, use when Brave results lack depth), `get_code_context_exa` (code/API lookups), `company_research_exa` (business intel). Do not use Exa when Brave suffices.
  - Routing: general/news -> Brave | code/API docs -> Exa `get_code_context_exa` | business intel -> Exa `company_research_exa` | Brave poor results -> retry with Exa `web_search_exa`.
- **Google Workspace**: 94 tools via `mcp__google__*`. Never guess file IDs -- always search first. Always read before modifying. Search Drive in parallel with QMD when task references docs/spreadsheets.

# Codex MCP
- MCP servers live in `~/.claude.json`, not `~/.claude/settings.json`.
- Routed through safe proxy at `~/git/rewriter-skill/scripts/codex-mcp-safe-proxy.mjs` (strips unsupported model overrides).
- Omit explicit OpenAI `model` overrides in `mcp__codex__codex`/`codex-reply`. Defaults from `~/.codex/config.toml`.
- On model-related errors: check `codex login status` and `claude mcp get codex` first.
- **Read-only MCP policy**: use a static allowlist, not a classifier hook. Safe-by-default verbs are `get_`, `list_`, `search_`, `find_`. Do not auto-allow verbs such as `create_`, `update_`, `edit_`, `delete_`, `send_`, `add_`, `remove_`, `upload_`, `download_`, `open_`, `join_`, `mark_`, `set_`, `archive_`, `pin_`, `unpin_`, `complete_`, `reply_`, `share_`, `move_`, `copy_`, `rename_`, or `convert_` unless there is an explicit reason.
- Use `~/git/CLAUDE-md/scripts/audit-mcp-readonly-policy.py` after installing or changing MCP servers to find uncovered safe read-only tools in partially gated namespaces.
- **Slack exception**: `mcp__slack__*` is fully wildcarded in allow. Destructive ops (`send_message`, `delete_message`, `update_message`, `send_ephemeral`, `archive_channel`, `upload_file`) are deny-listed and still prompt. Other Slack write tools (reactions, bookmarks, pins, reminders, channel joins) pass through without prompt.
- **Teams exception**: `mcp__teams__*` is fully wildcarded in allow. Destructive ops (`send_channel_message`, `send_chat_message`, `reply_to_message`, `upload_file`, `create_channel`, `update_channel`, `create_chat`) are deny-listed and still prompt. Preemptive denies for `delete_message`, `update_message`, `archive_*` (don't exist yet). File-saving tools (`download_file`, `get_user_photo`) pass through since Claude already has local filesystem write access. Other Teams read/search/reaction tools pass through without prompt.
- When you launch Claude inside an MCP repo, also inspect project-local `.claude/settings.json` and `.claude/settings.local.json`. A stale exact-tool allowlist there can reintroduce prompts even when the global safe-read baseline is broader.
- After changing MCP permissions, start a fresh Claude shell and check the newest `~/.claude/debug/*` startup snapshot for the expected `mcp__...` allow entries.

# Workflow
- Present a plan before architectural changes and wait for approval.
- Run existing linters, formatters, and tests before proposing changes.
- When uncertain, present options with tradeoffs rather than guessing.

# Git
- **Init**: If not a git repo, run `git init`, create `.gitignore` (covering .env*, *.pem, *.key, *.pfx, credentials.json, service-account*.json, token.json), initial commit. Use `gh auth status` before `gh` commands. If no remote, ask user about `gh repo create`.
- **During session**: Work on `main`. Commit frequently, imperative mood. Push to `origin main` after each logical commit if remote exists.
- **Remote**: Never auto-create -- prompt user. Default `gh repo create --private`; public only when explicitly requested.
- **Safety**: Never force-push. Run `gitleaks detect` before pushing. Never commit secrets. Ask if unsure about file contents. Verify `.gitignore` covers secrets before first commit.
- **Exit**: Stop hook auto-commits as safety net -- prefer explicit commits with good messages during session.

# Session Start

## Orientation Scan (automatic, every session)
Check in order: `~/.claude/error-log.md` (apply lessons) -> `.state/working-state.md` (interrupted work) -> `.state/progress.md` (recent entry) -> `## Session Context` in project CLAUDE.md -> `~/.claude/plans/` (last 48h) -> `.state/research-*.md`, `analysis-*.md`, `draft-outline.md`, `draft-sections/` (interrupted research/doc-gen) -> `/Users/naqi.khan/Documents/Obsidian/LLM History/` (recent project files) -> `.claude/local-context.md` (QMD warmup results). Legacy fallback: also check `.claude/` for working-state.md and progress.md in projects not yet migrated.

Present: artifacts found, 2-3 sentence summary of where things left off, recommended next steps. If nothing found, say so and proceed.

## First Turn
- Start in plan mode (`defaultMode: "plan"`). On task requests: invoke `/prompt` skill (read `~/.claude/skills/prompt/SKILL.md` first, execute full 6-step workflow) to polish input before execution.
- If interrupted work detected: skip `/prompt`, present orientation summary + next steps as plan instead.

# Incremental Work Capture
For tasks with 3+ tool calls, multi-step logic, multi-file changes, or plan mode:
1. **Start**: Write task summary to `.state/working-state.md` (description, phases, target files).
2. **Milestones**: Update with completed work, decisions, remaining items.
3. **Before heavy ops**: Checkpoint to `working-state.md`. When context feels high, suggest `/compact` or `/llm-history`.
4. **Completion**: Delete `working-state.md`, consolidate to `.state/progress.md` + `## Session Context`.
Also use `.state/research-*.md` and `.state/analysis-*.md` for research/analysis tasks. Apply automatically to ALL medium+ tasks.

# Research Tasks
For research/analysis/report/doc-creation tasks:
1. **QMD first** -- always search local knowledge before web searches or file exploration.
2. **Size and default to file-based** -- estimate scope; when uncertain, write artifacts to `.state/` from the start. If task grows beyond expectations (3+ searches, draft >150 lines), STOP and write progress to `.state/research-{topic}.md`.
3. **Write incrementally** -- each phase writes a durable artifact (`research-*.md`, `analysis-*.md`, `plan-*.md`, each <200 lines) to disk before starting the next. Never accumulate all findings in context.
4. **Resume from artifacts** -- on session start, read existing artifacts and continue from next incomplete step. Don't re-run completed phases.
5. **Parallel research** -- use Explore sub-agents for independent questions; combine findings into single artifact.
6. **Compact proactively** -- write progress to artifact, suggest `/compact` or `/llm-history`, read artifact to restore after compaction.
7. **Clean up** -- remove interim `research-*` and `analysis-*` files after task completes. Keep only `.state/progress.md` and deliverables.

# Document Generation
For multi-section documents (reports, specs, guides, proposals):
1. **Outline first** -- write `.state/draft-outline.md` with title, numbered sections, scope, dependencies (`depends_on`), target path.
2. **Parallel writers** -- launch Agent per section in a single message. Each writes to `.state/draft-sections/{NN}-{slug}.md`, returns only a brief summary. Launch dependent sections after their dependencies complete.
3. **Assemble incrementally** -- write first section to output, append subsequent sections one at a time via Edit. Never read all sections into context at once.
4. **Failure/resume** -- retry only failed sections. If `.state/draft-outline.md` and `.state/draft-sections/` exist on session start, generate only missing sections. Never restart from scratch.
5. **Clean up** -- delete outline and draft-sections from `.state/` after delivery. Chain with Research Tasks pattern (QMD first) for research-heavy documents.

# Session Continuity
- At end of meaningful work: update `## Session Context` in project CLAUDE.md (date, state, decisions, next steps, max 20 lines) + append to `.state/progress.md`. Skip routine reads and obvious decisions. Summarize progress.md when >200 lines.
- Stop hook auto-saves session context to Obsidian on exit. Do NOT run `/llm-history` proactively or automatically -- only when the user explicitly requests it. Check `~/Documents/Obsidian/LLM History/` when resuming projects.
- Use `claude --name "<label>"` when starting named-task sessions so they're searchable in `/resume`.
- `--resume` with a non-UUID search string crashes the CLI (upstream bug). Workaround: use bare `--resume` for interactive picker.

# Error Self-Correction
- On user corrections: log to `~/.claude/error-log.md` immediately. Format: `## DATE -- title` + What went wrong / Correction / Category (wrong-command|wrong-file|wrong-assumption|misread-output|config-error|git-error|style-violation|other) / Lesson.
- Each session: read error-log and apply lessons. Check for applicable lessons before repeating error categories.
- When >100 entries: summarize older into Patterns section, remove >30 days old.

# Plan Innovation Prompt
At the end of every plan, include a `## Innovation` section answering: *"What's the single smartest and most radically innovative addition you could make to this plan?"* Keep it concrete and actionable.
