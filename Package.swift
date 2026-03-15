// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OracleSystem",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "oracle", targets: ["OracleOS"]),
        .library(name: "OracleLib", targets: ["OracleLib"])
    ],
    dependencies: [],
    targets: [
        // Library — all runtime code (testable)
        .target(
            name: "OracleLib",
            path: "oracle/Sources/OracleLib",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        // Executable — thin entry point
        .executableTarget(
            name: "OracleOS",
            dependencies: ["OracleLib"],
            path: "oracle/Sources/OracleOS"
        ),
        // Tests
        .testTarget(
            name: "OracleTests",
            dependencies: ["OracleLib"],
            path: "oracle/Tests/OracleTests"
        )
    ]
)
