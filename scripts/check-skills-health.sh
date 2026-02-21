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
command -v rg >/dev/null 2>&1 || {
  echo "Missing required command: rg" >&2
  exit 1
}

failures=0
checked=0

while IFS=$'	' read -r skill_name skill_source; do
  checked=$((checked + 1))
  link_path="${CLAUDE_SKILLS_DIR}/${skill_name}"

  if [ ! -L "${link_path}" ]; then
    echo "FAIL: missing or non-symlink skill entry: ${link_path}"
    failures=$((failures + 1))
    continue
  fi

  resolved="$(readlink "${link_path}")"
  if [ "${resolved}" != "${skill_source}" ]; then
    echo "FAIL: bad symlink target for ${skill_name}: ${resolved} (expected ${skill_source})"
    failures=$((failures + 1))
  fi

  if [ ! -d "${skill_source}" ]; then
    echo "FAIL: source directory missing for ${skill_name}: ${skill_source}"
    failures=$((failures + 1))
    continue
  fi

  skill_md="${skill_source}/SKILL.md"
  if [ ! -f "${skill_md}" ]; then
    echo "FAIL: SKILL.md missing for ${skill_name}: ${skill_md}"
    failures=$((failures + 1))
    continue
  fi

  if ! sed -n '1,20p' "${skill_md}" | rg -q '^name:\s*\S'; then
    echo "FAIL: missing frontmatter name in ${skill_md}"
    failures=$((failures + 1))
  fi
  if ! sed -n '1,20p' "${skill_md}" | rg -q '^description:\s*\S'; then
    echo "FAIL: missing frontmatter description in ${skill_md}"
    failures=$((failures + 1))
  fi

done < <(jq -r '.skills[] | [.name, .source] | @tsv' "${MANIFEST_PATH}")

echo "Checked: ${checked}, failures: ${failures}"

if [ "${failures}" -gt 0 ]; then
  exit 1
fi
