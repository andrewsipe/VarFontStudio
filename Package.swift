// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VarFontEditor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "VarFontCore", targets: ["VarFontCore"]),
    ],
    targets: [
        .target(
            name: "VarFontCore",
            path: "Sources/VarFontCore"
        ),
        .testTarget(
            name: "VarFontCoreTests",
            dependencies: ["VarFontCore"],
            path: "Tests/VarFontCoreTests"
        ),
    ]
)
