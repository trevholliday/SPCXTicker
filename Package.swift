// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SPCXTicker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SPCXTicker",
            path: "Sources/SPCXTicker"
        )
    ]
)
