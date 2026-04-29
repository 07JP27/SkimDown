# コードブロック

## インラインコード

変数 `count` を使って `for` ループを回します。パス `/usr/local/bin` を確認してください。

## Swift

```swift
import SwiftUI

struct ContentView: View {
    @State private var message = "Hello, SkimDown!"

    var body: some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.largeTitle)
                .foregroundStyle(.primary)

            Button("Tap me") {
                message = "ボタンが押されました 🎉"
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## Python

```python
from pathlib import Path

def scan_markdown_files(root: Path) -> list[Path]:
    """指定ディレクトリ以下の Markdown ファイルを再帰的に検索する"""
    extensions = {".md", ".markdown"}
    return sorted(
        p for p in root.rglob("*")
        if p.suffix.lower() in extensions
        and not p.name.startswith(".")
    )

if __name__ == "__main__":
    files = scan_markdown_files(Path("."))
    for f in files:
        print(f"  📄 {f}")
```

## JavaScript

```javascript
function debounce(fn, delay) {
  let timer = null;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

const handleResize = debounce(() => {
  console.log(`Window size: ${window.innerWidth}x${window.innerHeight}`);
}, 250);

window.addEventListener("resize", handleResize);
```

## TypeScript

```typescript
interface MarkdownFile {
  path: string;
  name: string;
  size: number;
  lastModified: Date;
}

async function loadMarkdown(file: MarkdownFile): Promise<string> {
  const response = await fetch(file.path);
  if (!response.ok) {
    throw new Error(`Failed to load: ${file.name}`);
  }
  return response.text();
}
```

## HTML

```html
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>SkimDown サンプル</title>
  <link rel="stylesheet" href="skimdown.css">
</head>
<body>
  <div id="content">
    <h1>Hello, SkimDown!</h1>
    <p>Markdown ビューアーへようこそ。</p>
  </div>
  <script src="renderer.js"></script>
</body>
</html>
```

## CSS

```css
:root {
  --primary: #0a66d6;
  --bg: #fbfbfd;
  --fg: #20242c;
}

.markdown-body {
  max-width: 980px;
  margin: 0 auto;
  padding: 2rem;
  font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  color: var(--fg);
  background: var(--bg);
}
```

## JSON

```json
{
  "name": "SkimDown",
  "version": "1.0.0",
  "description": "A lightweight Markdown viewer for macOS",
  "features": [
    "Folder-based navigation",
    "Syntax highlighting",
    "Math rendering",
    "Mermaid diagrams"
  ],
  "supported_extensions": [".md", ".markdown"]
}
```

## Shell

```bash
#!/bin/bash
set -euo pipefail

echo "🔨 Building SkimDown..."
make clean && make build

echo "✅ Build succeeded"
echo "🚀 Launching..."
make run
```

## SQL

```sql
SELECT
    f.name AS file_name,
    f.path AS file_path,
    f.size_bytes,
    d.name AS directory
FROM markdown_files f
JOIN directories d ON f.directory_id = d.id
WHERE f.extension IN ('.md', '.markdown')
ORDER BY d.name, f.name;
```

## YAML

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make build
      - name: Test
        run: make test
```

## 言語指定なし

```
これは言語指定なしのコードブロックです。
シンタックスハイライトは適用されません。
プレーンテキストとして表示されます。
```

## diff

```diff
- const oldValue = "removed";
+ const newValue = "added";

  function unchanged() {
-   return false;
+   return true;
  }
```
