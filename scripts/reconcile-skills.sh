#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MANIFEST_PATH="${1:-${REPO_ROOT}/.claude/skills-manifest.json}"
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
CLAUDE_SKILLS_DIR="${CLAUDE_HOME}/skills"

[ -f "${MANIFEST_PATH}" ] || {
  echo "Missing manifest: ${MANIFEST_PATH}" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || {
  echo "Missing required command: jq" >&2
  exit 1
}

mkdir -p "${CLAUDE_SKILLS_DIR}"

jq -r '.skills[] | [.name, .source] | @tsv' "${MANIFEST_PATH}" | while IFS=$'	' read -r skill_name skill_source; do
  [ -n "${skill_name}" ] || {
    echo "Invalid skill name in manifest." >&2
    exit 1
  }
  [ -d "${skill_source}" ] || {
    echo "Missing source dir for ${skill_name}: ${skill_source}" >&2
    exit 1
  }
  [ -f "${skill_source}/SKILL.md" ] || {
    echo "Missing SKILL.md for ${skill_name}: ${skill_source}/SKILL.md" >&2
    exit 1
  }

  ln -sfn "${skill_source}" "${CLAUDE_SKILLS_DIR}/${skill_name}"
  echo "Reconciled ${skill_name}"
done

echo "Claude skill reconciliation complete."
