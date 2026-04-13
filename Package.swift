// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "AsciiChartApp",
    platforms: [
        .macOS(.v11)
    ],
    targets: [
        .executableTarget(
            name: "AsciiChartApp",
            path: "Sources/AsciiChartApp"
        )
    ]
)
