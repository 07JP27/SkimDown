# SkimDown — アーキテクチャ

> **技術スタック:** Swift 6 + AppKit + WKWebView  
> **対象OS:** macOS 26+  
> **ビルドシステム:** Xcodeプロジェクト（xcodegenで生成）  
> **配布:** ad-hoc 署名 + DMG (現状の CI フロー)。将来 Developer ID 署名 + notarization に切替可能。

## 方針

SkimDownは読む専用の軽量Markdownビューアーとして作る。アプリ本体はAppKitで構成し、Markdown表示部分だけ `WKWebView` を使う。

SwiftUIはMVPでは必須にしない。将来Settings画面を作る場合は、ZoomacIt同様に `NSHostingController` 経由で導入してよい。

## リポジトリ構成

```text
SkimDown/
├── .github/
│   └── copilot-instructions.md
├── design/
│   ├── CONCEPT.md
│   ├── SPEC.md
│   └── ARCHITECTURE.md
├── docs/
│   └── VitePress documentation
├── README.md
├── README_ja.md
├── Makefile
└── src/
    ├── project.yml
    ├── SkimDown.xcodeproj/
    ├── SkimDown/
    │   ├── App/
    │   ├── Core/
    │   ├── Sidebar/
    │   ├── Markdown/
    │   ├── Viewer/
    │   ├── Models/
    │   ├── Utilities/
    │   └── Resources/
    └── SkimDownTests/
```

ZoomacItに合わせて、`project.yml` と生成済み `.xcodeproj` はどちらもGit管理対象にする。

## レイヤー

| レイヤー | 役割 |
|---|---|
| `App` | アプリ起動、メニュー、ウィンドウ管理 |
| `Core` | フォルダ権限、設定保存、ファイル監視 |
| `Sidebar` | Markdownツリー表示、選択、開閉状態 |
| `Markdown` | ファイル走査、リンク解決、HTML生成補助 |
| `Viewer` | `WKWebView`、検索、リンククリック処理 |
| `Models` | フォルダセッション、ツリー項目、設定値 |
| `Utilities` | URL/パス、安全判定、拡張メソッド |
| `Resources` | CSS、同梱JS、テンプレート、アイコン |

## 主要コンポーネント

| コンポーネント | 役割 |
|---|---|
| `AppDelegate` | AppKitアプリのエントリ、メニュー構築、起動復元 |
| `WindowManager` | 複数ウィンドウの生成、フォルダドロップ時の振り分け |
| `DocumentWindowController` | 1フォルダ=1ウィンドウの状態管理 |
| `FolderSession` | 開いているフォルダ、選択ファイル、ツリー状態を保持 |
| `SecurityScopedBookmarkStore` | フォルダ権限の保存と復元 |
| `MarkdownScanner` | 対象Markdownの再帰走査と除外判定 |
| `MarkdownTreeBuilder` | ツリー構築、VS Code風の並び順 |
| `FileWatcher` | 変更検知、ツリー更新、プレビュー再読み込み |
| `MarkdownRenderer` | Markdown文字列からHTML表示データを作る |
| `MarkdownWebView` | `WKWebView` ラッパー、検索、コピー、テーマ反映 |
| `LinkRouter` | アンカー、相対Markdown、外部リンクを振り分ける |
| `SettingsStore` | `UserDefaults` による軽量設定保存 |

## Markdown描画

MarkdownはWebView内で描画する。軽さを優先し、同梱ライブラリは必要なMarkdownでだけ使う。

- Markdown: `markdown-it`
- 脚注: `markdown-it-footnote`
- 数式: `KaTeX`
- Mermaid: `mermaid`
- コードハイライト: `highlight.js`
- HTMLサニタイズ: `DOMPurify`

これらはアプリ内に同梱し、通常のMarkdown表示でCDNへアクセスしない。

### リソース配置

```text
Resources/
├── Web/
│   ├── renderer.html
│   ├── skimdown.css
│   ├── renderer.js
│   └── vendor/
│       ├── markdown-it/
│       ├── katex/
│       ├── mermaid/
│       ├── highlight.js/
│       └── dompurify/
├── Info.plist
├── SkimDown.entitlements
└── Assets.xcassets/
```

## 描画データフロー

```text
Open Folder
  -> security-scoped bookmark取得
  -> MarkdownScannerで走査
  -> MarkdownTreeBuilderでツリー構築
  -> 初期選択を決定
  -> UTF-8としてMarkdown読み込み
  -> MarkdownWebViewへ本文とbase URLを渡す
  -> WebView内でHTML化、サニタイズ、描画
```

ファイル変更時は `FileWatcher` がイベントを受け、短くdebounceしてから必要最小限の再走査または再描画を行う。

## セキュリティ境界

- 通常配布のmacOSアプリとして提供し、App Sandboxは採用しない
- ユーザーが選択したフォルダだけを macOS の file bookmark として記憶する (Recent Folders / 起動時の前回フォルダ復元用)
- ローカルファイル参照は開いたフォルダ内に制限する (アプリ実装側の境界チェック)
- WebViewでは任意JavaScriptをMarkdownから実行しない
- HTMLはDOMPurifyでサニタイズする
- 外部画像のためにネットワーク読み込みは許可する
- 外部リンクはアプリ内で開かず、既定ブラウザへ渡す
- Hardened Runtime を有効にし、Release entitlements は `com.apple.security.get-task-allow=false` のみとする

## パフォーマンス方針

- 起動とファイル切り替えを最優先で軽くする
- フォルダ走査と変更検知処理はUIをブロックしない
- MermaidとKaTeXは該当記法がある場合だけ有効化する
- WebViewへ渡すデータは表示中ファイルに限定する
- 複数ファイル横断検索はMVP外にして初期実装を軽く保つ
- スクロール位置保存は軽量に実装できる場合のみ入れる

## 永続化

`UserDefaults` に軽量設定を保存する。フォルダ権限はsecurity-scoped bookmarkとして保存する。

- 前回フォルダ
- 最近開いたフォルダ
- フォルダごとの最後に開いたMarkdown
- フォルダごとのツリー開閉状態
- サイドバー位置、表示状態、幅
- テーマ、フォントサイズ
- 本文検索の大文字小文字設定

## ビルド構成

ZoomacItに合わせ、Makefileに以下を用意する。

```bash
make build       # Debug build
make test        # Run unit tests
make run         # Build and launch app
make release     # Release build
make notarize    # Release build + Apple notarization
make dmg VERSION=1.0.0
make clean
make generate    # Regenerate xcodeproj
make docs
make docs-build
```

## テスト

MVPではUIよりもロジックをテストする。

| テスト対象 | 内容 |
|---|---|
| `MarkdownScannerTests` | 対象拡張子、除外ディレクトリ、隠しファイル除外 |
| `MarkdownTreeBuilderTests` | フォルダ先、名前順、空フォルダ除外 |
| `InitialSelectionTests` | 前回ファイル、README、先頭ファイルの優先順位 |
| `LinkResolverTests` | アンカー、相対Markdown、外部リンクの分類 |
| `SecurityBoundaryTests` | フォルダ外ローカル参照の拒否 |
| `SettingsStoreTests` | デフォルト値、保存、復元 |

UI自動テストはMVP外。リリース前の手動確認手順をdocsにまとめる。