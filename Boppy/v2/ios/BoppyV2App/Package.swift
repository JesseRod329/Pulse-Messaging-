// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BoppyV2Core",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "BoppyV2Core", targets: ["BoppyV2Core"])
    ],
    targets: [
        .target(
            name: "BoppyV2Core",
            path: "Sources/Core"
        ),
        .testTarget(
            name: "BoppyV2CoreTests",
            dependencies: ["BoppyV2Core"],
            path: "Tests/CoreTests"
        )
    ]
)
