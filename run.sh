#!/usr/bin/env bash
# End-to-end demo driver:
#   1. build the app for the simulator
#   2. build the bypass dylib
#   3. boot a simulator, enroll Face ID
#   4. install + launch the app with the dylib injected
#
# Usage:
#   ./run.sh            # launch WITH the bypass injected
#   ./run.sh clean      # launch WITHOUT injection (baseline)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

BUNDLE_ID="com.bellaposa.faceidvaultdemo"
DEVICE_NAME="iPhone 16 Pro"
DYLIB="$HERE/inject/libFaceIDBypass.dylib"
APP="$HERE/build/Build/Products/Debug-iphonesimulator/FaceIDVaultDemo.app"

MODE="${1:-inject}"

echo "== building app =="
xcodebuild -project FaceIDVaultDemo.xcodeproj -scheme FaceIDVaultDemo \
  -sdk iphonesimulator -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath build -quiet

echo "== building dylib =="
./inject/build_dylib.sh >/dev/null

echo "== picking a simulator =="
UDID="$(xcrun simctl list devices available | awk -v n="$DEVICE_NAME" '$0 ~ n {match($0,/\(([-0-9A-F]+)\)/,a); if(a[1]){print a[1]; exit}}')"
if [ -z "${UDID:-}" ]; then
  echo "Could not find '$DEVICE_NAME'. Available devices:"
  xcrun simctl list devices available
  exit 1
fi
echo "   using $DEVICE_NAME ($UDID)"

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator || true
xcrun simctl bootstatus "$UDID" -b

echo "== enrolling Face ID =="
xcrun simctl spawn "$UDID" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1 2>/dev/null || true
# The reliable path: enroll via the UI menu is manual; simctl has a helper too.
xcrun simctl ui "$UDID" enroll_biometric 2>/dev/null || \
  echo "   (if not enrolled, use Simulator menu: Features > Face ID > Enrolled)"

echo "== installing app =="
xcrun simctl install "$UDID" "$APP"

echo "== launching ($MODE) =="
if [ "$MODE" = "clean" ]; then
  xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID"
else
  SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$DYLIB" \
    xcrun simctl launch --console-pty "$UDID" "$BUNDLE_ID"
fi
