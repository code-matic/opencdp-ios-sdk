// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OpenCDP",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "OpenCDP", targets: ["OpenCDP"]),
        .library(name: "OpenCDPPushExtension", targets: ["OpenCDPPushExtension"]),
    ],
    targets: [
        .target(name: "OpenCDP"),
        .target(
            name: "OpenCDPPushExtension",
            dependencies: ["OpenCDP"],
            path: "Sources/OpenCDPPushExtension"
        ),
        .testTarget(name: "OpenCDPTests", dependencies: ["OpenCDP"]),
    ]
)
