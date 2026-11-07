// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cleaner",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Cleaner", path: "Sources/Cleaner")
    ]
)
