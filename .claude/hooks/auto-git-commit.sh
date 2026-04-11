#!/usr/bin/env bash
# auto-git-commit.sh — Auto-commit and push on Claude Code session exit
# Called by the exit orchestrator and compatible with direct hook execution.
# Receives hook JSON on stdin with session_id, cwd, etc.

set -euo pipefail

LOGFILE="${AUTO_GIT_LOGFILE:-/tmp/auto-git-commit.log}"
RESULT_FILE="${AUTO_GIT_RESULT_FILE:-}"
LAST_STDERR=""
REPO_ROOT=""
BRANCH=""
LOCK_DIR=""
LOCK_HELD="false"
UNSAFE_ROOTS=(
  "$HOME"
  "$HOME/git"
  "$HOME/git/_buffer"
  "$HOME/git/apps"
  "$HOME/git/mcps"
  "$HOME/git/research"
  "$HOME/git/skills"
)

mkdir -p "$(dirname "$LOGFILE")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOGFILE" 2>/dev/null; }
is_unsafe_root() {
  local candidate="${1%/}"
  local root

  for root in "${UNSAFE_ROOTS[@]}"; do
    if [ "$candidate" = "${root%/}" ]; then
      return 0
    fi
  done

  return 1
}
capture_stderr() {
  local tmp
  local status

  tmp=$(mktemp /tmp/auto-git-commit-stderr-XXXXXX)
  if "$@" >/dev/null 2>"$tmp"; then
    LAST_STDERR=""
    rm -f "$tmp"
    return 0
  else
    status=$?
  fi

  LAST_STDERR="$(tr '\n' ' ' <"$tmp" | awk '{$1=$1; print}')"
  rm -f "$tmp"
  return "$status"
}
write_result() {
  [ -n "$RESULT_FILE" ] || return 0
  cat > "$RESULT_FILE" <<EOF
result=$1
detail=${2:-}
repo_root=${3:-}
branch=${4:-}
EOF
}
finish() {
  write_result "$1" "${2:-}" "${3:-}" "${4:-}"
  log "RESULT result=$1 detail=${2:-} repo=${3:-unknown} branch=${4:-} stderr=${LAST_STDERR:-}"
  exit "${5:-0}"
}
cleanup() {
  if [ "$LOCK_HELD" = "true" ] && [ -n "$LOCK_DIR" ] && [ -d "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'log "ERROR in ${CWD:-unknown} at line $LINENO stderr=${LAST_STDERR:-}"; write_result error unexpected-error "${REPO_ROOT:-}" "${BRANCH:-}"; exit 1' ERR

INPUT=$(cat)
log "START input_length=${#INPUT}"
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Guard: prevent infinite loops
[ "$STOP_HOOK_ACTIVE" = "true" ] && finish "skip-stop-hook-active" "" "" "" 0

# Guard: CWD must exist
[ -z "$CWD" ] && finish "skip-no-cwd" "" "" "" 0
[ ! -d "$CWD" ] && finish "skip-missing-cwd" "" "" "" 0

# Guard: never operate from top-level home/container roots
if is_unsafe_root "$CWD"; then
  if [ "${CWD%/}" = "${HOME%/}" ]; then
    finish "skip-home-root" "" "" "" 0
  fi
  finish "skip-container-root" "" "" "" 0
fi

# Guard: never auto-initialize repos from SessionEnd
if ! git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null; then
  finish "skip-not-a-repo" "" "" "" 0
fi

# Navigate to repo root (handles being inside a subdirectory)
REPO_ROOT="$(git -C "$CWD" rev-parse --show-toplevel)"
if is_unsafe_root "$REPO_ROOT"; then
  if [ "${REPO_ROOT%/}" = "${HOME%/}" ]; then
    finish "skip-home-root" "" "$REPO_ROOT" "" 0
  fi
  finish "skip-container-root" "" "$REPO_ROOT" "" 0
fi

cd "$REPO_ROOT"
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || echo ".git")
case "$GIT_DIR" in
  /*) ;;
  *) GIT_DIR="$REPO_ROOT/$GIT_DIR" ;;
esac
LOCK_DIR="$GIT_DIR/.claude-session-end.lock"
if ! capture_stderr mkdir "$LOCK_DIR"; then
  if [ -d "$LOCK_DIR" ]; then
    LAST_STDERR=""
    finish "skip-repo-busy" "" "$REPO_ROOT" "$BRANCH" 0
  fi
  finish "error" "lock-failed" "$REPO_ROOT" "$BRANCH" 1
fi
LOCK_HELD="true"

# Check for uncommitted changes (staged, unstaged, or untracked)
STATUS_OUTPUT="$(git status --porcelain=v1 --untracked-files=normal 2>/dev/null || true)"
if [ -z "$STATUS_OUTPUT" ]; then
  finish "skip-clean-repo" "" "$REPO_ROOT" "$BRANCH" 0
fi

# Stage all changes (respects .gitignore)
if ! capture_stderr git add -A; then
  finish "error" "git-add-failed" "$REPO_ROOT" "$BRANCH" 1
fi

# Build descriptive commit message
DATE=$(date '+%Y-%m-%d %H:%M')
CHANGED="$(git diff --cached --stat | tail -1 | awk '{$1=$1; print}')"
[ -z "$CHANGED" ] && CHANGED="No diff stat available"
if ! capture_stderr git commit -m "Auto-commit on session exit (${DATE})" \
                -m "${CHANGED}"; then
  finish "error" "commit-failed" "$REPO_ROOT" "$BRANCH" 1
fi

# Push to remote if it exists and we're on main/master
PUSH_DETAIL=""
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  if git remote -v 2>/dev/null | grep -q origin; then
    # Run gitleaks if available
    if command -v gitleaks &>/dev/null; then
      if ! capture_stderr gitleaks detect --no-banner -q; then
        finish "error" "gitleaks-detected" "$REPO_ROOT" "$BRANCH" 1
      fi
    fi
    if capture_stderr git push origin "$BRANCH"; then
      PUSH_DETAIL="push-ok"
    else
      finish "error" "push-failed" "$REPO_ROOT" "$BRANCH" 1
    fi
  else
    PUSH_DETAIL="no-origin"
  fi
else
  PUSH_DETAIL="no-push-branch"
fi

finish "success" "${PUSH_DETAIL:-commit-only}" "$REPO_ROOT" "$BRANCH" 0
