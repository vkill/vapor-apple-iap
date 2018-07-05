// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "VaporAppleIAP",
    products: [
        .library(name: "VaporAppleIAP", targets: ["VaporAppleIAP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/http", from: "3.0.0"),
    ],
    targets: [
        .target(name: "VaporAppleIAP", dependencies: ["HTTP"]),
        .testTarget(name: "VaporAppleIAPTests", dependencies: ["VaporAppleIAP"]),
    ]
)
