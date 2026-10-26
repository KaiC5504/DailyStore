// swift-tools-version:6.0
// Compile-check only (tools/check-app.sh). The real app is built by XcodeGen from ios/project.yml;
// this manifest mirrors its DailyStore and DailyStoreWidget targets. The script copies the sources
// next to it, Sources/Shared into both targets as Xcode does, so the paths are relative to the
// staging folder, not to this file.
import PackageDescription

let package = Package(
    name: "DailyStoreCheck",
    platforms: [.iOS("26.0")],
    dependencies: [
        .package(path: "ValorantCore"),
    ],
    targets: [
        .target(
            name: "DailyStore",
            dependencies: [.product(name: "ValorantCore", package: "ValorantCore")],
            path: "App"
        ),
        .target(
            name: "DailyStoreWidget",
            dependencies: [.product(name: "ValorantCore", package: "ValorantCore")],
            path: "Widget"
        ),
    ],
    swiftLanguageModes: [.v5]
)
