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
        // Pre-built XCFramework — rebuild with scripts/build-xcframework.sh
        .binaryTarget(
            name: "DeeplinkSDK",
            path: "DeeplinkSDK.xcframework"
        ),
    ]
)
