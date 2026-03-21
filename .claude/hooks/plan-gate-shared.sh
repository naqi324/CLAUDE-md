#!/bin/sh
# Shared helpers and single-sourced gate wording for plan review hooks.

PLAN_GATE_LOG="${PLAN_GATE_LOG:-/tmp/plan-review-gate.log}"
PLAN_GATE_QUESTION='How would you like to review this plan?'

plan_gate_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$PLAN_GATE_LOG" 2>/dev/null
}

# Robust JSON field extraction: jq primary, grep/sed fallback.
plan_gate_extract_json_field() {
    local input="$1" field="$2" leaf
    leaf="${field##*.}"
    echo "$input" | jq -r ".${field} // \"\"" 2>/dev/null && return
    echo "$input" | grep -o "\"${leaf}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//' 2>/dev/null
}

plan_gate_extract_first_question() {
    local input="$1"
    echo "$input" | jq -r '.tool_input.questions[0].question // ""' 2>/dev/null && return
    echo "$input" | grep -o '"question"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*":[[:space:]]*"//;s/"$//' 2>/dev/null
}

plan_gate_render_exact_parameters() {
    local gate_file="$1"
    cat <<EOF
question: "${PLAN_GATE_QUESTION}"
option 1 - label: "Submit for approval", description: "Run: touch ${gate_file} then call ExitPlanMode"
option 2 - label: "Run /review-plan", description: "Fresh-context 6-dimension plan review, then re-present this gate"
option 3 - label: "Incorporate innovation", description: "Integrate innovation idea into plan steps, then re-present gate"
option 4 - label: "Review + incorporate innovation", description: "Incorporate innovation then run /review-plan, then re-present gate"
EOF
}

plan_gate_render_recovery_message() {
    local gate_file="$1"
    cat <<EOF
STOP. Do NOT call ExitPlanMode again. Your next tool call MUST be AskUserQuestion with these EXACT parameters:
$(plan_gate_render_exact_parameters "$gate_file")
EOF
}

plan_gate_render_soft_reminder() {
    local gate_file="$1"
    cat <<EOF
PLAN REVIEW GATE ACTIVE. Present AskUserQuestion with these EXACT parameters before ExitPlanMode:
$(plan_gate_render_exact_parameters "$gate_file")
EOF
}

plan_gate_render_submit_instruction() {
    local gate_file="$1"
    cat <<EOF
Gate was already presented. To submit for approval, run: touch ${gate_file}
Then call ExitPlanMode.
EOF
}
