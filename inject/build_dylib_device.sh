#!/usr/bin/env bash
# Build the injectable bypass dylib for a REAL DEVICE (arm64, iphoneos).
# This is the one you feed to Sideloadly's "inject dylib" option.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/libFaceIDBypass-device.dylib"
SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"

echo "[*] SDK: $SDK_PATH"

xcrun --sdk iphoneos clang \
  -dynamiclib \
  -arch arm64 \
  -miphoneos-version-min=17.0 \
  -isysroot "$SDK_PATH" \
  -framework Foundation \
  -framework LocalAuthentication \
  -fobjc-arc \
  -install_name "@executable_path/Frameworks/libFaceIDBypass-device.dylib" \
  -o "$OUT" \
  "$HERE/FaceIDBypass.m"

# Ad-hoc sign; Sideloadly will re-sign with your Apple ID during install.
codesign -f -s - "$OUT"

echo "[*] built: $OUT"
file "$OUT"
otool -l "$OUT" | grep -A2 LC_ID_DYLIB | head -6 || true
