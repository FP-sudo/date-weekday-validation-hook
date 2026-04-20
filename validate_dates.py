#!/usr/bin/env python3
"""
日本語テキスト中の日付+曜日パターンを検証するフック。
Write/Edit後に実行し、曜日の間違いがあれば警告を出力する。

検出パターン:
  - 4月29日(火)  4月29日（火）  4月29日(火曜日)  4月29日（火曜日）
  - 2026年4月29日(火)  2026/4/29(火)
  - 4/29(火)  4/29（火）
"""

import calendar
import json
import re
import sys

WEEKDAYS_JA = {
    0: '月', 1: '火', 2: '水', 3: '木', 4: '金', 5: '土', 6: '日',
}

WEEKDAY_TO_NUM = {v: k for k, v in WEEKDAYS_JA.items()}

# 年月日(曜日) パターン
PATTERNS = [
    # 2026年4月29日(火) or （火曜日）
    re.compile(
        r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    # 4月29日(火) — 年なし
    re.compile(
        r'(?<!\d)(\d{1,2})\s*月\s*(\d{1,2})\s*日\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    # 2026/4/29(火) or 2026-4-29(火)
    re.compile(
        r'(\d{4})\s*[/\-]\s*(\d{1,2})\s*[/\-]\s*(\d{1,2})\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
    # 4/29(火) — 年なし
    re.compile(
        r'(?<!\d)(\d{1,2})\s*/\s*(\d{1,2})\s*[（(]\s*([月火水木金土日])\s*(?:曜日?)?\s*[）)]'
    ),
]


def guess_year(month: int, day: int) -> int:
    """年が省略された場合、現在の年または翌年を推定"""
    from datetime import date
    today = date.today()
    candidate = today.year
    try:
        d = date(candidate, month, day)
        # 3ヶ月以上過去なら翌年と推定
        if (today - d).days > 90:
            candidate += 1
    except ValueError:
        pass
    return candidate


def validate_file(file_path: str) -> list[str]:
    """ファイル内の日付+曜日を検証。エラーリストを返す。"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return []

    errors = []

    for line_num, line in enumerate(content.split('\n'), 1):
        # パターン1: 年月日(曜日)
        for m in PATTERNS[0].finditer(line):
            year, month, day, weekday = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)
            err = check_weekday(year, month, day, weekday, line_num, m.group(0))
            if err:
                errors.append(err)

        # パターン2: 月日(曜日) — 年なし
        for m in PATTERNS[1].finditer(line):
            # パターン1に既にマッチしていたらスキップ
            if PATTERNS[0].search(line[max(0, m.start()-5):m.end()]):
                continue
            month, day, weekday = int(m.group(1)), int(m.group(2)), m.group(3)
            year = guess_year(month, day)
            err = check_weekday(year, month, day, weekday, line_num, m.group(0))
            if err:
                errors.append(err)

        # パターン3: YYYY/M/D(曜日)
        for m in PATTERNS[2].finditer(line):
            year, month, day, weekday = int(m.group(1)), int(m.group(2)), int(m.group(3)), m.group(4)
            err = check_weekday(year, month, day, weekday, line_num, m.group(0))
            if err:
                errors.append(err)

        # パターン4: M/D(曜日) — 年なし
        for m in PATTERNS[3].finditer(line):
            if PATTERNS[2].search(line[max(0, m.start()-5):m.end()]):
                continue
            month, day, weekday = int(m.group(1)), int(m.group(2)), m.group(3)
            year = guess_year(month, day)
            err = check_weekday(year, month, day, weekday, line_num, m.group(0))
            if err:
                errors.append(err)

    return errors


def check_weekday(year: int, month: int, day: int, weekday_ja: str, line_num: int, matched: str) -> str | None:
    """曜日が正しいか検証。間違いならエラーメッセージを返す。"""
    try:
        from datetime import date
        d = date(year, month, day)
        correct_weekday = WEEKDAYS_JA[d.weekday()]
        if weekday_ja != correct_weekday:
            return (
                f'[日付エラー] 行{line_num}: "{matched}" → '
                f'{year}年{month}月{day}日は{weekday_ja}曜日ではなく【{correct_weekday}曜日】です'
            )
    except ValueError:
        return f'[日付エラー] 行{line_num}: "{matched}" → 無効な日付です（{year}/{month}/{day}）'
    return None


def main():
    tool_input = json.loads(sys.stdin.read())
    file_path = tool_input.get('tool_input', {}).get('file_path', '')

    if not file_path:
        return

    # テキストファイルのみ対象
    if not any(file_path.endswith(ext) for ext in ('.md', '.html', '.txt', '.csv', '.json')):
        return

    errors = validate_file(file_path)

    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
