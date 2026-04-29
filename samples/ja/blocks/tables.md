# テーブル

## 基本的なテーブル

| 名前 | 役割 | 言語 |
|---|---|---|
| AppDelegate | アプリ起動 | Swift |
| MarkdownScanner | ファイル走査 | Swift |
| renderer.js | Markdown 描画 | JavaScript |

## 列の配置（アライメント）

| 左揃え | 中央揃え | 右揃え |
|:---|:---:|---:|
| りんご | 🍎 | ¥150 |
| みかん | 🍊 | ¥80 |
| ぶどう | 🍇 | ¥300 |
| いちご | 🍓 | ¥500 |

## 装飾を含むテーブル

| 機能 | 状態 | 備考 |
|---|---|---|
| **フォルダスキャン** | ✅ 完了 | `MarkdownScanner` で実装 |
| *サイドバー* | ✅ 完了 | ツリー表示対応 |
| ~~印刷機能~~ | ❌ 対象外 | MVP では不要 |
| `コードハイライト` | ✅ 完了 | highlight.js 使用 |
| [KaTeX](https://katex.org) | ✅ 完了 | 数式レンダリング |

## 長いテーブル（横スクロール確認）

| ID | ファイル名 | パス | サイズ | 作成日 | 更新日 | 拡張子 | エンコーディング | 行数 | 状態 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | README.md | /samples/README.md | 2.1KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 45 | Active |
| 2 | headings.md | /samples/basics/headings.md | 0.8KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 30 | Active |
| 3 | code-blocks.md | /samples/blocks/code-blocks.md | 3.5KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 120 | Active |
| 4 | math.md | /samples/extended/math.md | 1.2KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 50 | Active |
| 5 | mermaid.md | /samples/extended/mermaid.md | 1.8KB | 2025-01-01 | 2025-04-29 | .md | UTF-8 | 65 | Active |

## 多行テーブル

| コンポーネント | 説明 |
|---|---|
| MarkdownScanner | 対象フォルダを再帰走査して `.md` / `.markdown` ファイルを収集する。隠しファイルや除外ディレクトリ（`.git`, `node_modules` 等）はスキップする。 |
| MarkdownTreeBuilder | 収集したファイルをツリー構造に変換する。フォルダ優先・名前順で並べ、空フォルダは除外する。 |
| MarkdownRenderer | Markdown テキストから HTML を生成する。markdown-it をベースに、脚注・数式・Mermaid をプラグインで拡張している。 |
| LinkRouter | リンクのクリックを処理する。アンカーリンク、内部 Markdown リンク、外部リンクを判別して適切に振り分ける。 |

## 単一列テーブル

| サポートする拡張子 |
|---|
| `.md` |
| `.markdown` |
