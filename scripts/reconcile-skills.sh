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

mkdir -p "${CLAUDE_SKILLS_DIR}"

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

if [ -n "${rows}" ]; then
  while IFS=$'	' read -r skill_name skill_source; do
    [ -n "${skill_name}" ] || {
      echo "Invalid skill name in manifest." >&2
      exit 1
    }
    [ -d "${skill_source}" ] || {
      echo "Missing source dir for ${skill_name}: ${skill_source}" >&2
      exit 1
    }
    if ! printf '%s\n' "${stock}" | grep -Fxq "${skill_name}" && [ ! -f "${skill_source}/SKILL.md" ]; then
      echo "Missing SKILL.md for ${skill_name}: ${skill_source}/SKILL.md" >&2
      exit 1
    fi

    ln -sfn "${skill_source}" "${CLAUDE_SKILLS_DIR}/${skill_name}"
    echo "Reconciled ${skill_name}"
  done <<< "${rows}"
fi

if [ -n "${retired}" ]; then
  while IFS= read -r skill_name; do
    [ -n "${skill_name}" ] || continue
    path="${CLAUDE_SKILLS_DIR}/${skill_name}"
    if [ -e "${path}" ] || [ -L "${path}" ]; then
      rm -rf "${path}"
      echo "Removed retired skill ${skill_name}"
    fi
  done <<< "${retired}"
fi

echo "Claude skill reconciliation complete using ${resolved_manifest}."
