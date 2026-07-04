#!/bin/sh
set -eu

APP_PATH="${1:-build/DerivedData/Build/Products/Debug/SkimDown.app}"
TARGET_PATH="${2:-samples/en/extended/math.md}"
FAILURE_MARKER="SkimDownPreviewResourceFailure"
TIMEOUT_SECONDS="${CLI_LAUNCH_TIMEOUT_SECONDS:-30}"

resolve_path() {
  path="$1"
  if [ ! -e "$path" ]; then
    printf '%s\n' "$path"
    return
  fi

  if [ -d "$path" ]; then
    (cd "$path" && pwd -P)
    return
  fi

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  printf '%s/%s\n' "$(cd "$dir" && pwd -P)" "$base"
}

window_count_for_pid() {
  swift -e 'import CoreGraphics
import Foundation
func int32Value(_ value: Any?) -> Int32? {
    if let number = value as? NSNumber { return number.int32Value }
    if let int = value as? Int { return Int32(int) }
    return nil
}
let pid = Int32(CommandLine.arguments[1])!
let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
let count = windows.filter { window in
    int32Value(window[kCGWindowOwnerPID as String]) == pid &&
    (((window[kCGWindowBounds as String] as? [String: Any])?["Width"] as? Double) ?? 0) > 100 &&
    (((window[kCGWindowBounds as String] as? [String: Any])?["Height"] as? Double) ?? 0) > 100
}.count
print(count)' "$1"
}

APP_PATH="$(resolve_path "$APP_PATH")"
TARGET_PATH="$(resolve_path "$TARGET_PATH")"
EXECUTABLE="$APP_PATH/Contents/MacOS/SkimDown"
TMP_DIR="$(mktemp -d /tmp/skimdown-cli-smoke.XXXXXX)"
LOCAL_COMMAND="$TMP_DIR/skimdown"
STDOUT_LOG="$TMP_DIR/stdout.log"
STDERR_LOG="$TMP_DIR/stderr.log"
APP_PID=""

cleanup() {
  if [ -n "$APP_PID" ] && ps -p "$APP_PID" -o pid= >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

if [ ! -d "$APP_PATH" ]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if [ ! -x "$EXECUTABLE" ]; then
  echo "SkimDown executable not found: $EXECUTABLE" >&2
  exit 1
fi

if [ ! -e "$TARGET_PATH" ]; then
  echo "Target path not found: $TARGET_PATH" >&2
  exit 1
fi

ln -s "$EXECUTABLE" "$LOCAL_COMMAND"
"$LOCAL_COMMAND" "$TARGET_PATH" >"$STDOUT_LOG" 2>"$STDERR_LOG" &
APP_PID="$!"

START_TIME="$(date +%s)"
while :; do
  NOW="$(date +%s)"
  ELAPSED="$((NOW - START_TIME))"
  if [ "$ELAPSED" -ge "$TIMEOUT_SECONDS" ]; then
    echo "No on-screen SkimDown window was reported for PID $APP_PID within ${TIMEOUT_SECONDS}s." >&2
    exit 1
  fi

  if ! ps -p "$APP_PID" -o pid= >/dev/null 2>&1; then
    echo "SkimDown exited during CLI symlink launch." >&2
    echo "--- stdout ---" >&2
    cat "$STDOUT_LOG" >&2 || true
    echo "--- stderr ---" >&2
    cat "$STDERR_LOG" >&2 || true
    exit 1
  fi

  if [ "$(window_count_for_pid "$APP_PID")" -gt 0 ]; then
    break
  fi

  sleep 1
done

sleep 2

if grep -F "$FAILURE_MARKER" "$STDOUT_LOG" "$STDERR_LOG" >/dev/null 2>&1; then
  echo "Preview resource failure was reported during CLI symlink launch." >&2
  echo "--- stdout ---" >&2
  cat "$STDOUT_LOG" >&2 || true
  echo "--- stderr ---" >&2
  cat "$STDERR_LOG" >&2 || true
  exit 1
fi

echo "SkimDown CLI symlink smoke test passed."
