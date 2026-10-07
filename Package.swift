// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PoliticalFactCheckCore",
    products: [.library(name: "PoliticalFactCheckCore", targets: ["PoliticalFactCheckCore"])],
    targets: [
        .target(name: "PoliticalFactCheckCore"),
        .testTarget(name: "PoliticalFactCheckCoreTests", dependencies: ["PoliticalFactCheckCore"])
    ]
)
