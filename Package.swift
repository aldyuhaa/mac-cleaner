// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacCleaner",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacCleaner", targets: ["MacCleaner"])
    ],
    targets: [
        .executableTarget(name: "MacCleaner")
    ]
)
