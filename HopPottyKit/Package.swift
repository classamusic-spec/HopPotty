// swift-tools-version: 6.0
import PackageDescription

// HopPottyKit holds every piece of HopPotty that does not depend on Apple UI or
// Screen Time frameworks. Keeping it platform-agnostic means the scheduling
// engine, reward ledger, state machine and insight rules can be compiled and
// tested on any Swift toolchain — including CI without Xcode.
let package = Package(
    name: "HopPottyKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HopPottyCore", targets: ["HopPottyCore"]),
        .library(name: "HopPottyDesignTokens", targets: ["HopPottyDesignTokens"]),
        .library(name: "HopPottyFixtures", targets: ["HopPottyFixtures"]),
    ],
    targets: [
        .target(name: "HopPottyDesignTokens"),
        .target(name: "HopPottyCore"),
        .target(name: "HopPottyFixtures", dependencies: ["HopPottyCore"]),
        .testTarget(
            name: "HopPottyCoreTests",
            dependencies: ["HopPottyCore", "HopPottyFixtures"]
        ),
        .testTarget(
            name: "HopPottyDesignTokensTests",
            dependencies: ["HopPottyDesignTokens"]
        ),
    ]
)
