#!/bin/sh
# PreToolUse hook (matcher: ExitPlanMode): block plan exit without ## Innovation.
INPUT=$(cat)

PLANS_DIR="$HOME/.claude/plans"
[ -d "$PLANS_DIR" ] || exit 0

# Most recently modified main plan (exclude agent sub-plans)
PLAN=$(ls -t "$PLANS_DIR"/*.md 2>/dev/null | grep -v -- '-agent-a' | head -1)
[ -z "$PLAN" ] && exit 0

# Check for ## Innovation heading
grep -qi '^## .*innovat' "$PLAN" && exit 0

# Block: missing Innovation section
BASENAME=$(basename "$PLAN")
jq -n --arg reason "BLOCKED: Plan '$BASENAME' missing required '## Innovation' section. Add '## Innovation' with one concrete, actionable idea, then call ExitPlanMode again." \
'{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "block",
    "permissionDecisionReason": $reason
  }
}'
