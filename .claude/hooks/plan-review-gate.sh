#!/bin/sh
# PostToolUse hook (matcher: Edit|Write): reinforce plan review gate after plan writes.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "${SCRIPT_DIR}/plan-gate-shared.sh"

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    plan_gate_log "PostToolUse session=unknown path=unknown result=ERROR-empty-input"
    exit 0
fi

FILE_PATH=$(plan_gate_extract_json_field "$INPUT" "tool_input.file_path")
SESSION_ID=$(plan_gate_extract_json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-${PPID:-default}}"

case "$FILE_PATH" in
  */.claude/plans/*.md)
    GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"
    PLAN_PATH_FILE="/tmp/claude-plan-path-${SESSION_ID}"
    echo "$FILE_PATH" > "$PLAN_PATH_FILE"
    INNOVATION_MISSING=""
    if [ -f "$FILE_PATH" ] && ! grep -qi '^##.*innovat' "$FILE_PATH" 2>/dev/null; then
        INNOVATION_MISSING="WARNING: Plan file is MISSING a '## Innovation' section. The exit gate will BLOCK ExitPlanMode until this section exists. Add it before submitting."
    fi
    plan_gate_log "PostToolUse session=${SESSION_ID} path=${FILE_PATH} breadcrumb=${PLAN_PATH_FILE} result=fired"
    cat <<EOF
${INNOVATION_MISSING:+${INNOVATION_MISSING}
}$(plan_gate_render_soft_reminder "${GATE_FILE}")
NOTE: ExitPlanMode validates that the plan contains a '## Innovation' heading. It will be BLOCKED if missing.
EOF
    ;;
  *)
    plan_gate_log "PostToolUse session=${SESSION_ID} path=${FILE_PATH} result=skipped-not-plan"
    ;;
esac
