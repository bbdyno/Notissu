// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NoticeKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NoticeKit", targets: ["NoticeKit"]),
        .executable(name: "board-check", targets: ["board-check"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tid-kijyun/Kanna", from: "6.1.0"),
    ],
    targets: [
        .target(
            name: "NoticeKit",
            dependencies: ["Kanna"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "board-check",
            dependencies: ["NoticeKit"]
        ),
        .testTarget(
            name: "NoticeKitTests",
            dependencies: ["NoticeKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
