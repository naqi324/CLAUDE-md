#!/bin/bash
# PreToolUse hook: auto-approve all Bash commands.
# Deny list in settings.json still takes precedence.
cat > /dev/null
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by global PreToolUse hook"
  }
}'
