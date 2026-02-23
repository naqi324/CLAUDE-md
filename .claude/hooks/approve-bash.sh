#!/bin/bash
# PreToolUse hook: auto-approve all Bash commands.
# The deny list in settings.json still takes precedence over this hook.
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Auto-approved by global PreToolUse hook"
  }
}'
