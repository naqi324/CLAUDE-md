#!/bin/sh
# PostToolUse hook (matcher: AskUserQuestion): record that the plan review gate
# was actually presented for the current session.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "${SCRIPT_DIR}/plan-gate-shared.sh"

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    plan_gate_log "AskUserQuestion session=unknown result=ERROR-empty-input"
    exit 0
fi

SESSION_ID=$(plan_gate_extract_json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-${PPID:-default}}"
PLAN_PATH_FILE="/tmp/claude-plan-path-${SESSION_ID}"
GATE_ASKED_FILE="/tmp/claude-gate-asked-${SESSION_ID}"
QUESTION=$(plan_gate_extract_first_question "$INPUT")

if [ ! -f "$PLAN_PATH_FILE" ]; then
    plan_gate_log "AskUserQuestion session=${SESSION_ID} result=skipped-no-plan"
    exit 0
fi

if echo "$QUESTION" | grep -iq 'review this plan'; then
    touch "$GATE_ASKED_FILE"
    plan_gate_log "AskUserQuestion session=${SESSION_ID} marker=${GATE_ASKED_FILE} result=fired"
else
    plan_gate_log "AskUserQuestion session=${SESSION_ID} result=skipped-non-gate"
fi
