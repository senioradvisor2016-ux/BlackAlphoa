// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AlphaJunoPG300",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AlphaJunoCore", targets: ["AlphaJunoCore"]),
        .library(name: "AlphaJunoMIDI", targets: ["AlphaJunoMIDI"]),
        .executable(name: "BlackAlphaJunoEditor", targets: ["BlackAlphaJunoEditorApp"])
    ],
    targets: [
        .target(
            name: "AlphaJunoCore",
            path: "Sources/AlphaJunoCore"
        ),
        .target(
            name: "AlphaJunoMIDI",
            dependencies: ["AlphaJunoCore"],
            path: "Sources/AlphaJunoMIDI"
        ),
        .executableTarget(
            name: "BlackAlphaJunoEditorApp",
            dependencies: ["AlphaJunoCore", "AlphaJunoMIDI"],
            path: "Sources/AlphaJunoPG300App"
        ),
        .testTarget(
            name: "AlphaJunoCoreTests",
            dependencies: ["AlphaJunoCore"],
            path: "Tests/AlphaJunoCoreTests",
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)

