// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "PoliticalFactCheckCore", targets: ["PoliticalFactCheckCore"])]
products.append(.library(name: "PoliticalFactCheckScripting", targets: ["PoliticalFactCheckScripting"]))
var targets: [Target] = [
    .target(name: "PoliticalFactCheckCore"),
    .target(name: "PoliticalFactCheckScripting", dependencies: ["PoliticalFactCheckCore"], resources: [.process("Resources")]),
    .testTarget(name: "PoliticalFactCheckScriptingTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"]),
    .testTarget(name: "PoliticalFactCheckCoreTests", dependencies: ["PoliticalFactCheckCore"])
]
#if os(macOS)
products.append(.library(name: "PoliticalFactCheckExport", targets: ["PoliticalFactCheckExport"]))
targets.append(.target(name: "PoliticalFactCheckExport", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"], resources: [.process("Resources")]))
targets.append(.testTarget(name: "PoliticalFactCheckExportTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
products.append(.library(name: "PoliticalFactCheckPersistence", targets: ["PoliticalFactCheckPersistence"]))
products.append(.library(name: "PoliticalFactCheckAppModel", targets: ["PoliticalFactCheckAppModel"]))
targets.append(.target(name: "PoliticalFactCheckPersistence", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
targets.append(.target(name: "PoliticalFactCheckAppModel", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
targets.append(.testTarget(name: "PoliticalFactCheckAppModelTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckAppModel", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
targets.append(.testTarget(name: "PoliticalFactCheckPersistenceTests",
    dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
#endif

let package = Package(
    name: "PoliticalFactCheckCore",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
