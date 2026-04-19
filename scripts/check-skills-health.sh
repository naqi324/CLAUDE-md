#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_HELPER="${SCRIPT_DIR}/skill-manifest.py"

MANIFEST_PATH="${1:-}"
CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
CLAUDE_SKILLS_DIR="${CLAUDE_HOME}/skills"

command -v python3 >/dev/null 2>&1 || {
  echo "Missing required command: python3" >&2
  exit 1
}
command -v rg >/dev/null 2>&1 || {
  echo "Missing required command: rg" >&2
  exit 1
}

if [ -n "${MANIFEST_PATH}" ]; then
  resolved_manifest="$(python3 "${MANIFEST_HELPER}" --mode path --manifest "${MANIFEST_PATH}")"
  rows="$(python3 "${MANIFEST_HELPER}" --mode rows --home "${HOME}" --manifest "${MANIFEST_PATH}")"
  retired="$(python3 "${MANIFEST_HELPER}" --mode retired --manifest "${MANIFEST_PATH}")"
  stock="$(python3 "${MANIFEST_HELPER}" --mode stock --manifest "${MANIFEST_PATH}")"
else
  resolved_manifest="$(python3 "${MANIFEST_HELPER}" --mode path)"
  rows="$(python3 "${MANIFEST_HELPER}" --mode rows --home "${HOME}")"
  retired="$(python3 "${MANIFEST_HELPER}" --mode retired)"
  stock="$(python3 "${MANIFEST_HELPER}" --mode stock)"
fi

failures=0
checked=0

if [ -n "${rows}" ]; then
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

    if ! printf '%s\n' "${stock}" | grep -Fxq "${skill_name}"; then
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
    fi
  done <<< "${rows}"
fi

if [ -n "${retired}" ]; then
  while IFS= read -r skill_name; do
    [ -n "${skill_name}" ] || continue
    path="${CLAUDE_SKILLS_DIR}/${skill_name}"
    if [ -e "${path}" ] || [ -L "${path}" ]; then
      echo "FAIL: retired skill entry still present: ${path}"
      failures=$((failures + 1))
    fi
  done <<< "${retired}"
fi

echo "Checked: ${checked}, failures: ${failures}, manifest: ${resolved_manifest}"

if [ "${failures}" -gt 0 ]; then
  exit 1
fi
