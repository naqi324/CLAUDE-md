#!/usr/bin/env bash
#
# setup-trust.sh - Suppress Claude Code workspace trust prompt for a directory
#
# Usage: ./setup-trust.sh [directory]
#   directory: Path to trust (defaults to $HOME)
#
# Modifies ~/.claude.json to mark a directory as trusted, preventing
# the workspace trust confirmation prompt on startup.

set -euo pipefail

CLAUDE_CONFIG="${HOME}/.claude.json"
TARGET_DIR="${1:-$HOME}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)"

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    echo "Install with: brew install jq" >&2
    exit 1
fi

if [ ! -f "$CLAUDE_CONFIG" ]; then
    echo "Error: Claude config not found at $CLAUDE_CONFIG" >&2
    echo "Run Claude Code at least once to generate this file." >&2
    exit 1
fi

CURRENT_VALUE=$(jq -r --arg dir "$TARGET_DIR" '.projects[$dir].hasTrustDialogAccepted // "missing"' "$CLAUDE_CONFIG")

if [ "$CURRENT_VALUE" = "true" ]; then
    echo "Trust already enabled for: $TARGET_DIR"
    exit 0
fi

jq --arg dir "$TARGET_DIR" '
    .projects[$dir] = (.projects[$dir] // {}) + {hasTrustDialogAccepted: true}
' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp" && mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"

echo "Trust enabled for: $TARGET_DIR"
