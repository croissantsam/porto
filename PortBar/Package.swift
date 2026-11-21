// swift-tools-version: 5.9
//
// Porto — a macOS menu bar app that lists the ports currently open
// (TCP listeners) and lets you close them with a click.
//

import PackageDescription

let package = Package(
    name: "Porto",
    targets: [
        .executableTarget(name: "Porto")
    ]
)
