// swift-tools-version: 6.0
import PackageDescription

// Platform-agnostic core for Nobles Tools: models, networking, menu filtering,
// calendar math and persistence. Foundation-only, so it builds and tests on
// macOS and Linux as well as iOS. SwiftUI lives in the app and widget targets.
let package = Package(
    name: "NoblesKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NoblesKit", targets: ["NoblesKit"]),
    ],
    targets: [
        .target(name: "NoblesKit"),
        .testTarget(
            name: "NoblesKitTests",
            dependencies: ["NoblesKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
