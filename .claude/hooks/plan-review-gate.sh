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
    log "session=${SESSION_ID} path=${FILE_PATH} result=fired"
    cat <<EOF
PLAN REVIEW GATE — present AskUserQuestion before ExitPlanMode.
Question: "How would you like to review this plan?"
Options:
1. Submit for approval — run: touch ${GATE_FILE} — then call ExitPlanMode
2. Run /review-plan — invoke review-plan skill on plan file, then re-present this gate
3. Comments + /review-plan — collect user comments, run review-plan with them, then re-present gate
EOF
    ;;
  *)
    log "session=${SESSION_ID} path=${FILE_PATH} result=skipped-not-plan"
    ;;
esac
