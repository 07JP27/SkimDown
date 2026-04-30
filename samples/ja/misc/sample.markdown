# .markdown 拡張子テスト

このファイルは `.md` ではなく `.markdown` 拡張子で保存されています。

SkimDown の `MarkdownScanner` は `.md` と `.markdown` の両方をサポートしています。このファイルがサイドバーのツリーに表示されていれば、`.markdown` 拡張子の認識が正しく動作しています。

## 確認ポイント

- [x] サイドバーのツリーに表示されている
- [ ] 内容が正しくレンダリングされている
- [ ] 他のファイルからのリンクが機能する

## コード確認

対応する Swift コード:

```swift
var skimdownIsMarkdownFile: Bool {
    let ext = pathExtension.lowercased()
    return ext == "md" || ext == "markdown"
}
```

> このファイルが表示されていれば、上記のコードが正しく機能しています。
