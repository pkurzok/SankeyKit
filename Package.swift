// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SankeyKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SankeyKit", targets: ["SankeyKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(name: "SankeyKit"),
        .testTarget(name: "SankeyKitTests", dependencies: ["SankeyKit"])
    ]
)
