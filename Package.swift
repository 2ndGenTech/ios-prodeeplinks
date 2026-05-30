// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProDeepLinks",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "ProDeepLinks",
            targets: ["ProDeepLinks"]
        ),
    ],
    targets: [
        .target(
            name: "ProDeepLinks",
            path: "Sources/ProDeepLinks"
        ),
        .testTarget(
            name: "ProDeepLinksTests",
            dependencies: ["ProDeepLinks"],
            path: "Tests/ProDeepLinksTests"
        ),
    ]
)
