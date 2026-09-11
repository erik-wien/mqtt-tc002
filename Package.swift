// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TC002",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "TC002Core", swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "TC002App", dependencies: ["TC002Core"],
                          swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002CoreTests", dependencies: ["TC002Core"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TC002AppTests", dependencies: ["TC002App"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
