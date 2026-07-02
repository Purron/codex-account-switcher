#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Agent Status Indicator.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/swiftc \
  "$ROOT_DIR/AgentStatusIndicator.swift" \
  -o "$MACOS_DIR/AgentStatusIndicator" \
  -framework AppKit

cp "$ROOT_DIR/resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/resources/StatusIcon.png" "$RESOURCES_DIR/StatusIcon.png"
if [[ -f "$ROOT_DIR/resources/CodexTabIcon.svg" ]]; then
  cp "$ROOT_DIR/resources/CodexTabIcon.svg" "$RESOURCES_DIR/CodexTabIcon.svg"
fi
if [[ -f "$ROOT_DIR/resources/ClaudeTabIcon.svg" ]]; then
  cp "$ROOT_DIR/resources/ClaudeTabIcon.svg" "$RESOURCES_DIR/ClaudeTabIcon.svg"
fi
cp "$ROOT_DIR/agent-status-indicator.sh" "$RESOURCES_DIR/agent-status-indicator.sh"
chmod +x "$RESOURCES_DIR/agent-status-indicator.sh"

printf 'Built: %s\n' "$APP_DIR"
