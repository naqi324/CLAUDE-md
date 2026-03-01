#!/usr/bin/env bash
# auto-git-commit.sh — Auto-commit and push on Claude Code session exit
# Registered as a Stop hook in ~/.claude/settings.json
# Receives hook JSON on stdin with session_id, cwd, etc.

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Guard: prevent infinite loops
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

# Guard: CWD must exist
[ -z "$CWD" ] && exit 0
[ ! -d "$CWD" ] && exit 0

cd "$CWD"

# Init git repo if none exists
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  git init
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
  git commit -m "Initial commit" || true
fi

# Navigate to repo root (handles being inside a subdirectory)
cd "$(git rev-parse --show-toplevel)"

# Check for uncommitted changes (staged, unstaged, or untracked)
if git diff --quiet HEAD 2>/dev/null \
   && git diff --cached --quiet HEAD 2>/dev/null \
   && [ -z "$(git ls-files --others --exclude-standard)" ]; then
  exit 0
fi

# Stage all changes (respects .gitignore)
git add -A

# Build descriptive commit message
DATE=$(date '+%Y-%m-%d %H:%M')
CHANGED=$(git diff --cached --stat | tail -1)
git commit -m "Auto-commit on session exit (${DATE})" \
           -m "${CHANGED}" || true

# Push to remote if it exists and we're on main/master
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  if git remote -v 2>/dev/null | grep -q origin; then
    # Run gitleaks if available
    if command -v gitleaks &>/dev/null; then
      if ! gitleaks detect --no-banner -q 2>/dev/null; then
        exit 0
      fi
    fi
    git push origin "$BRANCH" 2>/dev/null || true
  fi
fi

exit 0
