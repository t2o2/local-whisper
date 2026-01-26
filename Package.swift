// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocalWhisper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LocalWhisper", targets: ["LocalWhisper"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.5.0")
    ],
    targets: [
        .executableTarget(
            name: "LocalWhisper",
            dependencies: [
                "WhisperKit",
                "Sparkle"
            ],
            path: "LocalWhisper",
            exclude: ["LocalWhisper.entitlements"]
        )
    ]
)
