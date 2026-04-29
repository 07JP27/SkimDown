# SkimDown

**Markdown を、読むモードへ。**

SkimDown は macOS 向けの軽量 Markdown ビューアーです。フォルダを開くだけで、中の Markdown ファイルをツリー表示し、美しくレンダリングします。編集機能はあえて持たず、「読む」ことに特化しています。

---

## 特徴

- 📂 **フォルダベース** — フォルダを開くと `.md` / `.markdown` ファイルを自動スキャン
- 🌲 **サイドバーツリー** — VS Code 風のツリー表示でファイルを素早くナビゲート
- 🎨 **ダーク/ライトテーマ** — システム設定に自動追従
- 📐 **数式サポート** — KaTeX による美しい数式描画
- 📊 **ダイアグラム** — Mermaid でフローチャートやシーケンス図を表示
- 🔍 **ページ内検索** — 表示中のドキュメント内をインクリメンタル検索
- 💻 **コードハイライト** — highlight.js による多言語シンタックスハイライト
- 🔗 **内部リンク** — Markdown 間の相対リンクをアプリ内でシームレスに遷移
- 🔒 **サンドボックス対応** — 選択したフォルダのみ読み取り、安全に動作

## サポートする Markdown 記法

SkimDown は以下の記法をサポートしています。各リンクからサンプルを確認できます。

### 基本記法

| 記法 | サンプル |
|---|---|
| 見出し（h1〜h6） | [headings.md](basics/headings.md) |
| テキスト装飾（太字・斜体・取り消し線） | [text-formatting.md](basics/text-formatting.md) |
| リンクと画像 | [links-and-images.md](basics/links-and-images.md) |
| リスト（順序付き・タスク） | [lists.md](basics/lists.md) |

### ブロック要素

| 記法 | サンプル |
|---|---|
| 引用 | [blockquotes.md](blocks/blockquotes.md) |
| コードブロック | [code-blocks.md](blocks/code-blocks.md) |
| テーブル | [tables.md](blocks/tables.md) |
| 区切り線 | [horizontal-rules.md](blocks/horizontal-rules.md) |

### 拡張記法

| 記法 | サンプル |
|---|---|
| 脚注 | [footnotes.md](extended/footnotes.md) |
| 数式（KaTeX） | [math.md](extended/math.md) |
| ダイアグラム（Mermaid） | [mermaid.md](extended/mermaid.md) |
| HTML 要素 | [html-elements.md](extended/html-elements.md) |

### その他

| ファイル | 用途 |
|---|---|
| [deep-file.md](deep/nested/folder/deep-file.md) | 深い階層のツリー表示確認 |
| [all-in-one.md](misc/all-in-one.md) | 全記法まとめ |
| [sample.markdown](misc/sample.markdown) | `.markdown` 拡張子の確認 |

---

## 技術スタック

- **Swift 6** + **AppKit** + **WKWebView**
- Markdown パース: [markdown-it](https://github.com/markdown-it/markdown-it)
- 数式: [KaTeX](https://katex.org)
- ダイアグラム: [Mermaid](https://mermaid.js.org)
- コードハイライト: [highlight.js](https://highlightjs.org)
- サニタイズ: [DOMPurify](https://github.com/cure53/DOMPurify)

> すべてのライブラリはアプリに同梱されており、CDN へのアクセスは不要です。
