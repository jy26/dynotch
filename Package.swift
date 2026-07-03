// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "dynotch",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Pinned by revision: the fork publishes no tags, and SwiftPM only accepts
        // its unsafeFlags (-fno-objc-arc) from non-version (branch/revision/local)
        // dependencies. Same pin as DockDoor; bump deliberately after testing.
        .package(
            url: "https://github.com/ejbills/mediaremote-adapter.git",
            revision: "cf30c4f1af29b5829d859f088f8dbdf12611a046"   // master HEAD, 2026-06-02
        )
    ],
    targets: [
        .executableTarget(
            name: "dynotch",
            dependencies: [
                .product(name: "MediaRemoteAdapter", package: "mediaremote-adapter")
            ],
            path: "Sources/dynotch"
        )
    ]
)
