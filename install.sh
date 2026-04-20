#!/usr/bin/env bash
# Date-Weekday Validation Hook installer for Claude Code
# - validate_dates.py を ~/.claude/hooks/ に配置
# - ~/.claude/settings.json の PostToolUse に hook を登録（既存hookは保持）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="${SCRIPT_DIR}/validate_dates.py"
HOOK_DIR="${HOME}/.claude/hooks"
HOOK_DST="${HOOK_DIR}/validate_dates.py"
SETTINGS="${HOME}/.claude/settings.json"
BACKUP="${SETTINGS}.bak.$(date +%Y%m%d%H%M%S)"

# --- 前提チェック ---
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 が見つかりません"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です (brew install jq / apt install jq)"; exit 1; }

PY_VER=$(python3 --version 2>&1 | cut -d' ' -f2)
PY_MAJ=$(echo "${PY_VER}" | cut -d. -f1)
PY_MIN=$(echo "${PY_VER}" | cut -d. -f2)
if [ "${PY_MAJ}" -lt 3 ] || { [ "${PY_MAJ}" -eq 3 ] && [ "${PY_MIN}" -lt 8 ]; }; then
  echo "ERROR: Python 3.8 以上が必要です (現在: ${PY_VER})"
  exit 1
fi

# --- settings.json 妥当性チェック（破壊防止）---
mkdir -p "$(dirname "${SETTINGS}")"
if [ ! -f "${SETTINGS}" ]; then
  echo '{}' > "${SETTINGS}"
fi
if ! jq empty "${SETTINGS}" >/dev/null 2>&1; then
  echo "ERROR: ${SETTINGS} が有効なJSONではありません。手動で修復してから再実行してください。" >&2
  exit 1
fi

# --- ファイル配置 ---
mkdir -p "${HOOK_DIR}"
cp "${HOOK_SRC}" "${HOOK_DST}"
chmod +x "${HOOK_DST}"
echo "✓ Installed: ${HOOK_DST}"

# --- settings.json 更新 ---
HOOK_CMD='python3 ~/.claude/hooks/validate_dates.py'

# 既に登録済みかチェック
if ! ALREADY=$(jq --arg cmd "${HOOK_CMD}" '
  [(.hooks.PostToolUse // [])[]?.hooks[]?.command // ""] | any(. == $cmd)
' "${SETTINGS}"); then
  echo "ERROR: settings.json の解析に失敗しました" >&2
  exit 1
fi

if [ "${ALREADY}" = "true" ]; then
  echo "✓ Already registered in ${SETTINGS} (skipped)"
else
  cp "${SETTINGS}" "${BACKUP}"
  echo "✓ Backup: ${BACKUP}"

  HOOK_JSON='{
    "matcher": "Write|Edit|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "python3 ~/.claude/hooks/validate_dates.py",
        "statusMessage": "日付+曜日の整合性チェック",
        "timeout": 10
      }
    ]
  }'

  if ! jq --argjson entry "${HOOK_JSON}" '
    .hooks = (.hooks // {})
    | .hooks.PostToolUse = (.hooks.PostToolUse // [])
    | .hooks.PostToolUse += [$entry]
  ' "${SETTINGS}" > "${SETTINGS}.tmp"; then
    echo "ERROR: settings.json の更新に失敗しました。バックアップは ${BACKUP} に保存済みです。" >&2
    rm -f "${SETTINGS}.tmp"
    exit 1
  fi

  mv "${SETTINGS}.tmp" "${SETTINGS}"
  echo "✓ Registered: ${SETTINGS}"
fi

echo ""
echo "インストール完了。新しい Claude Code セッションから有効になります。"
