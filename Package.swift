// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalWispr",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalWispr", targets: ["LocalWispr"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "LocalWispr",
            dependencies: [
                "WhisperKit"
            ],
            path: "LocalWispr",
            exclude: ["LocalWispr.entitlements"]
        )
    ]
)
