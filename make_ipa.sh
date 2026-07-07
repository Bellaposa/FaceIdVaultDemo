#!/usr/bin/env bash
# Build an UNSIGNED device .app and package it into an .ipa that Sideloadly can
# take, inject the dylib into, sign with your Apple ID, and install — no
# jailbreak required.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

BUILD_DIR="$HERE/build-device"
APP_NAME="FaceIDVaultDemo"

echo "== building CLEAN unsigned device .app (no embedded bypass) =="
# Override SWIFT_ACTIVE_COMPILATION_CONDITIONS to drop EMBEDDED_BYPASS, so the
# shipped IPA has no in-app toggle. The ONLY way to bypass it is external
# injection (Sideloadly) — exactly the article's story.
xcodebuild -project FaceIDVaultDemo.xcodeproj -scheme "$APP_NAME" \
  -sdk iphoneos -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="" \
  -quiet

APP="$BUILD_DIR/Build/Products/Release-iphoneos/$APP_NAME.app"
if [ ! -d "$APP" ]; then
  echo "!! app not found at $APP"; exit 1
fi

echo "== packaging IPA =="
rm -rf "$HERE/ipa" && mkdir -p "$HERE/ipa/Payload"
cp -R "$APP" "$HERE/ipa/Payload/"
( cd "$HERE/ipa" && zip -qry "$HERE/ipa/$APP_NAME.ipa" Payload )
rm -rf "$HERE/ipa/Payload"

echo "[*] IPA ready: $HERE/ipa/$APP_NAME.ipa"
echo "[*] dylib to inject: run ./inject/build_dylib_device.sh first"
