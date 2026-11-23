// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "L4NETraining",
    defaultLocalization: "el",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "L4NETrainingCore",
            targets: ["L4NETrainingCore"]
        ),
        .library(
            name: "L4NETrainingUI",
            targets: ["L4NETrainingUI"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "L4NECoreFFI",
            path: "Sources/L4NECoreFFI",
            publicHeadersPath: "include",
            linkerSettings: [
                .unsafeFlags(["-Ltarget/release", "-ll4ne_core"])
            ]
        ),
        .target(
            name: "L4NETrainingCore",
            dependencies: ["L4NECoreFFI"],
            path: "Sources/L4NETrainingCore"
        ),
        .target(
            name: "L4NETrainingUI",
            dependencies: ["L4NETrainingCore"],
            path: "Sources/L4NETrainingUI"
        ),
        .testTarget(
            name: "L4NETrainingCoreTests",
            dependencies: ["L4NETrainingCore", "L4NETrainingUI"],
            path: "Tests/L4NETrainingCoreTests"
        )
    ]
)
