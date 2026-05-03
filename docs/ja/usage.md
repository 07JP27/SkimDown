# 使い方

SkimDownの基本は、フォルダを開き、Markdownツリーを眺め、選択したファイルをきれいなプレビューで読むことです。

## 基本フロー

1. `File > Open Folder...`、`Cmd+O`、空状態のボタン、またはドラッグ&ドロップでフォルダを開きます。
2. サイドバーからMarkdownファイルを選びます。
3. レンダリングされたプレビューを読みます。
4. `Cmd+F` で表示中ファイル内を検索します。
5. 相対Markdownリンクでファイル間を移動します。

## サイドバーに表示されるもの

SkimDownは `.md` と `.markdown` だけを表示します。フォルダを再帰的に走査し、隠しファイル/フォルダや生成物ディレクトリを除外し、Markdownを含まない空フォルダは表示しません。

## 表示しないもの

SkimDownは読み取り専用です。Markdown編集、コメント、エクスポート、印刷、ファイル名検索、複数ファイル横断検索は行いません。

## サンプルで試す

自分のフォルダを開く前に SkimDown のレンダリングを試したい場合は、リポジトリ同梱の [`samples/`](https://github.com/07JP27/SkimDown/tree/main/samples) ディレクトリを開いてください。サポートされる Markdown 記法を網羅したリファレンス用ファイルが揃っています。

含まれるカテゴリ:

- **基本** — 見出し、テキスト装飾、リンクと画像、リスト
- **ブロック要素** — 引用、コードブロック、テーブル、区切り線
- **拡張記法** — 脚注、数式（KaTeX）、ダイアグラム（Mermaid）、HTML 要素
- **その他** — 深い階層のフォルダ、全記法をまとめた1ファイル、`.markdown` 拡張子

試し方:

1. リポジトリを clone するかダウンロードします。
2. SkimDown で **File → Open Folder…** を選び、`samples/ja`（日本語版）または `samples/en`（英語版）を開きます。
3. ツリーをたどって各サンプルを閲覧します。

ファイル一覧は [`samples/README_ja.md`](https://github.com/07JP27/SkimDown/blob/main/samples/README_ja.md) にまとまっています。SkimDown は読み取り専用なので、samples フォルダを開いても中身が編集・追加されることはありません。

## 詳細

- [フォルダを開く](./usage/open-folder.md)
- [プレビュー](./usage/preview.md)
- [設定](./usage/settings.md)
- [検索](./usage/search.md)
- [自動更新](./usage/reload.md)
- [セキュリティモデル](./security.md)

