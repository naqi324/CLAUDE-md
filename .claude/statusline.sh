#!/bin/bash
input=$(cat)

# Extract fields via jq
session_id=$(echo "$input" | jq -r '.session_id // "—"')
model_name=$(echo "$input" | jq -r '.model.display_name // "—"')
version=$(echo "$input" | jq -r '.version // "—"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // "—"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

# Full session_id (usable with `claude --resume`)
session_short="$session_id"

# Replace $HOME with ~ in project_dir, truncate to 40 chars
project_dir="${project_dir/#$HOME/~}"
if [ ${#project_dir} -gt 40 ]; then
  project_dir="…${project_dir: -39}"
fi

# Git branch
git_info=""
raw_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')
if [ -n "$raw_dir" ] && git -C "$raw_dir" rev-parse --short HEAD &>/dev/null; then
  git_branch=$(git -C "$raw_dir" symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$git_branch" ] && git_info=" | ${git_branch%%/*}"
fi

# Convert duration_ms to Xm Ys
total_seconds=$(( ${duration_ms%.*} / 1000 ))
minutes=$(( total_seconds / 60 ))
seconds=$(( total_seconds % 60 ))

# Build 15-char progress bar
bar_width=15
filled=$(printf "%.0f" "$(echo "$used_pct * $bar_width / 100" | bc -l 2>/dev/null || echo 0)")
[ "$filled" -lt 0 ] 2>/dev/null && filled=0
[ "$filled" -gt "$bar_width" ] 2>/dev/null && filled=$bar_width
empty=$(( bar_width - filled ))
bar=""
for ((i=0; i<filled; i++)); do bar+="█"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

# Color the progress bar based on percentage
pct_int=${used_pct%.*}
if [ "$pct_int" -gt 80 ] 2>/dev/null; then
  bar_color=$'\033[91m'   # bright red >80%
elif [ "$pct_int" -gt 60 ] 2>/dev/null; then
  bar_color=$'\033[93m'   # bright yellow >60%
else
  bar_color=$'\033[92m'   # bright green ≤60%
fi
reset=$'\033[0m'

# Line 1
printf "🔑 %s │ 📂 %s%s\n" "$session_short" "$project_dir" "$git_info"

# Line 2
printf "🤖 %s v%s │ 🧠 ${bar_color}[%s]${reset} %.1f%% │ ⏱️  %dm %ds\n" "$model_name" "$version" "$bar" "$used_pct" "$minutes" "$seconds"
