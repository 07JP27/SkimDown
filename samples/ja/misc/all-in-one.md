# 全記法まとめ（All-in-One）

このファイルは SkimDown がサポートする全ての Markdown 記法を1つにまとめたものです。

---

## 見出し

### h3 見出し

#### h4 見出し

##### h5 見出し

###### h6 見出し

## テキスト装飾

**太字** / *斜体* / ***太字斜体*** / ~~取り消し線~~ / `インラインコード`

## リンクと画像

- [内部リンク](../../README_ja.md)
- [外部リンク](https://github.com)
- [アンカーリンク](#見出し)

![Octocat](https://github.githubassets.com/images/icons/emoji/octocat.png)

## リスト

### 順序なし

- 項目 A
  - サブ項目 1
  - サブ項目 2
- 項目 B

### 順序付き

1. First
2. Second
3. Third

### タスクリスト

- [x] 完了タスク
- [ ] 未完了タスク

## 引用

> 引用テキストです。
>
> > ネストした引用です。

## コードブロック

```swift
struct SkimDown {
    let name = "SkimDown"
    let platform = "macOS"

    func greet() -> String {
        "Markdown を、読むモードへ。"
    }
}
```

```javascript
const md = window.markdownit({ html: true, linkify: true });
const html = md.render("# Hello, SkimDown!");
document.getElementById("content").innerHTML = html;
```

## テーブル

| 機能 | 状態 | 備考 |
|:---|:---:|---:|
| Markdown 表示 | ✅ | markdown-it |
| 数式 | ✅ | KaTeX |
| ダイアグラム | ✅ | Mermaid |
| コードハイライト | ✅ | highlight.js |

## 区切り線

---

## 脚注

SkimDown は軽量なビューアーです[^1]。KaTeX で数式も描画できます[^2]。

[^1]: 読む専用で編集機能は持っていません。
[^2]: インラインとディスプレイの両方に対応。

## 数式

インライン: $E = mc^2$

ディスプレイ:

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

## Mermaid

```mermaid
flowchart LR
    A[Markdown] --> B[markdown-it]
    B --> C[HTML]
    C --> D[DOMPurify]
    D --> E[WebView に表示]
```

## HTML 要素

<kbd>⌘</kbd> + <kbd>O</kbd> でフォルダを開く

<details>
<summary>詳細を表示</summary>

折りたたまれた内容がここに表示されます。

</details>

<mark>ハイライトされたテキスト</mark>

---

以上が SkimDown でサポートされる全ての Markdown 記法です。
