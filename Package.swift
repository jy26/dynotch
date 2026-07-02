// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dynotch",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "dynotch",
            path: "Sources/dynotch"
        )
    ]
)
