#!/bin/sh
# PostToolUse hook (matcher: Write): reinforce plan review gate.
# Fires after Write completes. Checks if the written file is a plan file.
# stdout is injected as context visible to the LLM on the next decision.
INPUT=$(cat)

# Extract file_path from tool input JSON
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only inject reminder when writing to the plans directory
case "$FILE_PATH" in
  */.claude/plans/*.md)
    echo "Plan review gate: You just wrote a plan file. Before calling ExitPlanMode, present AskUserQuestion with options: Submit for approval | Run /review-plan | Comments + /review-plan."
    ;;
esac
