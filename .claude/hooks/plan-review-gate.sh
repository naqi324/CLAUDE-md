#!/bin/sh
# PostToolUse hook (matcher: Edit|Write): reinforce plan review gate.
# Fires after Write/Edit completes. Checks if the file is a plan file.
# stdout is injected as context visible to the LLM on the next decision.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
case "$FILE_PATH" in
  */.claude/plans/*.md)
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null)
    GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"
    cat <<EOF
PLAN REVIEW GATE — present AskUserQuestion before ExitPlanMode.
Question: "How would you like to review this plan?"
Options:
1. Submit for approval — run: touch ${GATE_FILE} — then call ExitPlanMode
2. Run /review-plan — invoke review-plan skill on plan file, then re-present this gate
3. Comments + /review-plan — collect user comments, run review-plan with them, then re-present gate
EOF
    ;;
esac
