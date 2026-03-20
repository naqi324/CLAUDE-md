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

# Test 4: No flag file → deny
rm -f /tmp/claude-plan-gate-test-s2
result=$(echo '{"session_id":"test-s2"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "no flag file → deny" "$result" '"deny"'

# Test 5: Fresh flag file → allow + file deleted
touch /tmp/claude-plan-gate-test-s3
result=$(echo '{"session_id":"test-s3"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "fresh flag file → allow" "$result" '"allow"'
test_file_absent "flag file deleted after allow" "/tmp/claude-plan-gate-test-s3"

# Test 6: Stale flag (>5min) → deny + file deleted
touch -t 202501010000 /tmp/claude-plan-gate-test-s4
result=$(echo '{"session_id":"test-s4"}' | "$PERM_HOOK" 2>/dev/null)
test_contains "stale flag → deny" "$result" '"deny"'
test_file_absent "stale flag cleaned up" "/tmp/claude-plan-gate-test-s4"

echo
echo "jq-less fallback mode:"

# Test 7: PostToolUse without jq → should still work
result=$(echo '{"tool_input":{"file_path":"/x/.claude/plans/test.md"},"session_id":"test-s5"}' | PATH="$NO_JQ_PATH" "$POST_HOOK" 2>/dev/null)
test_contains "PostToolUse works without jq" "$result" "PLAN REVIEW GATE"

# Test 8: PermissionRequest without jq → should deny
rm -f /tmp/claude-plan-gate-test-s6
result=$(echo '{"session_id":"test-s6"}' | PATH="$NO_JQ_PATH" "$PERM_HOOK" 2>/dev/null)
test_contains "PermissionRequest denies without jq" "$result" '"deny"'

# Cleanup
rm -f /tmp/claude-plan-gate-test-s*
rm -rf "$FAKE_JQ_DIR"

echo
echo "=== Results: ${PASS}/${TOTAL} passed, ${FAIL} failed ==="
echo "Log entries: $(wc -l < "$LOG" | tr -d ' ')"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
