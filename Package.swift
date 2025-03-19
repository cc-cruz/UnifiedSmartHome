// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UnifiedSmartHome",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "UnifiedSmartHome",
            targets: ["UnifiedSmartHome"]),
        .library(
            name: "Models",
            targets: ["Models"]),
        .library(
            name: "Adapters",
            targets: ["Adapters"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"),
        .target(
            name: "Adapters",
            dependencies: ["Models"],
            path: "ios/Adapters"),
        .executableTarget(
            name: "UnifiedSmartHome",
            dependencies: ["Models", "Adapters"],
            path: "Sources",
            exclude: ["Models"]),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"],
            path: "Tests/ModelsTests"),
        .testTarget(
            name: "AdaptersTests",
            dependencies: ["Adapters", "Models"],
            path: "Tests/AdaptersTests")
    ]
)
