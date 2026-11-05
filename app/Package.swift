// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacOSStorageOptimiser",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacOSStorageOptimiser", targets: ["MacOSStorageOptimiser"])
    ],
    targets: [
        .executableTarget(
            name: "MacOSStorageOptimiser",
            path: "Sources/MacOSStorageOptimiser"
        ),
        .testTarget(
            name: "MacOSStorageOptimiserTests",
            dependencies: ["MacOSStorageOptimiser"],
            path: "Tests/MacOSStorageOptimiserTests"
        )
    ]
)
