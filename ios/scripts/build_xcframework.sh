#!/usr/bin/env bash
# Build DeeplinkSDK.xcframework from SPM source and zip it for distribution.
# Usage: ./scripts/build_xcframework.sh [version]
# Output: dist/DeeplinkSDK.xcframework.zip + dist/DeeplinkSDK.xcframework.zip.checksum

set -euo pipefail

VERSION="${1:-dev}"
SCHEME="DeeplinkSDK"
BUILD_DIR="$(pwd)/.build"
DIST_DIR="$(pwd)/dist"

echo "▶ Building DeeplinkSDK XCFramework — version $VERSION"
rm -rf "$BUILD_DIR/dd-ios" "$BUILD_DIR/dd-sim" "$BUILD_DIR/fw-ios" "$BUILD_DIR/fw-sim" \
       "$BUILD_DIR/libDeeplinkSDK-ios.a" "$BUILD_DIR/libDeeplinkSDK-sim.a"
mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/DeeplinkSDK.xcframework" "$DIST_DIR/DeeplinkSDK.xcframework.zip"

# ── Build for device ──────────────────────────────────────────────
echo "▶ Building for iOS device..."
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$BUILD_DIR/dd-ios" \
  -configuration Release \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  -quiet 2>&1 | grep -v "IDERunDestination" || true

# ── Build for simulator ───────────────────────────────────────────
echo "▶ Building for iOS Simulator..."
xcodebuild build \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$BUILD_DIR/dd-sim" \
  -configuration Release \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  -quiet 2>&1 | grep -v "IDERunDestination" || true

IOS_PROD="$BUILD_DIR/dd-ios/Build/Products/Release-iphoneos"
SIM_PROD="$BUILD_DIR/dd-sim/Build/Products/Release-iphonesimulator"

# ── Create static libraries ───────────────────────────────────────
echo "▶ Linking static libraries..."
libtool -static -o "$BUILD_DIR/libDeeplinkSDK-ios.a" "$IOS_PROD/DeeplinkSDK.o"
libtool -static -o "$BUILD_DIR/libDeeplinkSDK-sim.a" "$SIM_PROD/DeeplinkSDK.o"

# ── Create framework structures ───────────────────────────────────
make_framework() {
  local FWDIR="$1"
  local LIB="$2"
  local MODDIR="$3"

  mkdir -p "$FWDIR/Modules/DeeplinkSDK.swiftmodule" "$FWDIR/Headers"
  cp "$LIB" "$FWDIR/DeeplinkSDK"
  cp "$MODDIR"/*.swiftinterface "$FWDIR/Modules/DeeplinkSDK.swiftmodule/" 2>/dev/null || true
  cp "$MODDIR"/*.swiftmodule    "$FWDIR/Modules/DeeplinkSDK.swiftmodule/" 2>/dev/null || true
  cp "$MODDIR"/*.swiftdoc       "$FWDIR/Modules/DeeplinkSDK.swiftmodule/" 2>/dev/null || true

  cat > "$FWDIR/Modules/module.modulemap" <<'EOF'
framework module DeeplinkSDK {
  header "DeeplinkSDK-Swift.h"
  requires objc
}
EOF

  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleIdentifier string com.deeplink.DeeplinkSDK" \
    -c "Add :CFBundleName string DeeplinkSDK" \
    -c "Add :CFBundlePackageType string FMWK" \
    -c "Add :CFBundleShortVersionString string $VERSION" \
    -c "Add :CFBundleVersion string 1" \
    -c "Add :MinimumOSVersion string 14.0" \
    "$FWDIR/Info.plist" > /dev/null 2>&1
}

echo "▶ Assembling frameworks..."
make_framework \
  "$BUILD_DIR/fw-ios/DeeplinkSDK.framework" \
  "$BUILD_DIR/libDeeplinkSDK-ios.a" \
  "$IOS_PROD/DeeplinkSDK.swiftmodule"

make_framework \
  "$BUILD_DIR/fw-sim/DeeplinkSDK.framework" \
  "$BUILD_DIR/libDeeplinkSDK-sim.a" \
  "$SIM_PROD/DeeplinkSDK.swiftmodule"

# ── Create XCFramework ────────────────────────────────────────────
echo "▶ Creating XCFramework..."
xcodebuild -create-xcframework \
  -framework "$BUILD_DIR/fw-ios/DeeplinkSDK.framework" \
  -framework "$BUILD_DIR/fw-sim/DeeplinkSDK.framework" \
  -output "$DIST_DIR/DeeplinkSDK.xcframework"

# ── Zip + checksum ─────────────────────────────────────────────────
echo "▶ Zipping..."
(cd "$DIST_DIR" && zip -r "DeeplinkSDK.xcframework.zip" "DeeplinkSDK.xcframework" --quiet)
rm -rf "$DIST_DIR/DeeplinkSDK.xcframework"

CHECKSUM=$(swift package compute-checksum "$DIST_DIR/DeeplinkSDK.xcframework.zip")
echo "$CHECKSUM" > "$DIST_DIR/DeeplinkSDK.xcframework.zip.checksum"

echo "✅ Done"
echo "   Zip:      $DIST_DIR/DeeplinkSDK.xcframework.zip"
echo "   Size:     $(du -sh "$DIST_DIR/DeeplinkSDK.xcframework.zip" | cut -f1)"
echo "   Checksum: $CHECKSUM"
