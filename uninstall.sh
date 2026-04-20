#!/usr/bin/env bash
# Date-Weekday Validation Hook uninstaller

set -euo pipefail

HOOK_DST="${HOME}/.claude/hooks/validate_dates.py"
SETTINGS="${HOME}/.claude/settings.json"
BACKUP="${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です"; exit 1; }

if [ -f "${HOOK_DST}" ]; then
  rm "${HOOK_DST}"
  echo "✓ Removed: ${HOOK_DST}"
fi

if [ -f "${SETTINGS}" ]; then
  if ! jq empty "${SETTINGS}" >/dev/null 2>&1; then
    echo "ERROR: ${SETTINGS} が有効なJSONではありません。手動で修復してから再実行してください。" >&2
    exit 1
  fi

  cp "${SETTINGS}" "${BACKUP}"
  echo "✓ Backup: ${BACKUP}"

  if ! jq '
    if .hooks.PostToolUse then
      .hooks.PostToolUse |= map(
        select(
          (.hooks // []) |
          any(.command // "" | contains("validate_dates.py")) | not
        )
      )
    else . end
  ' "${SETTINGS}" > "${SETTINGS}.tmp"; then
    echo "ERROR: settings.json の更新に失敗しました。バックアップは ${BACKUP} に保存済みです。" >&2
    rm -f "${SETTINGS}.tmp"
    exit 1
  fi

  mv "${SETTINGS}.tmp" "${SETTINGS}"
  echo "✓ Updated: ${SETTINGS}"
fi

echo "アンインストール完了。"
