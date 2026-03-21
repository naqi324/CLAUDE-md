#!/bin/sh
# UserPromptSubmit hook: inject datetime + plan-mode gate reminder.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
. "${SCRIPT_DIR}/plan-gate-shared.sh"

INPUT=$(cat)
SESSION_ID=$(plan_gate_extract_json_field "$INPUT" "session_id")
SESSION_ID="${SESSION_ID:-${PPID:-default}}"
GATE_FILE="/tmp/claude-plan-gate-${SESSION_ID}"

echo "Current datetime: $(date '+%A, %Y-%m-%d %H:%M %Z')"

# If any plan breadcrumb exists recently, inject gate reminder.
if find /tmp -name 'claude-plan-path-*' -mmin -30 2>/dev/null | grep -q .; then
    cat <<EOF
<user-prompt-submit-hook>$(plan_gate_render_soft_reminder "${GATE_FILE}")
NOTE: ExitPlanMode requires the session-scoped submit flag file created by option 1.</user-prompt-submit-hook>
EOF
fi
