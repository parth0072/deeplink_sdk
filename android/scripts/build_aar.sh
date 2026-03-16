#!/usr/bin/env bash
# Build DeeplinkSDK release AAR from Gradle source.
# Usage: ./scripts/build_aar.sh [version]
#   version defaults to "dev"
# Output: dist/deeplink-sdk-{version}.aar

set -euo pipefail

VERSION="${1:-dev}"
DIST_DIR="$(pwd)/dist"

echo "▶ Building DeeplinkSDK AAR — version $VERSION"

mkdir -p "$DIST_DIR"

./gradlew :deeplinkSDK:assembleRelease --quiet

AAR_SRC="deeplinkSDK/build/outputs/aar/deeplinkSDK-release.aar"
AAR_OUT="$DIST_DIR/deeplink-sdk-${VERSION}.aar"

cp "$AAR_SRC" "$AAR_OUT"

echo "✅ Done"
echo "   AAR: $AAR_OUT"
