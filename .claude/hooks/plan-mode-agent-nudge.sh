#!/bin/sh
# PostToolUse hook (matcher: Agent): prevent plan mode stalling after agent calls.
INPUT=$(cat)
[ -z "$INPUT" ] && exit 0

SUBAGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
[ -z "$SUBAGENT" ] && SUBAGENT=$(echo "$INPUT" | grep -o '"subagent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//')

case "$SUBAGENT" in
  Explore|Plan)
    echo "PLAN MODE: Agent complete. Write findings to the plan file, then continue planning. Do not end your turn without a tool call."
    ;;
esac
