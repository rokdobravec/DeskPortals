// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "DeskPortals",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DeskPortals",
            path: "Sources/DeskPortals"
        )
    ]
)
