#!/bin/sh
# Smoke test for plan review gate hooks.
# Tests both hooks with various inputs, including jq-less fallback mode.
set -e

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
POST_HOOK="${HOOKS_DIR}/plan-review-gate.sh"
PERM_HOOK="${HOOKS_DIR}/plan-exit-gate.sh"
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

test_file_absent() {
    local desc="$1" path="$2"
    TOTAL=$((TOTAL + 1))
    if [ ! -f "$path" ]; then
        printf "  PASS: %s\n" "$desc"; PASS=$((PASS + 1))
    else
        printf "  FAIL: %s (file still exists: %s)\n" "$desc" "$path"; FAIL=$((FAIL + 1))
    fi
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
echo "PermissionRequest (plan-exit-gate.sh):"

# Helper: create temp plan files in a .claude/plans/ structure so they match the case pattern.
TEST_DIR=$(mktemp -d)
mkdir -p "${TEST_DIR}/.claude/plans"
PLAN_WITH_INNOV="${TEST_DIR}/.claude/plans/test-with-innov.md"
printf "# Plan\n\n## Steps\n\n1. Do thing\n\n## Innovation\n\nSmart idea here.\n" > "$PLAN_WITH_INNOV"
PLAN_NO_INNOV="${TEST_DIR}/.claude/plans/test-no-innov.md"
printf "# Plan\n\n## Steps\n\n1. Do thing\n" > "$PLAN_NO_INNOV"

# Test 4: No flag file, no breadcrumb → deny with "No plan file"
rm -f /tmp/claude-plan-gate-test-s2 /tmp/claude-plan-path-test-s2
result=$(echo '{"session_id":"test-s2"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no flag, no breadcrumb → deny" "$result" '"deny"'
test_contains "deny mentions no plan file" "$result" "No plan file"

# Test 5: Fresh flag + breadcrumb with innovation → allow + files cleaned
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s3
touch /tmp/claude-plan-gate-test-s3
result=$(echo '{"session_id":"test-s3"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "fresh flag + innovation → allow" "$result" '"allow"'
test_file_absent "flag file deleted after allow" "/tmp/claude-plan-gate-test-s3"
test_file_absent "breadcrumb deleted after allow" "/tmp/claude-plan-path-test-s3"

# Test 6: Stale flag + breadcrumb with innovation → deny + flag deleted
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s4
touch -t 202501010000 /tmp/claude-plan-gate-test-s4
result=$(echo '{"session_id":"test-s4"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "stale flag → deny" "$result" '"deny"'
test_file_absent "stale flag cleaned up" "/tmp/claude-plan-gate-test-s4"

echo
echo "jq-less fallback mode:"

# Test 7: PostToolUse without jq → should still work
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s5\"}" | PATH="$NO_JQ_PATH" "$POST_HOOK" 2>/dev/null)
test_contains "PostToolUse works without jq" "$result" "PLAN REVIEW GATE"

# Test 8: PermissionRequest without jq → should deny (no breadcrumb)
rm -f /tmp/claude-plan-gate-test-s6 /tmp/claude-plan-path-test-s6
result=$(echo '{"session_id":"test-s6"}' | PATH="$NO_JQ_PATH" "$PERM_HOOK" 2>/dev/null)
test_contains "PermissionRequest denies without jq" "$result" '"deny"'

echo
echo "Innovation content validation:"

# Test 9: PostToolUse — plan WITH innovation → gate reminder, NO warning
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s9\"}" | "$POST_HOOK" 2>/dev/null)
test_contains "plan with innovation → gate reminder" "$result" "PLAN REVIEW GATE"
TOTAL=$((TOTAL + 1))
if echo "$result" | grep -q "WARNING"; then
    printf "  FAIL: plan with innovation should NOT warn\n"; FAIL=$((FAIL + 1))
else
    printf "  PASS: plan with innovation has no warning\n"; PASS=$((PASS + 1))
fi

# Test 10: PostToolUse — plan WITHOUT innovation → WARNING + gate reminder
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_NO_INNOV}\"},\"session_id\":\"test-s10\"}" | "$POST_HOOK" 2>/dev/null)
test_contains "plan without innovation → warns" "$result" "WARNING"
test_contains "plan without innovation → still shows gate" "$result" "PLAN REVIEW GATE"

# Test 11: PostToolUse — breadcrumb file created with correct path
result=$(echo "{\"tool_input\":{\"file_path\":\"${PLAN_WITH_INNOV}\"},\"session_id\":\"test-s11\"}" | "$POST_HOOK" 2>/dev/null)
TOTAL=$((TOTAL + 1))
if [ -f /tmp/claude-plan-path-test-s11 ] && [ "$(cat /tmp/claude-plan-path-test-s11)" = "$PLAN_WITH_INNOV" ]; then
    printf "  PASS: breadcrumb created with correct path\n"; PASS=$((PASS + 1))
else
    printf "  FAIL: breadcrumb missing or wrong content\n"; FAIL=$((FAIL + 1))
fi

# Test 12: PermReq — fresh flag + breadcrumb + innovation → allow
echo "$PLAN_WITH_INNOV" > /tmp/claude-plan-path-test-s12
touch /tmp/claude-plan-gate-test-s12
result=$(echo '{"session_id":"test-s12"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "flag + breadcrumb + innovation → allow" "$result" '"allow"'

# Test 13: PermReq — fresh flag + breadcrumb + NO innovation → deny, flag NOT consumed
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

# Test 14: PermReq — no flag + no breadcrumb → deny with "No plan file found"
rm -f /tmp/claude-plan-gate-test-s14 /tmp/claude-plan-path-test-s14
result=$(echo '{"session_id":"test-s14"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no breadcrumb → deny" "$result" '"deny"'
test_contains "deny mentions no plan file" "$result" "No plan file"

echo
echo "Agent nudge hook (plan-mode-agent-nudge.sh):"

NUDGE_HOOK="${HOOKS_DIR}/plan-mode-agent-nudge.sh"

# Test 15: Explore agent → nudge fires
result=$(echo '{"tool_input":{"subagent_type":"Explore"},"session_id":"test-s15"}' | "$NUDGE_HOOK" 2>/dev/null)
test_contains "Explore agent → nudge fires" "$result" "PLAN MODE"

# Test 16: Plan agent → nudge fires
result=$(echo '{"tool_input":{"subagent_type":"Plan"},"session_id":"test-s16"}' | "$NUDGE_HOOK" 2>/dev/null)
test_contains "Plan agent → nudge fires" "$result" "PLAN MODE"

# Test 17: general-purpose agent → silent
result=$(echo '{"tool_input":{"subagent_type":"general-purpose"},"session_id":"test-s17"}' | "$NUDGE_HOOK" 2>/dev/null)
test_empty "general-purpose agent → silent" "$result"

# Cleanup
rm -f /tmp/claude-plan-gate-test-s* /tmp/claude-plan-path-test-s*
rm -rf "$TEST_DIR" "$FAKE_JQ_DIR"

echo
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo "Log entries: $(wc -l < "$LOG" | tr -d ' ')"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
