#!/bin/sh
# PostToolUse hook (matcher: Edit|Write): reinforce plan review gate.
# Fires after Write/Edit completes. If the file is a plan file, injects
# a reminder with the session-scoped gate unlock command.
LOG="/tmp/plan-review-gate.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] PostToolUse $*" >> "$LOG" 2>/dev/null; }

# Robust JSON field extraction: jq primary, grep/sed fallback.
# Fallback uses leaf key name — works for unique-leaf-key fields in Claude Code JSON.
extract_json_field() {
    local input="$1" field="$2" leaf
    leaf="${field##*.}"
    echo "$input" | jq -r ".${field} // \"\"" 2>/dev/null && return
    echo "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//' 2>/dev/null
}

INPUT=$(cat)
if [ -z "$INPUT" ]; then
    log "session=unknown path=unknown result=ERROR-empty-input"
    exit 0
fi

FILE_PATH=$(extract_json_field "$INPUT" "tool_input.file_path")
SESSION_ID=$(extract_json_field "$INPUT" "session_id")
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
    log "session=${SESSION_ID} path=${FILE_PATH} breadcrumb=${PLAN_PATH_FILE} result=fired"
    cat <<EOF
${INNOVATION_MISSING:+${INNOVATION_MISSING}
}PLAN REVIEW GATE — present AskUserQuestion before ExitPlanMode.
Question: "How would you like to review this plan?"
Options:
1. Submit for approval — run: touch ${GATE_FILE} — then call ExitPlanMode
2. Run /review-plan — invoke review-plan skill on plan file, then re-present this gate
3. Comments + /review-plan — collect user comments, run review-plan with them, then re-present gate
NOTE: ExitPlanMode validates that the plan contains a '## Innovation' heading. It will be BLOCKED if missing.
EOF
    ;;
  *)
    log "session=${SESSION_ID} path=${FILE_PATH} result=skipped-not-plan"
    ;;
esac
