// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Macmd",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Macmd",
            path: "Sources/Macmd",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "MacmdTests",
            dependencies: ["Macmd"],
            path: "Tests/MacmdTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
