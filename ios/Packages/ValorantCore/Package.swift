// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "ValorantCore",
    // macOS only so `swift test` runs on CI hosts; the app itself is iOS-only.
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "ValorantCore", targets: ["ValorantCore"]),
    ],
    targets: [
        .target(name: "ValorantCore"),
        .testTarget(name: "ValorantCoreTests", dependencies: ["ValorantCore"]),
    ],
    // Matches the app target; strict concurrency is not worth fighting without a Mac.
    swiftLanguageModes: [.v5]
)
