// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WebWatcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WebWatcher", targets: ["WebWatcher"])
    ],
    targets: [
        .executableTarget(
            name: "WebWatcher",
            path: "Sources/WebWatcher"
        )
    ]
)
