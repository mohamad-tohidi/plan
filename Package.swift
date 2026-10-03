// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "plan",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "plan",
            path: "Sources/plan"
        )
    ]
)