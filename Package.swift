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
            targets: ["Adapters"]),
        .library(
            name: "Helpers",
            targets: ["Helpers"]),
        .library(
            name: "Services",
            targets: ["Services"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.1"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"),
        .target(
            name: "Helpers",
            dependencies: ["KeychainAccess"],
            path: "Sources/Helpers"),
        .target(
            name: "Services",
            dependencies: ["Models", "Helpers"],
            path: "Sources/Services"),
        .target(
            name: "Adapters",
            dependencies: ["Models", "Helpers", "Services", "Alamofire"],
            path: "Sources/Adapters"),
        .executableTarget(
            name: "UnifiedSmartHome",
            dependencies: ["Models", "Adapters", "Helpers", "Services"],
            path: "Sources",
            exclude: ["Models", "Adapters", "Helpers", "Services"]),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"],
            path: "Tests/ModelsTests"),
        .testTarget(
            name: "AdaptersTests",
            dependencies: ["Adapters", "Models", "Helpers", "Services"],
            path: "Tests/AdaptersTests")
    ]
)
