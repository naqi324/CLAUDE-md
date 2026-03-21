# Session Progress Log

## 2026-02-16 -- Add session continuity protocol

**Summary**: Implemented a two-tier session continuity system to preserve working context across Claude Code sessions.

**What was done**:
- Added `## Session Continuity` section to both global (`~/.claude/CLAUDE.md`) and project CLAUDE.md with behavioral instructions for maintaining session artifacts
- Added `## Session Context` section to project CLAUDE.md as a live quick-reference snapshot
- Created `.claude/progress.md` (this file) as a rolling detailed session log
- Updated `README.md` with documentation of the session continuity feature

**Design decisions**:
- Two-tier approach: Session Context in CLAUDE.md for quick orientation, progress.md for detailed history. This avoids bloating CLAUDE.md while still giving immediate context on session start.
- Session Context is overwritten each session (current state only); progress.md is append-only (historical record).
- progress.md is tracked in git by default so session history is shared across machines. Projects can add it to .gitignore if unwanted.
- Global CLAUDE.md gets the behavioral instructions only (not Session Context), since Session Context is per-project data.
- Growth management: progress.md entries get summarized into a Historical Summary section when the file exceeds ~200 lines.

**Files modified**:
- `CLAUDE.md` — added Session Continuity instructions + Session Context section
- `~/.claude/CLAUDE.md` — added Session Continuity instructions only
- `.claude/progress.md` — created (this file)
- `README.md` — added session continuity documentation

**Next steps**:
- Use this protocol across multiple sessions to validate the instructions
- Refine wording based on practical experience
- Consider whether progress.md should have a machine-readable format for tooling

## 2026-02-19 -- Optimize global CLAUDE.md and deduplicate project CLAUDE.md

**Summary**: Trimmed global `~/.claude/CLAUDE.md` from 93 lines to 23 lines by removing content that is redundant with Claude Code defaults, vague mindset coaching, linter-enforceable rules, or project-specific policies. Replaced project CLAUDE.md with project-specific content only.

**What was done**:
- Rewrote `~/.claude/CLAUDE.md` to 4 sections (Preferences, Workflow, Git Safety, Session Continuity) totaling 23 lines
- Replaced project CLAUDE.md — removed all duplicated global instructions, kept only project description and Session Context
- Updated this progress log

**Design decisions**:
- Removed Naming Conventions, Folder Structure, Documentation, Code Quality, Permission Auto-Approval, and most Collaboration rules — all either redundant with Claude defaults or too vague to be actionable
- Compressed Session Continuity from 38 lines of prose to 5 bullet points with identical information density
- Project CLAUDE.md should contain only project-specific instructions; global instructions live exclusively in `~/.claude/CLAUDE.md`

**Files modified**:
- `~/.claude/CLAUDE.md` — rewritten (93 → 23 lines)
- `CLAUDE.md` — replaced with project-specific content (100 → 11 lines)
- `.claude/progress.md` — appended this entry

**Next steps**:
- Validate session continuity triggers correctly in a fresh session
- Apply same deduplication pattern to other project CLAUDE.md files

## 2026-02-21 -- Add Claude skill reconciliation and restore improve-prompt alias

**Summary**: Added manifest-driven Claude skill symlink management and repaired the missing improve-prompt global alias.

**What was done**:
- Added `.claude/skills-manifest.json` to declare canonical global skill link targets.
- Added `scripts/reconcile-skills.sh` to enforce global symlinks in `~/.claude/skills`.
- Added `scripts/check-skills-health.sh` to validate symlink targets and required SKILL frontmatter.
- Added compatibility alias coverage for both `improve-prompt-skill` and `prompt-improver` names.
- Updated `README.md` and `CLAUDE.md` Session Context.

**Design decisions**:
- Keep alias compatibility to avoid breaking legacy trigger names after repo/path changes.
- Use repository-local manifest as source of truth for global `~/.claude/skills` symlinks.
- Fail health checks on missing links, bad targets, or malformed SKILL frontmatter.

**Files modified**:
- `CLAUDE.md`
- `README.md`
- `.claude/skills-manifest.json`
- `.claude/progress.md`
- `scripts/reconcile-skills.sh`
- `scripts/check-skills-health.sh`

**Next steps**:
- Run `./scripts/reconcile-skills.sh` and `./scripts/check-skills-health.sh`.
- Run `gitleaks detect --source . --no-git` before push.

## 2026-02-21 -- Reduce approval interruptions and add error self-correction logging

**Summary**: Analyzed 3 session approval logs, identified 5 categories of unnecessary interruptions, and upgraded both the global Claude config (`~/.claude/CLAUDE.md` + `~/.claude/settings.json`) to reduce prompting. Added a persistent error self-correction mechanism.

**What was done**:
- Analyzed `approvals-01.md`, `approvals-02.md`, `approvals-03.md` for interruption patterns.
- Added 27 new entries to `~/.claude/settings.json` `permissions.allow` (Write, Edit, NotebookEdit, pkill, launchctl, rm, bash, sh, script execution, etc.).
- Added 10 new entries to `permissions.deny` (destructive home-dir rm, system process kills, sudo).
- Replaced Permissions section in both global and project CLAUDE.md with a tiered auto-approve policy.
- Added Error Self-Correction section to both global and project CLAUDE.md.
- Created `~/.claude/error-log.md` as persistent cross-session error log.

**Design decisions**:
- Tiered permission model: auto-approve everything except irreversible destructive ops, external cost/billing, and genuinely uncertain actions.
- Error log uses category-based entries with lessons for cross-session learning.
- Error log has growth management: summarize into Patterns section after ~100 entries, prune entries older than 30 days.
- Deny list targets system-critical processes (loginwindow, WindowServer, Finder, Dock) and home directory rm -rf patterns.

**Files modified**:
- `~/.claude/CLAUDE.md` — replaced Permissions, added Error Self-Correction
- `~/.claude/settings.json` — added 27 allow entries, 10 deny entries
- `~/.claude/error-log.md` — created
- `CLAUDE.md` — synced Permissions and Error Self-Correction, updated Session Context
- `.claude/progress.md` — appended this entry

**Next steps**:
- Validate reduced interruptions in a fresh Claude Code session.
- Monitor error-log.md accumulation and test pattern summarization trigger.

## 2026-03-07 -- Make Claude Code use Codex MCP safely under ChatGPT login

**Summary**: Added a Codex MCP safety proxy and repointed the global Claude `codex` server to it so Claude Code stops sending unsupported OpenAI model overrides to ChatGPT-backed Codex auth.

**What was done**:
- Confirmed `claude mcp get codex` was healthy but the failing path was Claude passing `model` values such as `gpt-5.4-xhigh`, `o3`, and `gpt-4.1` into `mcp__codex__codex`.
- Added `scripts/codex-mcp-safe-proxy.mjs` in `rewriter-skill` to forward MCP traffic to `codex mcp-server` while stripping unsupported `model` overrides.
- Added `scripts/verify-codex-mcp-safe-proxy.mjs` and used it for a live end-to-end smoke test against the real Codex backend.
- Repointed the global Claude user-level `codex` server in `~/.claude.json` to the proxy with `claude mcp remove/add`.
- Updated both `~/.claude/CLAUDE.md` and `CLAUDE.md` with Codex MCP guidance and the `~/.claude.json` source-of-truth note.

**Design decisions**:
- Keep the existing ChatGPT-backed Codex login rather than switching auth providers.
- Strip explicit OpenAI model overrides at the MCP boundary instead of trusting Claude to omit them consistently.
- Preserve standalone Codex defaults in `~/.codex/config.toml` rather than hardcoding model policy in the proxy.

**Files modified**:
- `CLAUDE.md`
- `.claude/progress.md`

**Next steps**:
- Restart Claude desktop if it still has the old MCP command cached.
- Re-run the verifier after any future Codex auth change or major Codex CLI upgrade.

## 2026-03-19 -- Fix Stop hook reliability and document --resume crash

**Summary**: Fixed intermittent llm-history Stop hook failures by daemonizing the slow `claude -p` call into a detached worker process. Added SessionEnd fallback, error logging, and documented upstream `--resume` CLI bug.

**What was done**:
- Split `llm-history-save.sh` into fast dispatcher + detached `llm-history-worker.sh` via nohup
- Changed dedup lock from `${SESSION_ID}-${HOOK_EVENT}.saved` to event-agnostic `${SESSION_ID}-save.saved`
- Lock created in dispatcher before fork (eliminates race between Stop and SessionEnd)
- Added SessionEnd hook to `~/.claude/settings.json` as belt-and-suspenders
- Added `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS=130000` to `~/.zprofile`
- Added error logging to all hook scripts (`/tmp/llm-history-hook.log`, `worker.log`, `auto-git-commit.log`)
- Worker uses `timeout 90` on `claude -p` to prevent orphan accumulation
- Worker handles missing `last_assistant_message` (unavailable on SessionEnd)
- Documented `--resume` crash (upstream bug) and `--name` best practice in CLAUDE.md and error-log.md

**Design decisions**:
- Daemonize via nohup rather than making hook synchronous (avoids 60s exit delay)
- Event-agnostic lock eliminates race between Stop and SessionEnd without needing coordination
- Lock in dispatcher (not worker) closes the race window to near-zero

**Files modified**:
- `~/git/llm-history/scripts/llm-history-save.sh` — refactored into dispatcher
- `~/git/llm-history/scripts/llm-history-worker.sh` — created (detached worker)
- `.claude/hooks/auto-git-commit.sh` — added error logging
- `~/.claude/settings.json` — added SessionEnd hook
- `~/.zprofile` — added SessionEnd timeout env var
- `~/.claude/CLAUDE.md` — added `--name` and `--resume` guidance
- `~/.claude/error-log.md` — added `--resume` crash entry

**Next steps**:
- Test in fresh session: verify dispatcher logs, worker completes, LLM history entry appears
- Stress test: close terminal mid-session, verify detached worker still completes

## 2026-03-20 -- Repair config parity and harden plan-gate recovery

**Summary**: Repaired the tracked/live Claude config mirror, implemented the unshipped AskUserQuestion gate marker flow from the handoff, and added parity/auditing utilities so future drift is detectable.

**What was done**:
- Replaced the stale tracked `CLAUDE.md` with the real live global Claude instructions and updated the Plan Review Gate / Plan Innovation Prompt sections to match the new recovery behavior.
- Added `.claude/hooks/plan-gate-shared.sh` as the single source for the four gate options and exact AskUserQuestion parameter wording.
- Added `.claude/hooks/plan-gate-asked.sh` and registered a new `PostToolUse` matcher for `AskUserQuestion` in `.claude/settings.json`.
- Refactored `plan-exit-gate.sh` so the first deny path emits the directive AskUserQuestion recovery block, while the post-gate/no-flag path emits the shorter submit instruction.
- Refactored `plan-review-gate.sh` and `inject-datetime.sh` to reuse the same exact parameter block as the deny path.
- Expanded `test-plan-gate.sh` from 32 to 45 passing smoke tests, covering gate-marker creation, jq-less fallback for the new hook, directive wording, option order, shorter post-gate denial, and cleanup of the gate marker on allow.
- Added `scripts/check-config-parity.sh` to diff repo/live `CLAUDE.md` and `.claude/settings.json` and verify repo hook targets exist.
- Added `scripts/audit-plan-gate.sh` to summarize plan-gate compliance from `/tmp/plan-review-gate.log`.
- Synced the live `~/.claude/CLAUDE.md` mirror to match the repaired tracked file; `~/.claude/settings.json` was already identical after the repo edit.

**Validation**:
- `sh .claude/hooks/test-plan-gate.sh` -> 45/45 passed
- `./scripts/check-config-parity.sh` -> passed
- `./scripts/audit-plan-gate.sh` -> runs successfully
- Real CLI smoke test could not complete because local `claude -p` returned `Not logged in · Please run /login`

**Files modified**:
- `CLAUDE.md`
- `README.md`
- `.claude/settings.json`
- `.claude/hooks/plan-exit-gate.sh`
- `.claude/hooks/plan-review-gate.sh`
- `.claude/hooks/inject-datetime.sh`
- `.claude/hooks/test-plan-gate.sh`
- `.claude/hooks/plan-gate-asked.sh`
- `.claude/hooks/plan-gate-shared.sh`
- `scripts/check-config-parity.sh`
- `scripts/audit-plan-gate.sh`
- `.state/progress.md`

**Next steps**:
- Log into the local `claude` CLI and rerun a sacrificial manual plan-mode smoke test.
- Commit the repo changes once you are happy with the mirror contract and the new gate behavior.

## 2026-03-20 -- Auto-approve read-only Slack MCP lookups

**Summary**: Added a narrow Slack read-only allowlist to the global Claude permissions so Slack search/list/get/find operations stop prompting by default while Slack write and state-changing actions remain gated.

**What was done**:
- Added four Slack MCP permission patterns to the tracked repo mirror `.claude/settings.json`:
  - `mcp__slack__slack_search_*`
  - `mcp__slack__slack_list_*`
  - `mcp__slack__slack_get_*`
  - `mcp__slack__slack_find_user_by_email`
- Applied the same four patterns to the live `~/.claude/settings.json` mirror.
- Intentionally did not allow `mcp__slack__*`, so send/edit/delete/update/download/open-conversation/join-channel/admin actions still require approval.

**Validation**:
- Confirmed both settings files parse as valid JSON after the change.
- Confirmed the repo and live settings mirrors now contain identical Slack allow entries.
- Fresh-session behavioral verification still requires a new Claude shell session to load the updated settings.

**Next steps**:
- Start a fresh Claude shell session and verify `slack_search_messages`, `slack_list_channels`, `slack_get_channel_history`, and `slack_find_user_by_email` no longer prompt.
- Confirm `slack_send_message`, `slack_update_message`, `slack_delete_message`, `slack_mark_read`, `slack_open_conversation`, and `slack_download_file` still prompt.

## 2026-03-20 -- Formalize static read-only MCP policy

**Summary**: Added a documented static read-only MCP classification policy and an audit utility so future partially gated MCP namespaces can be reviewed systematically instead of by ad hoc permission additions.

**What was done**:
- Documented the static read-only MCP rule in `README.md` and `CLAUDE.md`.
- Defined safe-by-default verbs as `get_`, `list_`, `search_`, and `find_`.
- Defined the non-safe-by-default verb set covering create/update/edit/delete/send/add/remove/upload/download/open/join/mark/set/archive/pin/unpin/complete/reply/share/move/copy/rename/convert actions.
- Added `scripts/audit-mcp-readonly-policy.py` to inspect installed MCP servers from `~/.claude.json`, compare repo/live settings mirrors, and classify partially gated namespaces.
- Wired Slack in as the reference partially gated namespace with current non-admin read-only coverage, admin read exclusions, and intentionally gated state-changing tools.

**Validation**:
- The audit script should show whole-server wildcards for `qmd`, `mail`, `browser-mcp`, `atlassian`, `brave-search`, `exa`, `google`, and `codex`.
- The first audit run surfaced two uncovered safe read-only Slack tools: `slack_find_people` and `slack_find_conversations`.
- Broadened the Slack read-only allow entry from `mcp__slack__slack_find_user_by_email` to `mcp__slack__slack_find_*` in both repo and live settings mirrors.
- The final Slack section should show non-admin read-only tools as covered, admin reads as intentionally excluded, and state-changing tools as intentionally gated.

**Next steps**:
- Run `./scripts/audit-mcp-readonly-policy.py`.
- If it reports an uncovered safe read-only tool in a partially gated namespace, add a targeted allow entry rather than widening the whole namespace.

## 2026-03-20 -- Sync Slack MCP local override with global safe-read baseline

**Summary**: Traced the remaining Slack approval prompts to a stale project-local Slack MCP override file and extended the MCP audit to catch local permission drift against the global safe-read baseline.

**What was done**:
- Confirmed the live global Slack allowlist already covered `mcp__slack__slack_search_*`, `mcp__slack__slack_list_*`, `mcp__slack__slack_get_*`, and `mcp__slack__slack_find_*`.
- Found `/Users/naqi.khan/git/mcps/slack-mcp/.claude/settings.local.json` carrying an older exact-tool subset that did not include newer safe read-only Slack tools such as `slack_find_people`.
- Replaced that local subset with the same four safe-read wildcards while preserving the intentional local exception for `mcp__slack__slack_open_conversation`.
- Extended `scripts/audit-mcp-readonly-policy.py` to inspect known project-local `.claude/settings.json` and `.claude/settings.local.json` files and emit a drift warning when a local Slack policy is narrower than the global safe-read baseline.
- Updated `README.md` and `CLAUDE.md` to document project-local MCP permission drift and the need to restart Claude shell sessions after permission changes.

**Validation**:
- Repo and live global `settings.json` still expose identical Slack wildcard allow entries.
- The Slack MCP local settings file now includes the global safe-read wildcards plus the preserved explicit local exception.
- `./scripts/audit-mcp-readonly-policy.py` now reports the Slack MCP local override as aligned instead of warning about a narrower local subset.
- A fresh `claude --debug-file /tmp/claude-slack-startup.log -p "Reply with ok."` process launched in `/Users/naqi.khan/git/mcps/slack-mcp` loaded both the global Slack wildcard entries and the local override file in its startup snapshot.
- The CLI still exited before a real tool invocation with `Not logged in · Please run /login`, so end-to-end live no-prompt verification is still blocked on Claude auth.

**Next steps**:
- Run `./scripts/audit-mcp-readonly-policy.py` and confirm the local override audit reports alignment.
- Start a fresh Claude shell in `/Users/naqi.khan/git/mcps/slack-mcp` and verify `slack_find_people` no longer prompts.
