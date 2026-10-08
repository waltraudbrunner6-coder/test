// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "PoliticalFactCheckCore", targets: ["PoliticalFactCheckCore"])]
products.append(.library(name: "PoliticalFactCheckScripting", targets: ["PoliticalFactCheckScripting"]))
var targets: [Target] = [
    .target(name: "PoliticalFactCheckCore"),
    .target(name: "PoliticalFactCheckScripting", dependencies: ["PoliticalFactCheckCore"]),
    .testTarget(name: "PoliticalFactCheckScriptingTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"]),
    .testTarget(name: "PoliticalFactCheckCoreTests", dependencies: ["PoliticalFactCheckCore"])
]
#if os(macOS)
products.append(.library(name: "PoliticalFactCheckPersistence", targets: ["PoliticalFactCheckPersistence"]))
products.append(.library(name: "PoliticalFactCheckAppModel", targets: ["PoliticalFactCheckAppModel"]))
targets.append(.target(name: "PoliticalFactCheckPersistence", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"]))
targets.append(.target(name: "PoliticalFactCheckAppModel", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting"]))
targets.append(.testTarget(name: "PoliticalFactCheckAppModelTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckAppModel", "PoliticalFactCheckScripting"]))
targets.append(.testTarget(name: "PoliticalFactCheckPersistenceTests",
    dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting"]))
#endif

let package = Package(
    name: "PoliticalFactCheckCore",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
