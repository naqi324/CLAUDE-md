#!/bin/sh
# PostToolUse hook (matcher: Agent): prevent plan mode stalling after agent calls.
# Only fires for Explore|Plan subagent types. Injects a single-line continuation nudge.
LOG="/tmp/plan-review-gate.log"

INPUT=$(cat)
[ -z "$INPUT" ] && exit 0

# Extract subagent_type — only nudge for plan-mode agent types
SUBAGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$INPUT" | grep -o '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)
SESSION_ID="${SESSION_ID:-${PPID:-default}}"

case "$SUBAGENT" in
  Explore|Plan)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AgentNudge session=${SESSION_ID} subagent=${SUBAGENT} result=fired" >> "$LOG" 2>/dev/null
    echo "PLAN MODE: Agent complete. Write findings to the plan file NOW, then AskUserQuestion or ExitPlanMode. Do not end your turn without a tool call."
    ;;
  *)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] AgentNudge session=${SESSION_ID} subagent=${SUBAGENT} result=skipped" >> "$LOG" 2>/dev/null
    ;;
esac
