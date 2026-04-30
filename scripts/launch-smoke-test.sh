#!/bin/sh
set -eu

APP_PATH="${1:-build/DerivedData/Build/Products/Debug/SkimDown.app}"
BUNDLE_ID="dev.jp27.SkimDown"

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
sleep 1

open -n "$APP_PATH"
sleep 2
osascript -e "tell application id \"$BUNDLE_ID\" to activate"
sleep 1

FRONT_APP="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')"
if [ "$FRONT_APP" != "SkimDown" ]; then
  echo "SkimDown is not frontmost; frontmost app is: $FRONT_APP" >&2
  exit 1
fi

ONSCREEN_COUNT="$(swift -e 'import CoreGraphics; let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []; print(windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "SkimDown" && (($0[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double ?? 0) > 100 && (($0[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double ?? 0) > 100 }.count)')"
if [ "$ONSCREEN_COUNT" -lt 1 ]; then
  echo "No on-screen SkimDown window was reported by CoreGraphics." >&2
  exit 1
fi

test -f "$APP_PATH/Contents/Resources/SkimDown.icns"
test -d "$APP_PATH/Contents/Resources/Web"

echo "SkimDown launch smoke test passed."

