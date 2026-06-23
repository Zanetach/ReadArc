// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadArc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReadArc", targets: ["ReadArc"]),
        .executable(name: "ReadArcCoreSmokeTests", targets: ["ReadArcCoreSmokeTests"])
    ],
    targets: [
        .target(
            name: "ReadArcCore"
        ),
        .executableTarget(
            name: "ReadArc",
            dependencies: ["ReadArcCore"]
        ),
        .executableTarget(
            name: "ReadArcCoreSmokeTests",
            dependencies: ["ReadArcCore"]
        )
    ]
)
