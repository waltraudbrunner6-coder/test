// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "PoliticalFactCheckCore", targets: ["PoliticalFactCheckCore"])]
var targets: [Target] = [
    .target(name: "PoliticalFactCheckCore"),
    .testTarget(name: "PoliticalFactCheckCoreTests", dependencies: ["PoliticalFactCheckCore"])
]
#if os(macOS)
products.append(.library(name: "PoliticalFactCheckPersistence", targets: ["PoliticalFactCheckPersistence"]))
targets.append(.target(name: "PoliticalFactCheckPersistence", dependencies: ["PoliticalFactCheckCore"]))
targets.append(.testTarget(name: "PoliticalFactCheckPersistenceTests",
    dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence"]))
#endif

let package = Package(
    name: "PoliticalFactCheckCore",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
