#!/usr/bin/env bash
# Release both iOS and Android SDKs.
# 1. Builds XCFramework + AAR
# 2. Creates GitHub Releases on distribution repos
# 3. Updates Package.swift checksum in deeplink-ios-sdk
# 4. Commits AAR to deeplink-android-sdk
#
# Usage: ./sdk/release.sh <version>
#   e.g.: ./sdk/release.sh 1.0.2
#
# Prerequisites:
#   - gh CLI authenticated (gh auth status)
#   - Xcode + Android SDK installed
#   - Both distribution repos cloned:
#       iOS:     ~/Desktop/deeplink-ios-sdk
#       Android: ~/Desktop/deeplink-android-sdk

set -euo pipefail

VERSION="${1:?Usage: ./sdk/release.sh <version>}"
TAG="v$VERSION"

IOS_SRC_DIR="$(cd "$(dirname "$0")/ios" && pwd)"
ANDROID_SRC_DIR="$(cd "$(dirname "$0")/android" && pwd)"
IOS_DIST_REPO=~/Desktop/deeplink-ios-sdk
ANDROID_DIST_REPO=~/Desktop/deeplink-android-sdk
IOS_GITHUB_REPO="parth0072/deeplink-ios-sdk"
ANDROID_GITHUB_REPO="parth0072/deeplink-android-sdk"

echo "══════════════════════════════════════════"
echo "  Deeplink SDK Release — $TAG"
echo "══════════════════════════════════════════"

# ── Build iOS ────────────────────────────────
echo ""
echo "── iOS: building XCFramework ──"
(cd "$IOS_SRC_DIR" && bash scripts/build_xcframework.sh "$VERSION")

IOS_ZIP="$IOS_SRC_DIR/dist/DeeplinkSDK.xcframework.zip"
IOS_CHECKSUM=$(cat "$IOS_SRC_DIR/dist/DeeplinkSDK.xcframework.zip.checksum")
IOS_RELEASE_URL="https://github.com/$IOS_GITHUB_REPO/releases/download/$TAG/DeeplinkSDK.xcframework.zip"

# ── Build Android ─────────────────────────────
echo ""
echo "── Android: building AAR ──"
(cd "$ANDROID_SRC_DIR" && bash scripts/build_aar.sh "$VERSION")
ANDROID_AAR="$ANDROID_SRC_DIR/dist/deeplink-sdk-${VERSION}.aar"

# ── iOS distribution repo ────────────────────
echo ""
echo "── iOS: updating distribution repo ──"
cd "$IOS_DIST_REPO"

# Overwrite Package.swift with binary target
cat > Package.swift <<SWIFT
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeeplinkSDK",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(name: "DeeplinkSDK", targets: ["DeeplinkSDK"]),
    ],
    targets: [
        .binaryTarget(
            name: "DeeplinkSDK",
            url: "$IOS_RELEASE_URL",
            checksum: "$IOS_CHECKSUM"
        ),
    ]
)
SWIFT

# Remove source (no longer shipped here)
rm -rf Sources

git add -A
git commit -m "release: $TAG — binary XCFramework distribution"
git tag "$TAG"

# ── Android distribution repo ─────────────────
echo ""
echo "── Android: updating distribution repo ──"
cd "$ANDROID_DIST_REPO"

# Remove Gradle source, keep only the AAR + README
find . -not -name '.git' -not -name 'README.md' -not -name '.' \
  -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

mkdir -p libs
cp "$ANDROID_AAR" "libs/deeplink-sdk.aar"

cat > build.gradle <<GRADLE
// Deeplink Android SDK — binary distribution
// Source: https://github.com/parth0072/deeplink_sdk
//
// To integrate:
//   1. Copy libs/deeplink-sdk.aar into your app's libs/ folder
//   2. In your app build.gradle:
//        implementation files('libs/deeplink-sdk.aar')
//        implementation 'com.android.installreferrer:installreferrer:2.2'
GRADLE

git add -A
git commit -m "release: $TAG — binary AAR distribution"
git tag "$TAG"

# ── Create GitHub Releases + push ────────────
echo ""
echo "── Pushing and creating GitHub Releases ──"

cd "$IOS_DIST_REPO"
git push origin main
git push origin "$TAG"
gh release create "$TAG" "$IOS_ZIP" \
  --repo "$IOS_GITHUB_REPO" \
  --title "DeeplinkSDK $TAG" \
  --notes "Binary XCFramework release. Integrate via Swift Package Manager." \
  --latest

cd "$ANDROID_DIST_REPO"
git push origin main
git push origin "$TAG"
gh release create "$TAG" "$ANDROID_AAR" \
  --repo "$ANDROID_GITHUB_REPO" \
  --title "DeeplinkSDK Android $TAG" \
  --notes "Binary AAR release. Copy \`libs/deeplink-sdk.aar\` into your project's \`libs/\` folder." \
  --latest

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ Released $TAG"
echo "  iOS SPM URL: $IOS_RELEASE_URL"
echo "  iOS checksum: $IOS_CHECKSUM"
echo "══════════════════════════════════════════"
