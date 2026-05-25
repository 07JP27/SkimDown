# カスタムカラーテーマ

SkimDown では、プレビュー領域のカラーテーマを JSON / JSONC ファイルで定義して切り替えられます。テーマは [VS Code のカラーテーマ形式](https://code.visualstudio.com/api/references/theme-color) に合わせているため、既存の VS Code テーマ資産を再利用できます。

## テーマの配置場所

JSON または JSONC ファイルを次のフォルダに置きます。

```text
~/Library/Application Support/SkimDown/Themes/
```

アプリからは **View → Theme → Open Themes Folder** でこのフォルダを開けます。

## JSON 形式

各ファイルは単独の VS Code カラーテーマとして書きます。VS Code テーマファイルで使われるコメントや末尾のカンマも読み込めます。たとえば、次の内容を `solarized-light.json` として保存します。

```json
{
  "$schema": "vscode://schemas/color-theme",
  "name": "Solarized Light",
  "type": "light",
  "colors": {
    "editor.background": "#fdf6e3",
    "editor.foreground": "#586e75",
    "descriptionForeground": "#93a1a1",
    "panel.border": "#eee8d5",
    "editorGroupHeader.tabsBackground": "#eee8d5",
    "editorWidget.background": "#fdf6e3",
    "textLink.foreground": "#268bd2",
    "editor.findMatchHighlightBackground": "#f8e8a5",
    "editor.findMatchBackground": "#fad880"
  }
}
```

- `name` — **View → Theme** に表示される名前です。省略するとファイル名が使われます。
- `type` — `"light"` または `"dark"` です。コードハイライト CSS と Mermaid テーマの light/dark 切り替えにも使われます。
- `colors` — VS Code のカラーキーです。SkimDown は一部のキーだけを使用し、それ以外は無視します。

`tokenColors`（シンタックスハイライト）はまだサポートしていません。コードブロックは `type` に応じて GitHub 風の light / dark ハイライトを使います。

## カラーキーの対応

複数のキーがある場合は、先頭から順に最初に見つかった値を使います。

| プレビュー要素 | VS Code カラーキー |
| -------------- | ------------------ |
| 背景 | `editor.background` |
| テキスト | `editor.foreground`, `foreground` |
| 補足テキスト | `descriptionForeground`, `disabledForeground` |
| ボーダー | `panel.border`, `editorGroup.border`, `editorWidget.border`, `contrastBorder` |
| 薄い背景 | `editorGroupHeader.tabsBackground`, `editor.lineHighlightBackground`, `sideBar.background` |
| パネル背景 | `editorWidget.background`, `editor.background` |
| リンクとアクセント | `textLink.foreground`, `editorLink.activeForeground`, `focusBorder` |
| 検索ハイライト | `editor.findMatchHighlightBackground` |
| 現在の検索一致 | `editor.findMatchBackground` |

キーが不足している場合は、テーマの `type` に応じて SkimDown 組み込みの light / dark パレットで補完します。

## テーマの再読み込み

Themes フォルダは自動監視されません。JSON または JSONC ファイルを追加または編集した後は、**View → Theme → Reload Themes** を選んで一覧を更新してください。

使用中のテーマファイルが削除された場合、次回の再読み込みまたは起動時に System テーマへ戻ります。
