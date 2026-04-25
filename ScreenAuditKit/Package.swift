// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScreenAuditKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "ScreenAuditKit",
            targets: ["ScreenAuditKit"]
        ),
        .executable(
            name: "screenaudit",
            targets: ["screenaudit"]
        ),
    ],
    targets: [
        .target(
            name: "ScreenAuditKit"
        ),
        .executableTarget(
            name: "screenaudit",
            dependencies: ["ScreenAuditKit"]
        ),
        .testTarget(
            name: "ScreenAuditKitTests",
            dependencies: ["ScreenAuditKit"],
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "ScreenAuditCLITests",
            dependencies: ["ScreenAuditKit"]
        ),
    ]
)
