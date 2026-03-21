#!/usr/bin/env bash
# auto-git-commit.sh — Auto-commit and push on Claude Code session exit
# Called by the exit orchestrator and compatible with direct hook execution.
# Receives hook JSON on stdin with session_id, cwd, etc.

set -euo pipefail

LOGFILE="${AUTO_GIT_LOGFILE:-/tmp/auto-git-commit.log}"
RESULT_FILE="${AUTO_GIT_RESULT_FILE:-}"

mkdir -p "$(dirname "$LOGFILE")"

log() { echo "[$(date -Iseconds)] $*" >> "$LOGFILE" 2>/dev/null; }
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
  log "RESULT result=$1 detail=${2:-} repo=${3:-unknown} branch=${4:-}"
  exit "${5:-0}"
}
trap 'log "ERROR in ${CWD:-unknown} at line $LINENO"; write_result error trap "${REPO_ROOT:-}" "${BRANCH:-}"; exit 1' ERR

INPUT=$(cat)
log "START input_length=${#INPUT}"
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Guard: prevent infinite loops
[ "$STOP_HOOK_ACTIVE" = "true" ] && finish "skip-stop-hook-active" "" "" "" 0

# Guard: CWD must exist
[ -z "$CWD" ] && finish "skip-no-cwd" "" "" "" 0
[ ! -d "$CWD" ] && finish "skip-missing-cwd" "" "" "" 0

# Guard: never init a repo in the top-level ~/git container directory
[[ "$CWD" == "$HOME/git" ]] && finish "skip-home-git" "" "" "" 0

cd "$CWD"

# Init git repo if none exists
REPO_INITIALIZED="false"
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  git init
  REPO_INITIALIZED="true"
  # Ensure .gitignore covers secrets before first commit
  if [ ! -f .gitignore ]; then
    cat > .gitignore << 'GITIGNORE'
.env*
*.pem
*.key
*.pfx
credentials.json
service-account*.json
token.json
.DS_Store
node_modules/
__pycache__/
GITIGNORE
  fi
  git add -A
  if ! git commit -m "Initial commit" >/dev/null 2>&1; then
    finish "error" "initial-commit-failed" "$CWD" "" 1
  fi
fi

# Navigate to repo root (handles being inside a subdirectory)
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# Check for uncommitted changes (staged, unstaged, or untracked)
if git diff --quiet HEAD 2>/dev/null \
   && git diff --cached --quiet HEAD 2>/dev/null \
   && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  if [ "$REPO_INITIALIZED" = "true" ]; then
    finish "success" "initialized-repo" "$REPO_ROOT" "$BRANCH" 0
  fi
  finish "skip-clean-repo" "" "$REPO_ROOT" "$BRANCH" 0
fi

# Stage all changes (respects .gitignore)
git add -A

# Build descriptive commit message
DATE=$(date '+%Y-%m-%d %H:%M')
CHANGED=$(git diff --cached --stat | tail -1)
if ! git commit -m "Auto-commit on session exit (${DATE})" \
                -m "${CHANGED}" >/dev/null 2>&1; then
  finish "error" "commit-failed" "$REPO_ROOT" "$BRANCH" 1
fi

# Push to remote if it exists and we're on main/master
PUSH_DETAIL=""
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  if git remote -v 2>/dev/null | grep -q origin; then
    # Run gitleaks if available
    if command -v gitleaks &>/dev/null; then
      if ! gitleaks detect --no-banner -q 2>/dev/null; then
        finish "error" "gitleaks-detected" "$REPO_ROOT" "$BRANCH" 1
      fi
    fi
    if git push origin "$BRANCH" >/dev/null 2>&1; then
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
