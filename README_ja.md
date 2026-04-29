# SkimDown

SkimDown は、AIエージェントが生成したMarkdownドキュメント群を軽快に読むための macOS Markdown ビューアーです。フォルダを開くと Markdown だけをサイドバーに表示し、選択したファイルを読み取り専用のプレビューで表示します。

## ドキュメント

ドキュメントサイトはエンドユーザー向けのインストールと使い方を扱います。開発者向けのワークフローはこの README にまとめます。

- [English docs](docs/index.md)
- [日本語ドキュメント](docs/ja/index.md)

## MVP機能

- `File > Open Folder...`、`Cmd+O`、ドラッグ&ドロップでフォルダを開く
- 複数フォルダを複数ウィンドウで表示
- `.md` と `.markdown` の再帰検出
- 隠しファイルと除外ディレクトリのフィルタリング
- フォルダ優先、大文字小文字を区別しない Markdown ツリー
- 読み取り専用 `WKWebView` プレビュー
- 同梱レンダリングアセット
- 表示中Markdown内の検索
- サイドバー位置、表示状態、幅、テーマ、フォントサイズ、最近開いたフォルダ、最後に開いたファイル、ツリー開閉状態の保存
- Markdownの追加、削除、リネーム、更新の変更検知

## アーキテクチャ

SkimDown は Swift 6 + AppKit の macOS アプリです。Markdown プレビューは `WKWebView` と同梱 JavaScript/CSS アセットで描画するため、通常のプレビュー表示は CDN に依存しません。

```text
src/
  project.yml
  SkimDown/
    App/
    Core/
    Sidebar/
    Markdown/
    Viewer/
    Models/
    Utilities/
    Resources/
  SkimDownTests/
```

## 開発

### 必要環境

- macOS 26以降
- Xcode 26以降
- XcodeGen
- VitePress ドキュメントサイト用の Node.js と npm

### XcodeGen ワークフロー

Xcode プロジェクトは `src/project.yml` から生成します。

```bash
make generate
```

`make build`、`make test`、`make run`、`make release`、`make launch-check` は、利用前にプロジェクトを再生成します。

### ビルドと起動

```bash
make generate
make build
make run
```

### テスト

```bash
make launch-check
make test
```

`make launch-check` は、ユニットテストでは検出できない GUI 起動の失敗を確認するスモークテストです。アプリをビルドして起動し、SkimDown が前面アプリになり、画面上に SkimDown ウィンドウが存在し、アイコンや Web レンダラーなどのリソースがバンドルされていることを確認します。

ユニットテストは UI 自動化ではなく、Markdown 走査、ツリーの並び順、初期選択、リンク解決、フォルダ境界チェック、設定保存などのロジックを対象にします。

### ドキュメントサイト

```bash
make docs
make docs-build
```

`make docs` はローカルの VitePress 開発サーバーを起動します。`make docs-build` は静的サイトをビルドします。

## セキュリティ

SkimDown は Sandbox を有効にし、ユーザーが選択したフォルダにだけ読み取り専用でアクセスします。フォルダ権限は app-scoped security-scoped bookmark として保存し、ローカルファイル参照は開いたフォルダ内に制限します。埋め込みHTMLはサニタイズし、外部リンクは既定ブラウザで開きます。

## リリースと配布

```bash
make release
make notarize
make dmg VERSION=1.0.0
```

notarization には `APPLE_ID`、`APPLE_TEAM_ID`、`APPLE_APP_PASSWORD` の環境変数が必要です。
