// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Features",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Features",
            targets: ["Features"]
        ),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Networking"),
        .package(path: "../Persistence"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Features",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "Networking", package: "Networking"),
                .product(name: "Persistence", package: "Persistence"),
            ]
        ),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"]
        ),
    ]
)
