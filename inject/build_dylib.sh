#!/usr/bin/env bash
# Build the injectable bypass dylib for the iOS Simulator.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/libFaceIDBypass.dylib"
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
ARCH="$(uname -m)"   # arm64 on Apple Silicon, x86_64 on Intel

echo "[*] SDK: $SDK_PATH"
echo "[*] arch: $ARCH"

xcrun --sdk iphonesimulator clang \
  -dynamiclib \
  -arch "$ARCH" \
  -mios-simulator-version-min=17.0 \
  -isysroot "$SDK_PATH" \
  -framework Foundation \
  -framework LocalAuthentication \
  -fobjc-arc \
  -o "$OUT" \
  "$HERE/FaceIDBypass.m"

# Ad-hoc sign so the simulator's dyld will load it.
codesign -f -s - "$OUT"

echo "[*] built: $OUT"
file "$OUT"
