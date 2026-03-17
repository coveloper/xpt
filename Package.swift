// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "xpt",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "xptCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/xptCore"
        ),
        .executableTarget(
            name: "xpt",
            dependencies: ["xptCore"],
            path: "Sources/xpt"
        ),
        .testTarget(
            name: "xptTests",
            dependencies: ["xptCore"],
            path: "Tests/xptTests"
        ),
    ]
)
