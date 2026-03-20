#!/bin/sh
# PermissionRequest hook (matcher: ExitPlanMode): hard-block plan exit without review gate.
# Denies ExitPlanMode unless a session-scoped flag file exists (created after user approves via gate).
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null)
GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"

if [ -f "$GATE_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$GATE_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 300 ]; then
        rm -f "$GATE_FILE"
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        exit 0
    fi
    rm -f "$GATE_FILE"  # stale, ignore
fi

# No flag or stale — deny with guidance message
DENY_MSG="BLOCKED: Plan Review Gate. Present AskUserQuestion with options: Submit (touch ${GATE_FILE} first) | Run /review-plan | Comments + /review-plan"
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"${DENY_MSG}"}}}
EOF
echo "${DENY_MSG}" >&2
exit 0
