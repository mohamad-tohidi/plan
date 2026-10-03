// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhiteboardScrumPlanner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "WhiteboardScrumPlanner",
            path: "Sources/WhiteboardScrumPlanner"
        )
    ]
)