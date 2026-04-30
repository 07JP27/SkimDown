# インストール

## システム要件

- **macOS 26**（Tahoe）以降
- `.md` または `.markdown` ファイルを含むフォルダ

## ダウンロードとインストール

1. [Releases ページ](https://github.com/07JP27/SkimDown/releases) から最新の `.dmg` をダウンロード
2. `.dmg` を開き、**SkimDown.app** を **Applications** フォルダにドラッグ
3. Applications から SkimDown を起動

## 検疫フラグの解除

「Appleは、"SkimDown"にMacに損害を与えたり、プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。」という警告が表示された場合は、**ターミナル**で以下のコマンドを実行して検疫フラグを解除してください：

```bash
xattr -cr /Applications/SkimDown.app
```

::: warning
[ソースコード](https://github.com/07JP27/SkimDown) の内容を確認の上、自己責任で実行してください。
:::

## 初回起動

1. SkimDown を開きます。
2. **File → Open Folder…** を選ぶ（または **⌘O**、もしくはウィンドウへフォルダをドラッグ&ドロップ）。
3. 読みたい Markdown ファイルが入っているフォルダを選択します。

SkimDown は macOS のフォルダ選択ダイアログを使ってアクセスします。選んだフォルダを読み取り、その後も最近開いたフォルダとして再表示できるよう、app-scoped security-scoped bookmark として権限を保存します。

::: tip
SkimDown は**読み取り専用**です。Markdown ファイルを編集・保存・エクスポート・変更することはありません。
:::

## アップデート

[Releases ページ](https://github.com/07JP27/SkimDown/releases) から新しい `.dmg` をダウンロードし、Applications フォルダ内の **SkimDown.app** を置き換えてください。Gatekeeper の警告が再び出る場合は `xattr -cr /Applications/SkimDown.app` を再度実行してください。

## 次に読む

起動後の操作は [使い方](./usage.md) を参照してください。フォルダを開く、ツリーを移動する、Markdown をプレビューする、表示中ファイルを検索する流れを説明しています。
