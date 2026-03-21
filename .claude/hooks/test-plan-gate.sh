#!/bin/sh
# Smoke test for plan review gate hooks.
# Tests both hooks with various inputs, including jq-less fallback mode.
set -e

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
POST_HOOK="${HOOKS_DIR}/plan-review-gate.sh"
PERM_HOOK="${HOOKS_DIR}/plan-exit-gate.sh"
ASK_HOOK="${HOOKS_DIR}/plan-gate-asked.sh"
LOG="/tmp/plan-review-gate.log"
PASS=0; FAIL=0; TOTAL=0

# Create a fake jq that always fails (shadows real jq without removing /usr/bin from PATH)
FAKE_JQ_DIR=$(mktemp -d)
printf '#!/bin/sh\nexit 127\n' > "${FAKE_JQ_DIR}/jq"
chmod +x "${FAKE_JQ_DIR}/jq"
NO_JQ_PATH="${FAKE_JQ_DIR}:${PATH}"

# Clean log before tests
: > "$LOG"

test_contains() {
    local desc="$1" result="$2" expect="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$result" | grep -q "$expect"; then
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    else
        printf "  FAIL: %s\n    expected: %s\n    got: %s\n" "$desc" "$expect" "$result"; FAIL=$((FAIL + 1))
    fi
}

test_empty() {
    local desc="$1" result="$2"
    TOTAL=$((TOTAL + 1))
    if [ -z "$result" ]; then
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    else
        printf "  FAIL: %s\n    expected empty, got: %s\n" "$desc" "$result"; FAIL=$((FAIL + 1))
    fi
}

test_not_contains() {
    local desc="$1" result="$2" unexpected="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$result" | grep -F -q "$unexpected"; then
        printf "  FAIL: %s\n    unexpected: %s\n    got: %s\n" "$desc" "$unexpected" "$result"; FAIL=$((FAIL + 1))
    else
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    fi
}

test_file_absent() {
    local desc="$1" path="$2"
    TOTAL=$((TOTAL + 1))
    if [ ! -f "$path" ]; then
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (file still exists: %s)\n" "$desc" "$path"; FAIL=$((FAIL + 1))
    fi
}

test_file_present() {
    local desc="$1" path="$2"
    TOTAL=$((TOTAL + 1))
    if [ -f "$path" ]; then
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (missing file: %s)\n" "$desc" "$path"; FAIL=$((FAIL + 1))
    fi
}

test_ordered_tokens() {
    local desc="$1" result="$2"
    shift 2
    local prev=-1 token pos
    TOTAL=$((TOTAL + 1))
    for token in "$@"; do
        pos=$(printf '%s' "$result" | grep -F -b -o "$token" | head -1 | cut -d: -f1)
        if [ -z "$pos" ] || [ "$pos" -le "$prev" ]; then
            printf "  FAIL: %s\n    token order broke at: %s\n    got: %s\n" "$desc" "$token" "$result"; FAIL=$((FAIL + 1))
            return
        fi
        prev="$pos"
    done
    printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
}

echo "=== Plan Review Gate Smoke Tests ==="
echo

# --- PostToolUse tests ---
echo "PostToolUse (plan-review-gate.sh):"

# Test 1: Plan file path → should output gate reminder
result=$(echo '{"tool_input":{"file_path":"/x/.claude/plans/test.md"},"session_id":"test-s1"}' | "$POST_HOOK" 2>/dev/null)
test_contains "plan file triggers gate reminder" "$result" "PLAN REVIEW GATE"

# Test 2: Non-plan file → should be silent
result=$(echo '{"tool_input":{"file_path":"/x/src/foo.ts"},"session_id":"test-s1"}' | "$POST_HOOK" 2>/dev/null)
test_empty "non-plan file is silent" "$result"

# Test 3: Empty input → silent, log shows error
result=$(echo "" | "$POST_HOOK" 2>/dev/null)
test_empty "empty input is silent" "$result"
TOTAL=$((TOTAL + 1))
if grep -q "ERROR-empty-input" "$LOG"; then
    printf "  PASS: empty input logs error\n"; PASS=$((PASS + 1))
else
    printf "  FAIL: empty input should log error\n"; FAIL=$((FAIL + 1))
fi

echo
echo "AskUserQuestion marker hook (plan-gate-asked.sh):"

# Test 4: Matching gate question creates marker when plan breadcrumb exists
echo "/tmp/fake-plan-test-s4a.md" > /tmp/claude-plan-path-test-s4a
result=$(echo '{"tool_input":{"questions":[{"question":"How would you like to review this plan?"}]},"session_id":"test-s4a"}' | "$ASK_HOOK" 2>/dev/null)
test_empty "matching AskUserQuestion remains silent" "$result"
test_file_present "matching AskUserQuestion creates marker" "/tmp/claude-gate-asked-test-s4a"

# Test 5: Non-gate AskUserQuestion does not create marker
echo "/tmp/fake-plan-test-s5a.md" > /tmp/claude-plan-path-test-s5a
result=$(echo '{"tool_input":{"questions":[{"question":"Do you want to continue?"}]},"session_id":"test-s5a"}' | "$ASK_HOOK" 2>/dev/null)
test_empty "non-gate AskUserQuestion remains silent" "$result"
test_file_absent "non-gate AskUserQuestion does not create marker" "/tmp/claude-gate-asked-test-s5a"

# Test 6: Matching AskUserQuestion without breadcrumb does not create marker
rm -f /tmp/claude-plan-path-test-s6a /tmp/claude-gate-asked-test-s6a
result=$(echo '{"tool_input":{"questions":[{"question":"How would you like to review this plan?"}]},"session_id":"test-s6a"}' | "$ASK_HOOK" 2>/dev/null)
test_empty "matching AskUserQuestion without breadcrumb remains silent" "$result"
test_file_absent "matching AskUserQuestion without breadcrumb does not create marker" "/tmp/claude-gate-asked-test-s6a"

echo
echo "PermissionRequest (plan-exit-gate.sh):"

# Helper: create temp plan files in a .claude/plans/ structure so they match the case pattern.
TEST_DIR=$(mktemp -d)
mkdir -p "${TEST_DIR}/.claude/plans"
PLAN_WITH_INNOV="${TEST_DIR}/.claude/plans/test-with-innov.md"
printf "# Plan\n\n## Steps\n\n1. Do thing\n\n## Innovation\n\nSmart idea here.\n" > "$PLAN_WITH_INNOV"
PLAN_NO_INNOV="${TEST_DIR}/.claude/plans/test-no-innov.md"
printf "# Plan\n\n## Steps\n\n1. Do thing\n" > "$PLAN_NO_INNOV"

# Test 7: No flag file, no breadcrumb → deny with "No plan file"
rm -f /tmp/claude-plan-gate-test-s2 /tmp/claude-plan-path-test-s2 /tmp/claude-gate-asked-test-s2
result=$(echo '{"session_id":"test-s2"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no flag, no breadcrumb → deny" "$result" '"deny"'
test_contains "deny mentions no plan file" "$result" "No plan file"

# Test 8: Fresh flag + breadcrumb with innovation → allow + files cleaned
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s3
touch /tmp/claude-plan-gate-test-s3
result=$(echo '{"session_id":"test-s3"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "fresh flag + innovation → allow" "$result" '"allow"'
test_file_absent "flag file deleted after allow" "/tmp/claude-plan-gate-test-s3"
test_file_absent "breadcrumb deleted after allow" "/tmp/claude-plan-path-test-s3"

# Test 9: Stale flag + breadcrumb with innovation → deny + flag deleted
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s4
touch -t 202501010000 /tmp/claude-plan-gate-test-s4
result=$(echo '{"session_id":"test-s4"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "stale flag → deny" "$result" '"deny"'
test_file_absent "stale flag cleaned up" "/tmp/claude-plan-gate-test-s4"

echo
echo "jq-less fallback mode:"

# Test 10: PostToolUse without jq → should still work
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s5\"}" | PATH="$NO_JQ_PATH" "$POST_HOOK" 2>/dev/null)
test_contains "PostToolUse works without jq" "$result" "PLAN REVIEW GATE ACTIVE"

# Test 11: PermissionRequest without jq → should deny (no breadcrumb)
rm -f /tmp/claude-plan-gate-test-s6 /tmp/claude-plan-path-test-s6
result=$(echo '{"session_id":"test-s6"}' | PATH="$NO_JQ_PATH" "$PERM_HOOK" 2>/dev/null)
test_contains "PermissionRequest denies without jq" "$result" '"deny"'

# Test 12: AskUserQuestion marker works without jq
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s7
result=$(echo '{"tool_input":{"questions":[{"question":"How would you like to review this plan?"}]},"session_id":"test-s7"}' | PATH="$NO_JQ_PATH" "$ASK_HOOK" 2>/dev/null)
test_empty "AskUserQuestion marker is silent without jq" "$result"
test_file_present "AskUserQuestion marker works without jq" "/tmp/claude-gate-asked-test-s7"

echo
echo "Innovation content validation:"

# Test 13: PostToolUse — plan WITH innovation → gate reminder, NO warning
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s9\"}" | "$POST_HOOK" 2>/dev/null)
test_contains "plan with innovation → gate reminder" "$result" "PLAN REVIEW GATE ACTIVE"
TOTAL=$((TOTAL + 1))
if echo "$result" | grep -q "WARNING"; then
    printf "  FAIL: plan with innovation should NOT warn\n"; FAIL=$((FAIL + 1))
else
    printf "  PASS: plan with innovation has no warning\n"; PASS=$((PASS + 1))
fi

# Test 14: PostToolUse — plan WITHOUT innovation → WARNING + gate reminder
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_NO_INNOV}\"},\"session_id\":\"test-s10\"}" | "$POST_HOOK" 2>/dev/null)
test_contains "plan without innovation → warns" "$result" "WARNING"
test_contains "plan without innovation → still shows gate" "$result" "PLAN REVIEW GATE ACTIVE"

# Test 15: PostToolUse — breadcrumb file created with correct path
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s11\"}" | "$POST_HOOK" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ -f /tmp/claude-plan-path-test-s11 ] && [ "$(cat /tmp/claude-plan-path-test-s11)" = "$PLAN_WITH_INNOV" ]; then
    printf "  PASS: breadcrumb created with correct path\n"; PASS=$((PASS + 1))
else
    printf "  FAIL: breadcrumb missing or wrong content\n"; FAIL=$((FAIL + 1))
fi

# Test 16: PermReq — fresh flag + breadcrumb + innovation → allow
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s12
touch /tmp/claude-plan-gate-test-s12
result=$(echo '{"session_id":"test-s12"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "flag + breadcrumb + innovation → allow" "$result" '"allow"'

# Test 17: PermReq — fresh flag + breadcrumb + NO innovation → deny, flag NOT consumed
echo "$PLAN_NO_INNOV" > /tmp/claude-plan-path-test-s13
touch /tmp/claude-plan-gate-test-s13
result=$(echo '{"session_id":"test-s13"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "flag + no innovation → deny" "$result" '"deny"'
test_contains "deny mentions Innovation" "$result" "Innovation"
TOTAL=$((TOTAL + 1))
if [ -f /tmp/claude-plan-gate-test-s13 ]; then
    printf "  PASS: flag NOT consumed when innovation missing\n"; PASS=$((PASS + 1))
else
    printf "  FAIL: flag consumed despite missing innovation\n"; FAIL=$((FAIL + 1))
fi

# Test 18: PermReq — no flag + no breadcrumb → deny with "No plan file found"
rm -f /tmp/claude-plan-gate-test-s14 /tmp/claude-plan-path-test-s14
result=$(echo '{"session_id":"test-s14"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no breadcrumb → deny" "$result" '"deny"'
test_contains "deny mentions no plan file" "$result" "No plan file"

# Test 19: PermReq — breadcrumb + innovation + no gate asked → directive recovery message
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s19a
rm -f /tmp/claude-gate-asked-test-s19a /tmp/claude-plan-gate-test-s19a
result=$(echo '{"session_id":"test-s19a"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no gate asked → directive recovery" "$result" "Your next tool call MUST be AskUserQuestion with these EXACT parameters"
test_ordered_tokens "directive recovery preserves option order" "$result" "Submit for approval" "Run /review-plan" "Incorporate innovation" "Review + incorporate innovation"

# Test 20: PermReq — gate asked + no flag → shorter submit instruction
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s20a
touch /tmp/claude-gate-asked-test-s20a
result=$(echo '{"session_id":"test-s20a"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "gate asked + no flag → shorter submit instruction" "$result" "Gate was already presented. To submit for approval"
test_not_contains "shorter submit instruction omits directive recovery block" "$result" "Your next tool call MUST be AskUserQuestion with these EXACT parameters"

echo
echo "Agent nudge hook (plan-mode-agent-nudge.sh):"

NUDGE_HOOK="${HOOKS_DIR}/plan-mode-agent-nudge.sh"

# Test 21: Explore agent → nudge fires
result=$(echo '{"tool_input":{"subagent_type":"Explore"},"session_id":"test-s15"}' | "$NUDGE_HOOK" 2>/dev/null)
test_contains "Explore agent → nudge fires" "$result" "PLAN MODE"

# Test 22: Plan agent → nudge fires
result=$(echo '{"tool_input":{"subagent_type":"Plan"},"session_id":"test-s16"}' | "$NUDGE_HOOK" 2>/dev/null)
test_contains "Plan agent → nudge fires" "$result" "PLAN MODE"

# Test 23: general-purpose agent → silent
result=$(echo '{"tool_input":{"subagent_type":"general-purpose"},"session_id":"test-s17"}' | "$NUDGE_HOOK" 2>/dev/null)
test_empty "general-purpose agent → silent" "$result"

echo
echo "TTL and denial escalation:"

# Test 24: Flag at 500s → allow (within 600s TTL)
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s18
touch -t "$(date -v-500S '+%Y%m%d%H%M.%S' 2>/dev/null || date -d '500 seconds ago' '+%Y%m%d%H%M.%S' 2>/dev/null)" /tmp/claude-plan-gate-test-s18 2>/dev/null
# Fallback: just use perl to set mtime 500s ago
if [ ! -f /tmp/claude-plan-gate-test-s18 ]; then
    touch /tmp/claude-plan-gate-test-s18
    perl -e 'utime(time-500, time-500, "/tmp/claude-plan-gate-test-s18")' 2>/dev/null
fi
result=$(echo '{"session_id":"test-s18"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "flag at 500s → allow (within 600s TTL)" "$result" '"allow"'

# Test 25: Flag at 700s → deny-stale (beyond 600s TTL)
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s19
touch /tmp/claude-plan-gate-test-s19
perl -e 'utime(time-700, time-700, "/tmp/claude-plan-gate-test-s19")' 2>/dev/null
result=$(echo '{"session_id":"test-s19"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "flag at 700s → deny-stale" "$result" '"deny"'

# Test 26: Denial count escalation — 2nd denial shows CRITICAL
rm -f /tmp/claude-gate-deny-count-test-s20 /tmp/claude-plan-gate-test-s20
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s20
# First denial
echo '{"session_id":"test-s20"}' | "$PERM_HOOK" > /dev/null 2>&1
# Second denial — should escalate
result=$(echo '{"session_id":"test-s20"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "2nd denial → CRITICAL escalation" "$result" "CRITICAL"

# Test 27: Allow path cleans up deny count file and gate marker
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s21
echo "3" > /tmp/claude-gate-deny-count-test-s21
touch /tmp/claude-gate-asked-test-s21
touch /tmp/claude-plan-gate-test-s21
result=$(echo '{"session_id":"test-s21"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "allow after denials" "$result" '"allow"'
test_file_absent "deny count cleaned on allow" "/tmp/claude-gate-deny-count-test-s21"
test_file_absent "gate marker cleaned on allow" "/tmp/claude-gate-asked-test-s21"

# Cleanup
rm -f /tmp/claude-plan-gate-test-s* /tmp/claude-plan-path-test-s* /tmp/claude-gate-deny-count-test-s* /tmp/claude-gate-asked-test-s*
rm -rf "$TEST_DIR" "$FAKE_JQ_DIR"

echo
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo "Log entries: $(wc -l < "$LOG" | tr -d ' ')"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
