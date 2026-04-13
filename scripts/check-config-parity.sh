#!/bin/sh
# Verify that tracked repo mirrors match the live ~/.claude surfaces and that
# every command referenced by settings.json exists and is executable.

set -eu

REPO_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LIVE_DIR="${HOME}/.claude"
STATUS=0
REQUIRED_SENSITIVE_READ_ASK_RULES='[
  "Read(~/.ssh/**)",
  "Read(~/.gnupg/**)",
  "Read(~/.aws/**)",
  "Read(~/.azure/**)",
  "Read(~/.kube/**)",
  "Read(~/.npmrc)",
  "Read(~/.git-credentials)",
  "Read(~/.config/gh/**)",
  "Read(.env)",
  "Read(./.env)",
  "Read(*.env)",
  "Read(**/.env)",
  "Read(.env.*)",
  "Read(./.env.*)",
  "Read(**/.env.*)"
]'

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

resolve_command_path() {
    case "$1" in
        "~/"*)
            printf "%s/%s\n" "$HOME" "${1#\~/}"
            ;;
        /*)
            printf "%s\n" "$1"
            ;;
        *)
            return 1
            ;;
    esac
}

check_command_targets() {
    local settings_file="$1"
    local failed=0 targets_file target
    printf "Checking command targets referenced by %s...\n" "$settings_file"
    if ! command -v jq >/dev/null 2>&1; then
        printf "FAIL: jq is required to inspect command targets.\n"
        STATUS=1
        return
    fi
    targets_file=$(mktemp)
    jq -r '.. | objects | select(has("command")) | .command' "$settings_file" > "$targets_file"
    while IFS= read -r command; do
        [ -n "$command" ] || continue
        if ! target="$(resolve_command_path "$command")"; then
            printf "FAIL: command target is not a direct path: %s\n" "$command"
            failed=1
            continue
        fi
        if [ -e "$target" ]; then
            printf "PASS: command target exists: %s\n" "$target"
        else
            printf "FAIL: missing command target: %s\n" "$target"
            failed=1
            continue
        fi
        if [ -x "$target" ]; then
            printf "PASS: command target is executable: %s\n" "$target"
        else
            printf "FAIL: command target is not executable: %s\n" "$target"
            failed=1
        fi
    done < "$targets_file"
    rm -f "$targets_file"
    if [ "$failed" -ne 0 ]; then
        STATUS=1
    fi
}

check_sensitive_read_ask_rules() {
    local label="$1" settings_file="$2" missing_file
    printf "Checking sensitive read ask rules in %s...\n" "$label"
    if ! command -v jq >/dev/null 2>&1; then
        printf "FAIL: jq is required to inspect sensitive read ask rules.\n"
        STATUS=1
        return
    fi
    missing_file=$(mktemp)
    jq -r --argjson required "$REQUIRED_SENSITIVE_READ_ASK_RULES" \
        '($required - (.permissions.ask // []))[]?' \
        "$settings_file" > "$missing_file"
    if [ -s "$missing_file" ]; then
        while IFS= read -r rule; do
            [ -n "$rule" ] || continue
            printf "FAIL: missing sensitive read ask rule in %s: %s\n" "$label" "$rule"
        done < "$missing_file"
        STATUS=1
    else
        printf "PASS: sensitive read ask rules present in %s.\n" "$label"
    fi
    rm -f "$missing_file"
}

check_pair "CLAUDE.md" "${REPO_DIR}/CLAUDE.md" "${LIVE_DIR}/CLAUDE.md"
check_pair ".claude/settings.json" "${REPO_DIR}/.claude/settings.json" "${LIVE_DIR}/settings.json"
check_sensitive_read_ask_rules "repo settings" "${REPO_DIR}/.claude/settings.json"
check_sensitive_read_ask_rules "live settings" "${LIVE_DIR}/settings.json"
check_command_targets "${REPO_DIR}/.claude/settings.json"

if [ "$STATUS" -ne 0 ]; then
    printf "Config parity check FAILED.\n"
    exit 1
fi

printf "Config parity check PASSED.\n"
