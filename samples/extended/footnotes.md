# 脚注（Footnotes）

## 基本的な脚注

SkimDown は markdown-it-footnote プラグインを使用して脚注をサポートしています[^1]。

脚注はドキュメントの末尾にまとめて表示されます[^2]。

[^1]: markdown-it-footnote は markdown-it のプラグインです。
[^2]: 脚注番号をクリックすると、対応する脚注にジャンプできます。

## 名前付き脚注

Markdown は John Gruber によって作られました[^gruber]。その後、多くの拡張記法が登場しました[^extensions]。

[^gruber]: John Gruber は Daring Fireball の著者で、Markdown の生みの親です。
[^extensions]: GitHub Flavored Markdown（GFM）、CommonMark、markdown-it などが代表的な拡張仕様です。

## 長い脚注

SkimDown のレンダリングパイプラインは複数のステップで構成されています[^pipeline]。

[^pipeline]: レンダリングパイプラインの詳細:

    1. Markdown テキストを markdown-it でパースして HTML に変換
    2. DOMPurify で HTML をサニタイズ
    3. タスクリストのチェックボックスを正規化
    4. リンクと画像のパスを解決
    5. テーブルをスクロール可能なラッパーで囲む
    6. Mermaid ブロックをダイアグラムとしてレンダリング
    7. コードブロックにツールバー（言語ラベル + コピーボタン）を追加
    8. KaTeX で数式を描画

    このように、複数のポストプロセッシングを行っています。

## インライン脚注

インライン脚注も使えます^[これはインライン脚注です。定義を別の場所に書く必要がありません。]。

もう一つの例^[SkimDown は読む専用のビューアーなので、Markdown の編集機能は持っていません。]。

## 複数の参照

同じ脚注を複数の場所から参照することもできます。SkimDown[^1] は macOS 向けのアプリです。markdown-it[^1] を使って Markdown を描画します。
