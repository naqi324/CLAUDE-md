#!/bin/sh
# PermissionRequest hook (matcher: ExitPlanMode): hard-block plan exit without review gate.
# Validates: (1) plan file breadcrumb exists, (2) plan has ## Innovation heading,
# (3) session-scoped flag file exists and is fresh. Denies with full gate spec on failure.
# Tracks denial count and escalates message on repeated attempts.
LOG="/tmp/plan-review-gate.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PermReq $*" >> "$LOG" 2>/dev/null; }

# Robust JSON field extraction: jq primary, grep/sed fallback.
extract_json_field() {
    local input="$1" field="$2" leaf
    leaf="${field##*.}"
    echo "$input" | jq -r ".${field} // \"\"" 2>/dev/null && return
    echo "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//' 2>/dev/null
}

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
        echo "CRITICAL: This is ExitPlanMode denial #${count}. STOP retrying ExitPlanMode. Your NEXT action MUST be AskUserQuestion with the gate options below."
    fi
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
DENY_COUNT_FILE="/tmp/claude-gate-deny-count-${SESSION_ID}"

# Gate text template — included in every deny message so the model can reconstruct the full gate.
# GATE_FILE_PLACEHOLDER is replaced with actual path before use.
GATE_TEXT='PLAN REVIEW GATE — you MUST present AskUserQuestion before ExitPlanMode.
Question: "How would you like to review this plan?"
Options (present ALL four):
1. Submit for approval — run: touch GATE_FILE_PLACEHOLDER — then call ExitPlanMode
2. Run /review-plan — invoke review-plan skill on plan file, then re-present this gate
3. Incorporate innovation — revise plan to integrate innovation idea, then re-present gate
4. Review + incorporate innovation — incorporate innovation AND run /review-plan, then re-present gate
After /review-plan REVISE: revise plan, re-present gate. After APPROVE: note result, re-present gate.'
GATE_TEXT=$(echo "$GATE_TEXT" | sed "s|GATE_FILE_PLACEHOLDER|${GATE_FILE}|g")

# --- Read plan path from breadcrumb ---
PLAN_PATH_FILE="/tmp/claude-plan-path-${SESSION_ID}"
PLAN_PATH=""
[ -f "$PLAN_PATH_FILE" ] && PLAN_PATH=$(cat "$PLAN_PATH_FILE" 2>/dev/null)

# --- Check 1: Breadcrumb must exist and point to a real file ---
if [ -z "$PLAN_PATH" ] || [ ! -f "$PLAN_PATH" ]; then
    ESCALATION=$(increment_deny_count)
    log "session=${SESSION_ID} plan=NONE result=deny-no-breadcrumb"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: No plan file found for this session. Write your plan to a .claude/plans/*.md file first, then re-present the gate.

${GATE_TEXT}"
    find /tmp -name 'claude-plan-path-*' -mmin +60 -delete 2>/dev/null
    exit 0
fi

# --- Check 2: Innovation heading must exist (does NOT consume flag) ---
if ! grep -qi '^##.*innovat' "$PLAN_PATH" 2>/dev/null; then
    ESCALATION=$(increment_deny_count)
    log "session=${SESSION_ID} plan=${PLAN_PATH} result=deny-no-innovation"
    output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: Plan file is missing a required '## Innovation' section. Add a heading like '## Innovation' to your plan with a concrete suggestion, then re-present the gate.

${GATE_TEXT}"
    find /tmp -name 'claude-plan-path-*' -mmin +60 -delete 2>/dev/null
    exit 0
fi
log "session=${SESSION_ID} plan=${PLAN_PATH} innovation=present"

# --- Check 3: Flag file must exist and be fresh ---
if [ -f "$GATE_FILE" ]; then
    AGE=$(( $(date +%s) - $(stat -f %m "$GATE_FILE" 2>/dev/null || echo 0) ))
    if [ "$AGE" -lt 600 ]; then
        rm -f "$GATE_FILE" "$PLAN_PATH_FILE" "$DENY_COUNT_FILE"
        log "session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=allow"
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        exit 0
    fi
    rm -f "$GATE_FILE"
    log "session=${SESSION_ID} gate=${GATE_FILE} age=${AGE}s result=deny-stale"
fi

# No flag or stale flag
ESCALATION=$(increment_deny_count)
log "session=${SESSION_ID} gate=${GATE_FILE} result=deny"
output_deny "${ESCALATION:+${ESCALATION}
}BLOCKED: ExitPlanMode requires the Plan Review Gate flag file.

${GATE_TEXT}"
find /tmp -name 'claude-plan-path-*' -mmin +60 -delete 2>/dev/null
exit 0
