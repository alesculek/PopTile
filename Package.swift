// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PopTile",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PopTileCore",
            path: "Sources/PopTile",
            exclude: ["main.swift", "Info.plist"]
        ),
        .executableTarget(
            name: "PopTile",
            dependencies: ["PopTileCore"],
            path: "Sources/PopTileApp"
        ),
        .testTarget(
            name: "PopTileTests",
            dependencies: ["PopTileCore"],
            path: "Tests/PopTileTests"
        )
    ]
)
