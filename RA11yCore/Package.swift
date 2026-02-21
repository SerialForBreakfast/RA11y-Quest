// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RA11yCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RA11yCore",
            targets: ["RA11yCore"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RA11yCore"
        ),
        .testTarget(
            name: "RA11yCoreTests",
            dependencies: ["RA11yCore"]
        ),
    ]
)
