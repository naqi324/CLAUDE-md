# Reduce Approval Interruptions for Codex + Claude

## Summary
Audit this session’s approval prompts, classify which were low-risk and unnecessary to interrupt for, then install a tiered auto-approval policy in your global Codex/Claude setup.

Goal: keep approvals only for genuinely risky actions (destructive ops, broad remote side effects, secrets), while auto-allowing routine setup/validation and trusted config writes.

## Session Review: Low-Risk Prompts You Likely Didn’t Need
- Writing `.codex/progress.md` in repo.
- Appending `.codex/progress.md` again for session logs.
- Reading `~/.claude.json` top-level keys.
- Running `gh auth status`.
- Running `claude mcp list`, `codex mcp list`.
- Running local setup/validation scripts that only checked tools/status.
- Creating a local feature branch (`git checkout -b ...`) in this repo.
- Creating/updating symlinks in `~/.codex/skills` and `~/.claude/skills` to a trusted local repo path.

These are low/minimal risk because they are either read-only, repo-local metadata updates, or bounded writes to known user config/skill paths.

## Approval Rules to Add Globally

### 1) Always auto-allow read-only diagnostics
Allow without prompts:
- `gh auth status`
- `gh repo view`
- `git status`, `git branch -vv`, `git log`, `git remote -v`, `git fetch --prune`
- `claude mcp list`, `claude mcp get`
- `codex mcp list`, `codex mcp get`
- `jq`, `ls`, `cat`, `sed`, `rg`, `find`, `stat`

### 2) Auto-allow bounded local writes in trusted repos
Allow without prompts in trusted workspaces:
- writing `.codex/progress.md`
- updating `AGENTS.md` session context
- creating branches (`git checkout -b ...`)
- non-destructive git operations (`git add`, `git commit`)

Keep prompts for:
- `git reset --hard`, `git checkout --`, `rm -rf`, history rewrites

### 3) Auto-allow MCP config operations
For your own machine, allow:
- `claude mcp add/list/get/remove`
- `codex mcp add/list/get/remove`

Rationale: these touch only user MCP config and were core to your workflow.

### 4) Auto-allow skill symlink maintenance
Allow `ln -sfn` updates only for:
- source under `/Users/naqi.khan/git/*`
- targets under `~/.codex/skills/*` and `~/.claude/skills/*`

### 5) Keep approvals for medium/high-risk remote operations
Keep prompt required for:
- `gh repo create`, `gh repo edit` (repo-level side effects)
- `git push` to remote branches (unless explicitly requested in current prompt)
- branch deletion on remote

Optional stricter relaxation:
- auto-allow `git push origin <current-branch>` only when branch is not `main`
- still prompt for pushes/deletes involving `main`

### 6) Claude runtime permission policy
For unattended browser automation runs, default to:
- `claude -p --permission-mode bypassPermissions` in trusted environments

For interactive/manual runs, keep normal permission mode.

This removes tool-use interruptions like `browser_navigate` denials.

## Important Interfaces / Config Surfaces to Update
- Codex:
  - global approved command prefixes (trusted prefixes list)
  - default approval mode for trusted projects
- Claude Code:
  - default invocation alias/profile for unattended MCP runs
  - MCP command allowlist and trusted skill paths
- Shell:
  - wrapper aliases/scripts for common “safe auto” commands

## Validation Scenarios
### Scenario 1: Run setup + validate scripts in trusted repo.
Expected: zero approval prompts.

### Scenario 2: MCP list/get/add operations.
Expected: no prompts; config updated correctly.

### Scenario 3: Session log writes (`.codex/progress.md`).
Expected: no prompts.

### Scenario 4: `git push origin main`.
Expected: still prompts unless explicitly relaxed.

### Scenario 5: destructive command (`git reset --hard`).
Expected: always prompts/blocked.

## Assumptions and Defaults
- Assumption: your home machine and these repo paths are trusted.
- Default safety posture:
  - aggressively auto-allow read-only + bounded local config writes
  - keep prompts for destructive actions and high-impact remote actions
- Default branch protection:
  - keep stricter prompts around `main` operations unless explicitly requested.
