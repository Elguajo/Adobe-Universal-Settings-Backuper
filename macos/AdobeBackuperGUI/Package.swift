// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AdobeBackuperGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AdobeBackuperGUI", targets: ["AdobeBackuperGUI"])
    ],
    targets: [
        .executableTarget(
            name: "AdobeBackuperGUI"
        )
    ]
)
