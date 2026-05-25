# カスタムカラーテーマ

SkimDown では、プレビュー領域のカラーテーマを JSON ファイルで定義して切り替えられます。テーマは [VS Code のカラーテーマ形式](https://code.visualstudio.com/api/references/theme-color) に合わせているため、既存の VS Code テーマ資産を再利用できます。

## テーマの配置場所

JSON ファイルを次のフォルダに置きます。

```text
~/Library/Application Support/SkimDown/Themes/
```

アプリからは **View → Theme → Open Themes Folder** でこのフォルダを開けます。

## JSON 形式

各ファイルは単独の VS Code カラーテーマとして書きます。

```json
{
  "name": "My Theme",
  "type": "dark",
  "colors": {
    "editor.background": "#1e1e1e",
    "editor.foreground": "#d4d4d4",
    "textLink.foreground": "#3794ff"
  }
}
```

- `name` — **View → Theme** に表示される名前です。省略するとファイル名が使われます。
- `type` — `"light"` または `"dark"` です。コードハイライト CSS と Mermaid テーマの light/dark 切り替えにも使われます。
- `colors` — VS Code のカラーキーです。SkimDown は一部のキーだけを使用し、それ以外は無視します。

`tokenColors`（シンタックスハイライト）はまだサポートしていません。コードブロックは `type` に応じて GitHub 風の light / dark ハイライトを使います。

## カラーキーの対応

| SkimDown の CSS 変数 | VS Code キー（優先順） |
| -------------------- | ---------------------- |
| `--skimdown-bg` | `editor.background` |
| `--skimdown-fg` | `editor.foreground`, `foreground` |
| `--skimdown-muted` | `descriptionForeground`, `disabledForeground` |
| `--skimdown-border` | `panel.border`, `editorGroup.border`, `editorWidget.border`, `contrastBorder` |
| `--skimdown-subtle` | `editorGroupHeader.tabsBackground`, `editor.lineHighlightBackground`, `sideBar.background` |
| `--skimdown-surface` | `editorWidget.background`, `editor.background` |
| `--skimdown-accent` | `textLink.foreground`, `editorLink.activeForeground`, `focusBorder` |
| `--skimdown-mark` | `editor.findMatchHighlightBackground` |
| `--skimdown-current-mark` | `editor.findMatchBackground` |

キーが不足している場合は、テーマの `type` に応じて SkimDown 組み込みの light / dark パレットで補完します。

## テーマの再読み込み

Themes フォルダは自動監視されません。JSON ファイルを追加または編集した後は、**View → Theme → Reload Themes** を選んで一覧を更新してください。

使用中のテーマファイルが削除された場合、次回の再読み込みまたは起動時に System テーマへ戻ります。
