// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NostrEssentials",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NostrEssentials",
            targets: ["NostrEssentials"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/fabianfabian/CombineWebSocket", .revision("aca69f455cf9cc27d1ecaa5c5b5dc9f54f496d7b")),
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift", .upToNextMinor(from: "0.9.2")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NostrEssentials",
            dependencies: [
                .product(name: "CombineWebSocket", package: "CombineWebSocket"),
                .product(name: "secp256k1", package: "secp256k1.swift"),
            ]
        ),
        .testTarget(
            name: "NostrEssentialsTests",
            dependencies: [
                "NostrEssentials"
            ],
            resources: [
                .copy("Resources/upload-test.png"),
                .copy("Resources/coffeechain.png"),
                .copy("Resources/beerstr.png"),
                .copy("Resources/bitcoin.png")
            ]
        )
    ]
)

//let swiftSettings: [SwiftSetting] = [
//    // -enable-bare-slash-regex becomes
//    .enableUpcomingFeature("BareSlashRegexLiterals"),
//    // -warn-concurrency becomes
//    .enableUpcomingFeature("StrictConcurrency"),
//    .unsafeFlags(["-enable-actor-data-race-checks"],
//        .when(configuration: .debug)),
//]
//
//for target in package.targets {
//    target.swiftSettings = target.swiftSettings ?? []
//    target.swiftSettings?.append(contentsOf: swiftSettings)
//}
