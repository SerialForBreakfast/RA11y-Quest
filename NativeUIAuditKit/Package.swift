// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NativeUIAuditKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "NativeUIAuditKit",
            targets: ["NativeUIAuditKit"]
        )
    ],
    targets: [
        .target(
            name: "NativeUIAuditKit",
            path: "Sources/NativeUIAuditKit"
        ),
        .testTarget(
            name: "NativeUIAuditKitTests",
            dependencies: ["NativeUIAuditKit"],
            path: "Tests/NativeUIAuditKitTests"
        )
    ]
)
