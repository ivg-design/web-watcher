// swift-tools-version: 5.9
// WebWatcher v1.2.0 (Build 3)
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
        )
    ]
)
