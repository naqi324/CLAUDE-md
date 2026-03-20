#!/bin/sh
# PermissionRequest hook (matcher: ExitPlanMode): hard-block plan exit without review gate.
# Denies ExitPlanMode unless a session-scoped flag file exists (created after user approves via gate).
LOG="/tmp/plan-review-gate.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PermReq $*" >> "$LOG" 2>/dev/null; }

# Robust JSON field extraction: jq primary, grep/sed fallback.
extract_json_field() {
    local input="$1" field="$2" leaf
    leaf="${field##*.}"
    echo "$input" | jq -r ".${field} // \"\"" 2>/dev/null && return
    echo "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//' 2>/dev/null
}

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    log "session=unknown result=ERROR-empty-input-deny"
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}'
    exit 0
fi

SESSION_ID=$(extract_json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-${PPID:-default}}"
GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"

if [ -f "$GATE_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$GATE_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 300 ]; then
        rm -f "$GATE_FILE"
        log "session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=allow"
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        exit 0
    fi
    rm -f "$GATE_FILE"
    log "session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=deny-stale"
fi

# No flag or stale — deny with guidance message
DENY_MSG="BLOCKED: Plan Review Gate. Present AskUserQuestion with options: Submit (touch ${GATE_FILE} first) | Run /review-plan | Comments + /review-plan"
log "session=${SESSION_ID} gate=${GATE_FILE} result=deny"
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"${DENY_MSG}"}}}
EOF
echo "${DENY_MSG}" >&2
exit 0
