// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "oracle-runtime",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "oracle-runtime", targets: ["App"]),
        .library(name: "Core", targets: ["Core"]),
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .target(
            name: "Interface",
            dependencies: ["Core"],
            path: "Sources/Interface"
        ),
        .target(
            name: "MultiAgent",
            dependencies: ["Core"],
            path: "Sources/MultiAgent"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Core", "Interface", "MultiAgent"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "ArchitectureEnforcement",
            dependencies: ["Core", "Interface", "MultiAgent"],
            path: "Tests/ArchitectureEnforcement"
        ),
    ]
)
