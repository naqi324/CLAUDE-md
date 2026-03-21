#!/bin/sh
# Verify that tracked repo mirrors match the live ~/.claude surfaces and that
# hook commands referenced by settings.json exist on disk.

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LIVE_DIR="${HOME}/.claude"
STATUS=0

check_pair() {
    local label="$1" repo_file="$2" live_file="$3"
    printf "Checking %s...\n" "$label"
    if [ ! -f "$repo_file" ]; then
        printf "FAIL: repo file missing: %s\n" "$repo_file"
        STATUS=1
        return
    fi
    if [ ! -f "$live_file" ]; then
        printf "FAIL: live file missing: %s\n" "$live_file"
        STATUS=1
        return
    fi
    if diff -u "$repo_file" "$live_file"; then
        printf "PASS: %s matches live config.\n" "$label"
    else
        STATUS=1
    fi
}

check_hook_targets() {
    local settings_file="$1"
    local missing=0 targets_file
    printf "Checking hook targets referenced by %s...\n" "$settings_file"
    if ! command -v jq >/dev/null 2>&1; then
        printf "FAIL: jq is required to inspect hook targets.\n"
        STATUS=1
        return
    fi
    targets_file=$(mktemp)
    jq -r '.. | objects | select(has("command")) | .command' "$settings_file" > "$targets_file"
    while IFS= read -r command; do
        case "$command" in
            /Users/naqi.khan/git/CLAUDE-md/.claude/hooks/*)
                if [ -e "$command" ]; then
                    printf "PASS: hook target exists: %s\n" "$command"
                else
                    printf "FAIL: missing hook target: %s\n" "$command"
                    missing=1
                fi
                ;;
        esac
    done < "$targets_file"
    rm -f "$targets_file"
    if [ "$missing" -ne 0 ]; then
        STATUS=1
    fi
}

check_pair "CLAUDE.md" "${REPO_DIR}/CLAUDE.md" "${LIVE_DIR}/CLAUDE.md"
check_pair ".claude/settings.json" "${REPO_DIR}/.claude/settings.json" "${LIVE_DIR}/settings.json"
check_hook_targets "${REPO_DIR}/.claude/settings.json"

if [ "$STATUS" -ne 0 ]; then
    printf "Config parity check FAILED.\n"
    exit 1
fi

printf "Config parity check PASSED.\n"
