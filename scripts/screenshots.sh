#!/usr/bin/env bash
# Captures the README screenshot gallery from a booted iPhone 17 simulator.
# Uses the launch-argument scenarios in ios/Kollektiv/App/ScreenshotScenario.swift.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="com.jenskristian.kollektiv"
OUT="$ROOT/docs/screenshots"
mkdir -p "$OUT"

echo "==> Building"
cd "$ROOT/ios"
xcodegen generate
xcodebuild -project Kollektiv.xcodeproj -scheme Kollektiv \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/kdd build | tail -1

APP="/tmp/kdd/Build/Products/Debug-iphonesimulator/Kollektiv.app"
xcrun simctl install booted "$APP"

echo "==> Clean status bar"
xcrun simctl status_bar booted override --time 9:41 --batteryState charged \
  --batteryLevel 100 --wifiBars 3 --cellularBars 4

shot() {
  local name="$1"; shift
  echo "==> $name"
  xcrun simctl terminate booted "$APP_ID" 2>/dev/null || true
  xcrun simctl launch booted "$APP_ID" "$@" >/dev/null
  sleep 3
  xcrun simctl io booted screenshot --type=png "$OUT/$name.png" >/dev/null
  sips --resampleWidth 600 "$OUT/$name.png" >/dev/null
}

shot house              -tab house -person kristian
shot chat-cover-request -scenario journeyA-pending  -tab chat  -person sam
shot chat-accepted      -scenario journeyA-accepted -tab chat  -person sam
shot chat-cook          -scenario journeyC          -tab chat  -person kristian
shot meals              -tab house -sheet today -person kristian
shot chores             -scenario journeyA-accepted -tab house -chores -person sam
shot week               -scenario journeyA-accepted -tab week  -person kristian
shot house-pending      -scenario journeyA-pending  -tab house -person kristian

echo "==> Reset"
xcrun simctl status_bar booted clear
xcrun simctl terminate booted "$APP_ID" 2>/dev/null || true
xcrun simctl launch booted "$APP_ID" >/dev/null
ls -la "$OUT"
