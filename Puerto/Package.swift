// swift-tools-version: 5.9
//
// Puerto — a macOS menu bar app that lists the ports currently open
// (TCP listeners) and lets you close them with a click.
//

import PackageDescription

let package = Package(
    name: "Puerto",
    targets: [
        .executableTarget(name: "Puerto"),
        .testTarget(name: "PuertoTests", dependencies: ["Puerto"]),
    ]
)
