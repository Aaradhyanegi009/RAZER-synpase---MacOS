// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SynapseMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CRazer",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "SynapseMac",
            dependencies: ["CRazer"]
        )
    ]
)
