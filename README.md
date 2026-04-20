# Date-Weekday Validation Hook

Claude Code 用の **PostToolUse hook**。日本語テキスト中の「日付 + 曜日」表記の整合性を自動検証し、曜日が間違っている場合にエラーで停止します。

## 何を防ぐか

LLM が生成する日本語コンテンツ（メルマガ・LP・記事・告知文）では、日付と曜日がズレる事故が頻発します。

例えば「4月29日」という日付に対し `(火)` と書かれていても、実際は水曜日だった、というケース。人間のレビューでも見落としやすく、配信事故・告知ミスの原因になります。

このフックは `Write` / `Edit` / `MultiEdit` の直後に自動走査し、間違いを検出すると **exit code 2** で停止します。Claude Code は stderr 出力を受け取り、自己修正します。

## 検出パターン

| パターン | 形式 |
|---|---|
| 年月日 + 曜日 | `YYYY年M月D日(曜)` / `YYYY年M月D日（曜曜日）` |
| 月日 + 曜日（年省略） | `M月D日(曜)` / `M月D日（曜曜日）` |
| YYYY/M/D + 曜日 | `YYYY/M/D(曜)` / `YYYY-M-D(曜)` |
| M/D + 曜日（年省略） | `M/D(曜)` / `M/D（曜）` |

- 曜日文字: 月・火・水・木・金・土・日
- カッコ: 半角 `()` / 全角 `（）` 両対応
- 曜日単体（「火」）・曜日フル（「火曜」「火曜日」）両対応
- 年省略時は現在の年を推定（3ヶ月以上過去なら翌年と推定）
- 対象拡張子: `.md` / `.html` / `.txt` / `.csv` / `.json`

## 要件

- **Python 3.8 以上**（標準ライブラリのみ / 追加パッケージ不要）
- **jq**（install.sh が settings.json を安全にマージするため）
- macOS / Linux / Windows (WSL)
- Claude Code

## インストール

```bash
git clone https://github.com/FP-sudo/date-weekday-validation-hook.git
cd date-weekday-validation-hook
./install.sh
```

実行後、**新しい Claude Code セッション**から有効になります。

`install.sh` は以下を行います：

1. `validate_dates.py` を `~/.claude/hooks/` にコピー
2. `~/.claude/settings.json` の `hooks.PostToolUse` に登録（既存 hook は保持）
3. 既存 `settings.json` をタイムスタンプ付きでバックアップ
4. 登録済みの場合はスキップ（冪等）

## アンインストール

```bash
./uninstall.sh
```

## 動作イメージ

誤った曜日が書かれたファイルを Claude Code が編集した直後、hook が次のような stderr を出力します：

```
[日付エラー] 行N: "<日付表記>" → YYYY年M月D日はX曜日ではなく【Y曜日】です
```

Claude Code はこの stderr を受け取り、自動で曜日を修正します。

## 一時的に無効化したい場合

このフック自身を開発・テストしている時や、わざと「誤った曜日の例」を含むドキュメントを書きたい時は、**一時的に無効化**できます。

### 方法1: settings.json を直接編集

```bash
# 元の settings を退避
cp ~/.claude/settings.json ~/.claude/settings.json.disabled

# validate_dates.py エントリだけ除外した版を本体に書き戻す
jq '.hooks.PostToolUse |= map(select((.hooks // []) | any(.command // "" | contains("validate_dates.py")) | not))' \
  ~/.claude/settings.json.disabled > ~/.claude/settings.json

# 作業後、退避から復元
mv ~/.claude/settings.json.disabled ~/.claude/settings.json
```

### 方法2: フックスクリプトをリネーム

```bash
mv ~/.claude/hooks/validate_dates.py ~/.claude/hooks/validate_dates.py.off
# 作業後
mv ~/.claude/hooks/validate_dates.py.off ~/.claude/hooks/validate_dates.py
```

hook 設定は Claude Code の**新セッション**で読み込まれるので、方法1の場合は新しいセッションで有効になります。方法2は即時反映されます。

### 方法3: Bash / Python で直接ファイル書き込み

フックは `Write` / `Edit` / `MultiEdit` ツールの PostToolUse にのみ登録されています。`Bash` ツールから `python3 script.py` などでファイルを書き出す経路には介入しません。短時間の回避策として有効です。

## 手動で settings.json に追加する場合

`install.sh` を使わず手動設定したい場合、`~/.claude/settings.json` の `hooks.PostToolUse` に以下を追加：

```json
{
  "matcher": "Write|Edit|MultiEdit",
  "hooks": [
    {
      "type": "command",
      "command": "python3 ~/.claude/hooks/validate_dates.py",
      "statusMessage": "日付+曜日の整合性チェック",
      "timeout": 10
    }
  ]
}
```

## カスタマイズ

`validate_dates.py` の以下を編集すると動作を変えられます：

- **対象拡張子**: `main()` 内の `('.md', '.html', '.txt', '.csv', '.json')`
- **年省略時の推定**: `guess_year()` — デフォルトは「3ヶ月以上過去なら翌年」
- **検出パターン**: `PATTERNS` 配列に正規表現を追加

## なぜこれが必要か

LLM はカレンダー計算が苦手です。特に：

- 次回配信日を「来週の◯曜日」と書いてほしい指示で曜日をミスる
- 祝日や月またぎで曜日がズレる
- プロンプトで日付だけ変えさせたとき曜日を更新し忘れる

人間のレビューでも見落としやすいため、**自動検証の最後の砦**として機能します。

## ライセンス

MIT
