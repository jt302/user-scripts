// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "UserScripts",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "UserScriptsCore",
            targets: ["UserScriptsCore"]
        ),
        .executable(
            name: "UserScriptsApp",
            targets: ["UserScriptsApp"]
        ),
    ],
    targets: [
        .target(
            name: "UserScriptsCore"
        ),
        .executableTarget(
            name: "UserScriptsApp",
            dependencies: ["UserScriptsCore"]
        ),
        .testTarget(
            name: "UserScriptsCoreTests",
            dependencies: [
                "UserScriptsCore",
                "UserScriptsApp",
            ]
        ),
    ]
)
