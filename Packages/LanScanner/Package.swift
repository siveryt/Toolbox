// swift-tools-version:5.5
// LanScanner, kept in this repository for Toolbox's LAN Scanner (see README.md).

import PackageDescription

let package = Package(
    name: "LanScanner",
    products: [
        .library(
            name: "LanScanner",
            targets: ["LanScanner"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LanScanner",
            dependencies: ["LanScanInternal"]
        ),
        .target(
            name: "LanScanInternal",
            dependencies: []
        ),
    ]
)
