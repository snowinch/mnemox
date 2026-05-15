// swift-tools-version: 5.9
// Mnemox — local macOS coding agent (Phase 1: Swift stdlib + Foundation only).

import PackageDescription

let package = Package(
    name: "mnemox",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "mnemox", targets: ["mnemox"]),
    ],
    targets: [
        .executableTarget(
            name: "mnemox",
            path: "Sources/mnemox"
        ),
        .testTarget(
            name: "mnemoxTests",
            dependencies: ["mnemox"],
            path: "Tests/mnemoxTests"
        ),
    ]
)
