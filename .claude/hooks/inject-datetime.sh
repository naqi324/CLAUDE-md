#!/bin/sh
# UserPromptSubmit hook: inject datetime + plan-mode gate reminder
cat > /dev/null
echo "Current datetime: $(date '+%A, %Y-%m-%d %H:%M %Z')"

# If any plan breadcrumb exists recently, inject gate reminder
if find /tmp -name 'claude-plan-path-*' -mmin -30 2>/dev/null | grep -q .; then
    echo "<user-prompt-submit-hook>PLAN REVIEW GATE ACTIVE: If in plan mode, present AskUserQuestion with all 4 options (Submit | /review-plan | Incorporate innovation | Review+innovation) before calling ExitPlanMode.</user-prompt-submit-hook>"
fi
