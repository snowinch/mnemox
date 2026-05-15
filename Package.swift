// swift-tools-version: 5.9
// Mnemox — local macOS coding agent.

import PackageDescription

let package = Package(
    name: "mnemox",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "mnemox", targets: ["mnemox"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MrKai77/Luminare", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "mnemox",
            dependencies: ["Luminare"],
            path: "Sources/mnemox",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Support/MnemoxEmbeddedInfo.plist",
                ])
            ]
        ),
        .testTarget(
            name: "mnemoxTests",
            dependencies: ["mnemox"],
            path: "Tests/mnemoxTests"
        ),
    ]
)
