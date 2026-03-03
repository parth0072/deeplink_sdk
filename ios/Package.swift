// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeeplinkSDK",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(name: "DeeplinkSDK", targets: ["DeeplinkSDK"]),
    ],
    targets: [
        .target(
            name: "DeeplinkSDK",
            path: "Sources/DeeplinkSDK"
        ),
        .testTarget(
            name: "DeeplinkSDKTests",
            dependencies: ["DeeplinkSDK"],
            path: "Tests/DeeplinkSDKTests"
        ),
    ]
)
