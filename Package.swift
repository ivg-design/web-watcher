// swift-tools-version: 5.9
// WebWatcher v1.10.6 (Build 31)
// https://github.com/ivg-design/web-watcher

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
        ),
        .testTarget(
            name: "WebWatcherTests",
            dependencies: ["WebWatcher"],
            path: "Tests/WebWatcherTests"
        )
    ]
)
