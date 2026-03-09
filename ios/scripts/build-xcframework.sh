#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# build-xcframework.sh
# Compiles DeeplinkSDK source into a universal XCFramework.
# Output: ios/DeeplinkSDK.xcframework  (committed to repo)
#         ios/DeeplinkSDK.xcframework.zip + checksum (for SPM url release)
#
# Usage:
#   cd sdk/ios && bash scripts/build-xcframework.sh
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCHEME="DeeplinkSDK"
DERIVED_DATA="$(mktemp -d)/DerivedData"
OUT_DIR="$(cd "$(dirname "$0")/.." && pwd)"   # sdk/ios/
ARCHIVE_FW_PATH="usr/local/lib"  # SPM dynamic libs install here

echo "▶ Cleaning previous build..."
rm -rf "$OUT_DIR/DeeplinkSDK.xcframework" "$OUT_DIR/archives"

mkdir -p "$OUT_DIR/archives/ios-device"
mkdir -p "$OUT_DIR/archives/ios-simulator"

# ── Helper: copy .swiftmodule directory into a framework Modules/ dir ──
inject_modules() {
  local archive_path="$1"
  local sdk_suffix="$2"   # e.g. "iphoneos" or "iphonesimulator"
  local fw="$archive_path/Products/$ARCHIVE_FW_PATH/$SCHEME.framework"
  local modules_src="$DERIVED_DATA/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath/Release-$sdk_suffix/$SCHEME.swiftmodule"
  local modules_dst="$fw/Modules/$SCHEME.swiftmodule"

  if [ -d "$modules_src" ]; then
    mkdir -p "$fw/Modules"
    cp -R "$modules_src" "$modules_dst"
    echo "   ✓ Swift modules injected from $sdk_suffix"
  else
    echo "   ⚠ Swift modules not found at $modules_src — skipping"
  fi
}

echo "▶ Archiving for iOS device (arm64)..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$OUT_DIR/archives/ios-device/$SCHEME.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
  -quiet

inject_modules "$OUT_DIR/archives/ios-device/$SCHEME.xcarchive" "iphoneos"

echo "▶ Archiving for iOS Simulator (arm64 + x86_64)..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$OUT_DIR/archives/ios-simulator/$SCHEME.xcarchive" \
  -derivedDataPath "$DERIVED_DATA" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
  -quiet

inject_modules "$OUT_DIR/archives/ios-simulator/$SCHEME.xcarchive" "iphonesimulator"

echo "▶ Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$OUT_DIR/archives/ios-device/$SCHEME.xcarchive/Products/$ARCHIVE_FW_PATH/$SCHEME.framework" \
  -framework "$OUT_DIR/archives/ios-simulator/$SCHEME.xcarchive/Products/$ARCHIVE_FW_PATH/$SCHEME.framework" \
  -output "$OUT_DIR/$SCHEME.xcframework"

echo "▶ Cleaning up archives..."
rm -rf "$OUT_DIR/archives" "$DERIVED_DATA"

echo "▶ Zipping for SPM release..."
cd "$OUT_DIR"
zip -r "$SCHEME.xcframework.zip" "$SCHEME.xcframework" -q
CHECKSUM=$(swift package compute-checksum "$SCHEME.xcframework.zip" 2>/dev/null || shasum -a 256 "$SCHEME.xcframework.zip" | awk '{print $1}')
echo "$CHECKSUM" > "$SCHEME.xcframework.zip.sha256"

echo ""
echo "✅ Done!"
echo "   XCFramework : $OUT_DIR/$SCHEME.xcframework"
echo "   Zip         : $OUT_DIR/$SCHEME.xcframework.zip"
echo "   SHA256      : $CHECKSUM"
echo ""
echo "For local SPM (path):"
echo "  .binaryTarget(name: \"$SCHEME\", path: \"./DeeplinkSDK.xcframework\")"
echo ""
echo "For hosted SPM (url + checksum) — upload the .zip to a GitHub Release first:"
echo "  .binaryTarget(name: \"$SCHEME\","
echo "                url: \"https://github.com/parth0072/deeplink_sdk/releases/download/vX.Y.Z/$SCHEME.xcframework.zip\","
echo "                checksum: \"$CHECKSUM\")"
