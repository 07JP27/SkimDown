# リンクと画像

## 内部リンク（相対パス）

SkimDown では Markdown ファイル間を相対パスでリンクできます:

- [README に戻る](../README.md)
- [見出しサンプル](headings.md)
- [テキスト装飾](text-formatting.md)
- [リストサンプル](lists.md)
- [深い階層のファイル](../deep/nested/folder/deep-file.md)

## アンカーリンク

同じドキュメント内のセクションへジャンプできます:

- [外部リンクへ](#外部リンク)
- [画像セクションへ](#画像)
- [ページ最上部へ](#リンクと画像)

## 外部リンク

- [GitHub](https://github.com)
- [markdown-it](https://github.com/markdown-it/markdown-it)
- [KaTeX](https://katex.org)
- [Mermaid](https://mermaid.js.org)

自動リンク: https://github.com/07JP27/SkimDown

## 画像

### 外部画像

![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png)

### タイトル付き画像

![GitHub Logo](https://github.githubassets.com/favicons/favicon.svg "GitHub のロゴ")

## リンク付き画像

[![GitHub](https://github.githubassets.com/favicons/favicon.svg)](https://github.com)

## 空リンク・壊れたリンク

以下はエッジケースのテスト:

- [空のリンク]()
- [存在しないファイル](non-existent.md)
