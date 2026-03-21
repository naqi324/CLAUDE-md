# Codex Handoff: Plan Review Gate & Innovation Prompt Hardening

**Date**: 2026-03-20
**Project**: `~/git/CLAUDE-md` — Claude Code configuration management (hooks, settings, CLAUDE.md)
**Branch**: `main` (all work committed and pushed)

---

## 1. Problem Statement

The user wants two behaviors to occur **every single time** Claude Code is in plan mode:

1. **Plan Review Gate**: After the plan is written, the model MUST present an `AskUserQuestion` with 4 specific options (Submit / Run review-plan / Incorporate innovation / Review + incorporate innovation) before calling `ExitPlanMode`.

2. **Innovation Prompt**: Every plan MUST contain a `## Innovation` heading with a concrete suggestion. The user should be able to act on it (incorporate it into the plan) via the gate options.

**Current state**: Both behaviors are sporadic. The review-plan options appear inconsistently. The innovation prompt is missing from ~72% of historical plans. When the innovation IS present, the user often can't act on it because the gate doesn't surface it.

---

## 2. What Was Built (4 commits, all shipped)

### Commit `54e1ba4` — Content validation + comprehensive deny messages

**The hard enforcement layer.** ExitPlanMode is blocked at the PermissionRequest hook level unless:
1. A plan file breadcrumb exists (`/tmp/claude-plan-path-${SESSION_ID}`)
2. The plan contains a `## Innovation` heading (`grep -qi '^##.*innovat'`)
3. A session-scoped flag file exists and is fresh (`/tmp/claude-plan-gate-${SESSION_ID}`)

Key design: innovation check does NOT consume the flag file, so the user can fix and retry.

**Files**:
- `.claude/hooks/plan-exit-gate.sh` — PermissionRequest hook (matcher: ExitPlanMode), ~120 lines
- `.claude/hooks/plan-review-gate.sh` — PostToolUse hook (matcher: Edit|Write), writes breadcrumb + warns about missing innovation
- `.claude/hooks/test-plan-gate.sh` — 24 tests at this point

### Commit `3867712` — Agent nudge hook

Prevents model from stalling after Explore/Plan agents complete (model would end its turn without writing the plan file).

**Files**:
- `.claude/hooks/plan-mode-agent-nudge.sh` — PostToolUse hook (matcher: Agent), fires only for Explore|Plan subagent types
- Tests: 24 → 27

### Commit `7415cc2` — 4-option gate layout

Replaced 3-option gate (Submit / Review / Comments) with 4-option gate:
1. Submit for approval
2. Run /review-plan
3. **Incorporate innovation** — integrate innovation into plan steps
4. **Review + incorporate innovation** — incorporate then review

Updated in both hooks (PostToolUse heredoc + PermissionRequest GATE_TEXT).

### Commit `c4b701e` — TTL increase + denial escalation + UserPromptSubmit reminder

- Flag TTL: 300s → 600s (review workflows take 5-10min; logs showed flag expiring at 348s)
- Denial count tracking: on 2nd+ ExitPlanMode denial, prepends "CRITICAL: This is denial #N. STOP retrying."
- UserPromptSubmit hook (`inject-datetime.sh`): when any plan breadcrumb exists (mtime < 30min), injects gate reminder on user's next prompt
- Tests: 27 → 32

---

## 3. Current Architecture

### Hook chain (registered in `~/.claude/settings.json`):

```
PostToolUse:
  (no matcher)     → ghostty-hook-title.sh (terminal title)
  Edit|Write       → plan-review-gate.sh (breadcrumb + gate reminder)
  Agent            → plan-mode-agent-nudge.sh (continuation nudge)

PermissionRequest:
  ExitPlanMode     → plan-exit-gate.sh (3-check validation + deny with gate spec)

UserPromptSubmit:
  (no matcher)     → inject-datetime.sh (datetime + mtime-based gate reminder)

Stop/SessionEnd/PreCompact/SessionStart: (unrelated hooks, not part of gate)
```

### Three-layer defense:

| Layer | Type | Mechanism | Effectiveness |
|-------|------|-----------|---------------|
| CLAUDE.md instructions | Behavioral (soft) | Model reads and follows instructions | Inconsistent — works most of the time |
| PostToolUse hook output | Context injection (soft) | Text injected into tool result after Write/Edit | Model sees it but may not act on it |
| PermissionRequest deny | Hard block | ExitPlanMode is blocked; deny message delivered to model | **Always blocks** — model recovery is the problem |

### Temp file state:

| File | Created by | Consumed by | Purpose |
|------|-----------|-------------|---------|
| `/tmp/claude-plan-path-${SID}` | plan-review-gate.sh | plan-exit-gate.sh | Breadcrumb: which plan file was written |
| `/tmp/claude-plan-gate-${SID}` | User via `touch` | plan-exit-gate.sh | Flag: user approved via gate |
| `/tmp/claude-gate-deny-count-${SID}` | plan-exit-gate.sh | plan-exit-gate.sh | Denial counter for escalation |

---

## 4. The Core Unsolved Problem

**The hard block works. The model's recovery after being blocked does not.**

When ExitPlanMode is denied:
1. The model receives the deny `message` as mandatory context (confirmed by research)
2. Per Claude Code GitHub #29795: "When one tool is blocked, Claude actively seeks alternative tools to achieve the same goal"
3. The model continues working on OTHER tasks (editing non-plan files) instead of presenting AskUserQuestion
4. The model may retry ExitPlanMode without presenting the gate (the escalation counter mitigates this somewhat)

**Evidence from session `71454778`**: ExitPlanMode denied at 17:04, then model wrote `package.json`, `tsconfig.json`, `src/types.ts` etc. — never presented the gate.

**Evidence from session `1a14df45`**: 3 ExitPlanMode attempts in 13 minutes (16:40, 16:48, 16:53), each denied, model editing non-plan files between denials.

### Why this is architecturally hard:

- No hook can intercept `AskUserQuestion` (GitHub #12605 — requested, not implemented)
- No native "call A before B" mechanism in Claude Code
- Transcript-based validation is fragile (JSONL parsing in shell; deny messages contain "AskUserQuestion" text creating false positives)
- The deny message is the **ONLY leverage point** for recovery behavior
- CLAUDE.md and PostToolUse reminders are too far back in context by the time denial happens

---

## 5. Unimplemented Plan (Ready for Execution)

The following changes were designed, reviewed (3 rounds of /review-plan with fresh-context subagents), and refined but NOT yet implemented:

### Change 1: Restructure deny message as directive recovery command

Replace the conversational `GATE_TEXT` in `plan-exit-gate.sh` with a shorter, more directive format:

```
STOP. Do NOT call ExitPlanMode again. Your next tool call MUST be AskUserQuestion with these EXACT parameters:
question: "How would you like to review this plan?"
header: "Review"
option 1 — label: "Submit for approval", description: "Run: touch ${GATE_FILE} then call ExitPlanMode"
option 2 — label: "Run /review-plan", description: "Fresh-context 6-dimension plan review, then re-present this gate"
option 3 — label: "Incorporate innovation", description: "Integrate innovation idea into plan steps, then re-present gate"
option 4 — label: "Review + incorporate innovation", description: "Incorporate innovation then run /review-plan, then re-present gate"
```

**Rationale**: "STOP" as pattern interrupt. Parameters mirror AskUserQuestion tool schema to reduce translation effort. Shorter = less for model to lose track of.

Also update `plan-review-gate.sh` PostToolUse heredoc to match.

### Change 2: Content-matched gate-asked breadcrumb

New PostToolUse hook (matcher: `AskUserQuestion`) that writes `/tmp/claude-gate-asked-${SESSION_ID}` ONLY when:
- A plan breadcrumb exists (we're in plan mode)
- The AskUserQuestion's `tool_input.questions[0].question` contains "review this plan"

This is deterministic proof the gate was presented. The exit gate checks for it: if gate-asked exists but flag is missing, gives a shorter deny: "Gate was presented but flag file not created. Run: touch ${GATE_FILE}"

Content matching eliminates false positives from non-gate AskUserQuestion calls.

**New file**: `.claude/hooks/plan-gate-asked.sh`
**Settings**: Add `AskUserQuestion` PostToolUse matcher in `~/.claude/settings.json`

### Change 3: Shared gate-options.txt (optional, reduces maintenance)

Extract the 4-option gate spec into a single file read by both hooks. Eliminates the 3-place duplication (plan-exit-gate.sh GATE_TEXT, plan-review-gate.sh heredoc, CLAUDE.md).

---

## 6. Research Findings (from 3 parallel deep-research agents)

### Agent 1: Hook Mechanics
- PermissionRequest deny `message` IS delivered to model as mandatory context
- Tool call is blocked at engine level — model cannot bypass
- PostToolUse output goes to stdout, injected as context
- Known: "When one tool is blocked, Claude actively seeks alternative tools" (GitHub #29795)

### Agent 2: Empirical Patterns
- 72% of historical plans lack Innovation sections (pre-requirement plans inflate this)
- Real sessions show "ignore and retry" pattern — model retries ExitPlanMode without presenting gate
- After denial, model shifts to other tasks rather than recovering
- Gap between test paths (all work) and real behavior (recovery fails)

### Agent 3: Alternative Approaches
- No hook can intercept AskUserQuestion — closes entire class of solutions
- Tool sequencing NOT natively supported — no "call A before B" mechanism
- Transcript-based validation possible but fragile (JSONL parsing + false positives from deny text)
- Current three-layer approach is architecturally optimal given constraints
- PreToolUse hook on ExitPlanMode could inject `systemMessage` via `allow` response (unverified — needs testing)

---

## 7. Files Reference

### Hooks (all in `~/git/CLAUDE-md/.claude/hooks/`):

| File | Matcher | Purpose | Lines |
|------|---------|---------|-------|
| `plan-exit-gate.sh` | ExitPlanMode (PermissionRequest) | 3-check validation, deny with gate spec, escalation | 120 |
| `plan-review-gate.sh` | Edit\|Write (PostToolUse) | Breadcrumb write, innovation warning, gate reminder | 53 |
| `plan-mode-agent-nudge.sh` | Agent (PostToolUse) | Continuation nudge for Explore/Plan agents | 23 |
| `inject-datetime.sh` | (UserPromptSubmit) | Datetime + mtime-based gate reminder | 10 |
| `test-plan-gate.sh` | N/A | 32 smoke tests covering all gate paths | 210 |
| `plan-gate-asked.sh` | **NOT YET CREATED** | Content-matched gate-asked breadcrumb | ~20 |

### Config:
- `~/.claude/settings.json` — Hook registration (PostToolUse: 3 entries, PermissionRequest: 1 entry)
- `~/.claude/CLAUDE.md` — Plan Review Gate section (lines 101-120), Plan Innovation Prompt (lines 122-126)

### Logs:
- `/tmp/plan-review-gate.log` — Unified log for all gate hooks (PostToolUse, PermReq, AgentNudge, GateAsked)

---

## 8. What Codex Should Do

### Priority 1: Implement the unimplemented plan (Section 5)
1. Restructure GATE_TEXT in `plan-exit-gate.sh` to directive format
2. Update `plan-review-gate.sh` heredoc to match
3. Create `plan-gate-asked.sh` + register in settings.json
4. Add gate-asked check to `plan-exit-gate.sh`
5. Add tests, run full suite

### Priority 2: Investigate the core recovery problem deeper
The deny message is the only leverage point. Research:
- Does the `message` field in PermissionRequest deny responses support markdown, structured data, or only plain text?
- Can PreToolUse hooks inject a `systemMessage` alongside an `allow` decision? (Unverified claim from research)
- Are there Claude Code plugins or settings that can enforce tool ordering?
- What do other Claude Code power users do for behavioral enforcement? Search GitHub issues, Discord, forums.

### Priority 3: Consider architectural alternatives
- Could a custom MCP tool wrap ExitPlanMode with built-in gate logic?
- Could the plan mode system prompt be modified via a SessionStart hook?
- Is there a way to make AskUserQuestion hookable (GitHub #12605)?

---

## 9. Test Suite

Run: `sh ~/git/CLAUDE-md/.claude/hooks/test-plan-gate.sh`

Current: 32/32 pass. Covers:
- PostToolUse: plan files trigger gate, non-plan silent, empty input, innovation warning
- PermissionRequest: no-breadcrumb deny, innovation deny, fresh flag allow, stale flag deny, flag preservation on innovation failure
- jq-less fallback mode
- Agent nudge: Explore/Plan fire, general-purpose silent
- TTL boundaries: 500s allow, 700s deny-stale
- Denial escalation: 2nd denial shows CRITICAL, allow cleans up count file
