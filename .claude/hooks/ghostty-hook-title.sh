#!/usr/bin/env bash
set -euo pipefail

[ -z "${GHOSTTY_TTY_PATH:-}" ] && exit 0
dir="${PWD##*/}"
branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
[ -n "$branch" ] && title="${dir} [${branch}] :: claude" || title="${dir} :: claude"
printf '\e]0;%s\a' "$title" > "$GHOSTTY_TTY_PATH" 2>/dev/null
