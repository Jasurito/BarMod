// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BarMod",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BarModCore"),
        .executableTarget(name: "BarMod", dependencies: ["BarModCore"]),
        .testTarget(name: "BarModCoreTests", dependencies: ["BarModCore"]),
    ]
)
