#!/bin/sh
set -eu

APP_PATH="${1:-build/DerivedData/Build/Products/Debug/SkimDown.app}"
TARGET_PATH="${2:-.}"

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

APP_PATH="$(resolve_path "$APP_PATH")"
TARGET_PATH="$(resolve_path "$TARGET_PATH")"
EXECUTABLE="$APP_PATH/Contents/MacOS/SkimDown"
TMP_DIR="$(mktemp -d /tmp/skimdown-local-cli.XXXXXX)"
LOCAL_COMMAND="$TMP_DIR/skimdown"
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

echo "Launching fixed local SkimDown build through a temporary skimdown command:"
echo "  $LOCAL_COMMAND \"$TARGET_PATH\""
echo
echo "This does not modify /Applications/SkimDown.app or /usr/local/bin/skimdown."
echo "Quit SkimDown, or press Ctrl-C here, to finish this local check."
echo

"$LOCAL_COMMAND" "$TARGET_PATH" &
APP_PID="$!"
wait "$APP_PID"
