// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sonar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Sonar",
            path: "Sources/Sonar"
        )
    ]
)
