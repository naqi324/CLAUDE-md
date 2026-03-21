#!/bin/sh
# Summarize plan review gate compliance from the hook log.

set -eu

LOG="${PLAN_GATE_LOG:-/tmp/plan-review-gate.log}"

if [ ! -f "$LOG" ]; then
    printf "No plan gate log found at %s\n" "$LOG"
    exit 0
fi

TMP_REPORT=$(mktemp)
trap 'rm -f "$TMP_REPORT"' EXIT

awk '
function remember(session) {
    if (!(session in seen)) {
        seen[session] = 1
        order[++count] = session
    }
}
function yesno(array, key) {
    return (key in array) ? "yes" : "no"
}
{
    session = ""
    current_path = ""
    for (i = 1; i <= NF; i++) {
        if ($i ~ /^session=/) {
            session = substr($i, 9)
        }
        if ($i ~ /^path=/) {
            current_path = substr($i, 6)
        }
    }
    if (session != "") {
        remember(session)
        if (current_path != "") {
            path[session] = current_path
        }
        if ($0 ~ /PostToolUse/ && $0 ~ /result=fired/) {
            wrote_plan[session] = 1
        }
        if ($0 ~ /AskUserQuestion/ && $0 ~ /result=fired/) {
            gate_shown[session] = 1
        }
        if ($0 ~ /innovation=present/) {
            innovation[session] = 1
        }
        if ($0 ~ /PermReq/ && $0 ~ /result=allow/) {
            allowed[session] = 1
        }
        if ($0 ~ /PermReq/ && $0 ~ /result=deny/) {
            retries[session] += 1
        }
    }
}
END {
    for (i = 1; i <= count; i++) {
        session = order[i]
        printf "%s|%s|%s|%s|%s|%s|%d\n", session, path[session], yesno(wrote_plan, session), yesno(innovation, session), yesno(gate_shown, session), yesno(allowed, session), retries[session] + 0
    }
}
' "$LOG" > "$TMP_REPORT"

printf "%-16s %-5s %-10s %-5s %-5s %-7s %s\n" "Session" "Plan" "Innovation" "Gate" "Allow" "Retries" "Plan Path"

while IFS='|' read -r session path wrote_plan innovation gate_shown allowed retries; do
    [ -n "$session" ] || continue
    if [ "$innovation" != "yes" ] && [ -n "$path" ] && [ -f "$path" ] && grep -qi '^##.*innovat' "$path" 2>/dev/null; then
        innovation="yes"
    fi
    printf "%-16s %-5s %-10s %-5s %-5s %-7s %s\n" "$session" "$wrote_plan" "$innovation" "$gate_shown" "$allowed" "$retries" "${path:--}"
done < "$TMP_REPORT"
