# HTML 要素

Markdown 内で使用できる HTML 要素のサンプルです。

## キーボードショートカット（kbd）

SkimDown で使えるキーボードショートカット:

| 操作 | ショートカット |
|---|---|
| フォルダを開く | <kbd>⌘</kbd> + <kbd>O</kbd> |
| ページ内検索 | <kbd>⌘</kbd> + <kbd>F</kbd> |
| 次の検索結果 | <kbd>⌘</kbd> + <kbd>G</kbd> |
| 前の検索結果 | <kbd>⌘</kbd> + <kbd>Shift</kbd> + <kbd>G</kbd> |
| フォントサイズ拡大 | <kbd>⌘</kbd> + <kbd>+</kbd> |
| フォントサイズ縮小 | <kbd>⌘</kbd> + <kbd>-</kbd> |

テキスト中でも使えます: <kbd>Ctrl</kbd> + <kbd>C</kbd> でコピー、<kbd>Ctrl</kbd> + <kbd>V</kbd> でペーストします。

## 折りたたみ（details / summary）

<details>
<summary>SkimDown の技術スタック（クリックで展開）</summary>

- **言語:** Swift 6
- **UI フレームワーク:** AppKit
- **Markdown パーサー:** markdown-it
- **数式:** KaTeX
- **ダイアグラム:** Mermaid
- **コードハイライト:** highlight.js
- **サニタイズ:** DOMPurify

</details>

<details>
<summary>サポートする Markdown 拡張子</summary>

| 拡張子 | 対応 |
|---|---|
| `.md` | ✅ |
| `.markdown` | ✅ |
| `.txt` | ❌ |
| `.rst` | ❌ |

</details>

<details>
<summary>除外されるディレクトリ</summary>

以下のディレクトリは `MarkdownScanner` によって自動的にスキップされます:

1. `.git`
2. `node_modules`
3. `.build`
4. `DerivedData`

これらはバージョン管理やビルドの成果物であり、Markdown ビューアーで表示する必要がないためです。

</details>

### ネストした折りたたみ

<details>
<summary>レイヤー構成</summary>

<details>
<summary>App レイヤー</summary>

アプリ起動、メニュー、ウィンドウ管理を担当します。

</details>

<details>
<summary>Core レイヤー</summary>

フォルダ権限、設定保存、ファイル監視を担当します。

</details>

<details>
<summary>Viewer レイヤー</summary>

WKWebView を使った Markdown の描画を担当します。

</details>

</details>

## ハイライト（mark）

SkimDown の最大の特徴は <mark>読む専用の Markdown ビューアー</mark> であることです。

重要なポイント: <mark>Sandbox 対応</mark> により、ユーザーが選択したフォルダのみを安全に読み取ります。

<mark>ダークモード</mark> と <mark>ライトモード</mark> の両方に対応しています。
