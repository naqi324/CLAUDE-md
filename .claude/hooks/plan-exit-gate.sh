#!/bin/sh
# PermissionRequest hook (matcher: ExitPlanMode): hard-block plan exit without review gate.
# Validates: (1) plan file breadcrumb exists, (2) plan has ## Innovation heading,
# (3) the gate was presented or the submit flag exists, and (4) the flag is fresh.
# Tracks denial count and escalates repeated retries.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "${SCRIPT_DIR}/plan-gate-shared.sh"

# Produce valid deny JSON. jq primary; no-jq fallback flattens to single line.
output_deny() {
    local msg="$1" result
    result=$(jq -n --arg msg "$msg" \
      '{hookSpecificOutput:{hookEventName:"PermissionRequest",decision:{behavior:"deny",message:$msg}}}' 2>/dev/null) && [ -n "$result" ] && {
        echo "$result"
        echo "$msg" >&2
        return
    }
    # No-jq fallback: flatten to single line to avoid broken JSON
    local flat
    flat=$(printf '%s' "$msg" | tr '\n' ' ' | sed 's/"/\\"/g')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"deny\",\"message\":\"${flat}\"}}}"
    echo "$msg" >&2
}

# Increment denial count and return escalation prefix if >= 2
increment_deny_count() {
    local count=0
    [ -f "$DENY_COUNT_FILE" ] && count=$(cat "$DENY_COUNT_FILE" 2>/dev/null)
    count=$((count + 1))
    echo "$count" > "$DENY_COUNT_FILE"
    if [ "$count" -ge 2 ]; then
        echo "CRITICAL: This is ExitPlanMode denial #${count}. STOP retrying ExitPlanMode. Follow the instruction below instead."
    fi
}

cleanup_stale_markers() {
    find /tmp -name 'claude-plan-path-*' -mmin +60 -delete 2>/dev/null
    find /tmp -name 'claude-gate-asked-*' -mmin +60 -delete 2>/dev/null
}

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    plan_gate_log "PermReq session=unknown result=ERROR-empty-input-deny"
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny"}}}'
    exit 0
fi

SESSION_ID=$(plan_gate_extract_json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-${PPID:-default}}"
GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"
GATE_ASKED_FILE="/tmp/claude-gate-asked-${SESSION_ID}"
DENY_COUNT_FILE="/tmp/claude-gate-deny-count-${SESSION_ID}"

# --- Read plan path from breadcrumb ---
PLAN_PATH_FILE="/tmp/claude-plan-path-${SESSION_ID}"
PLAN_PATH=""
[ -f "$PLAN_PATH_FILE" ] && PLAN_PATH=$(cat "$PLAN_PATH_FILE" 2>/dev/null)

# --- Check 1: Breadcrumb must exist and point to a real file ---
if [ -z "$PLAN_PATH" ] || [ ! -f "$PLAN_PATH" ]; then
    ESCALATION=$(increment_deny_count)
    plan_gate_log "PermReq session=${SESSION_ID} plan=NONE result=deny-no-breadcrumb"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: No plan file found for this session. Write your plan to a .claude/plans/*.md file first, then re-present the gate.

$(plan_gate_render_recovery_message "${GATE_FILE}")"
    cleanup_stale_markers
    exit 0
fi

# --- Check 2: Innovation heading must exist (does NOT consume flag) ---
if ! grep -qi '^##.*innovat' "$PLAN_PATH" 2>/dev/null; then
    ESCALATION=$(increment_deny_count)
    plan_gate_log "PermReq session=${SESSION_ID} plan=${PLAN_PATH} result=deny-no-innovation"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: Plan file is missing a required '## Innovation' section. Add a heading like '## Innovation' to your plan with a concrete suggestion, then re-present the gate.

$(plan_gate_render_recovery_message "${GATE_FILE}")"
    cleanup_stale_markers
    exit 0
fi
plan_gate_log "PermReq session=${SESSION_ID} plan=${PLAN_PATH} innovation=present"

# --- Check 3: Flag file must exist and be fresh ---
if [ -f "$GATE_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$GATE_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 600 ]; then
        rm -f "$GATE_FILE" "$PLAN_PATH_FILE" "$GATE_ASKED_FILE" "$DENY_COUNT_FILE"
        plan_gate_log "PermReq session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=allow"
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        exit 0
    fi
    rm -f "$GATE_FILE"
    plan_gate_log "PermReq session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=deny-stale"
fi

# No flag or stale flag
ESCALATION=$(increment_deny_count)
if [ -f "$GATE_ASKED_FILE" ]; then
    plan_gate_log "PermReq session=${SESSION_ID} gate=${GATE_FILE} gate_asked=${GATE_ASKED_FILE} result=deny-submit"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: ExitPlanMode requires the session-scoped submit flag file.

$(plan_gate_render_submit_instruction "${GATE_FILE}")"
else
    plan_gate_log "PermReq session=${SESSION_ID} gate=${GATE_FILE} result=deny-no-gate-asked"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: ExitPlanMode requires the Plan Review Gate AskUserQuestion.

$(plan_gate_render_recovery_message "${GATE_FILE}")"
fi
cleanup_stale_markers
exit 0
