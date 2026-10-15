// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Bounce",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Bounce",
            targets: ["Bounce"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Bounce",
            dependencies: [],
            path: "Bounce",
            exclude: ["Info.plist"]
        ),
    ]
)
