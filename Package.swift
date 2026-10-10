// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [.library(name: "PoliticalFactCheckCore", targets: ["PoliticalFactCheckCore"])]
products.append(.library(name: "PoliticalFactCheckScripting", targets: ["PoliticalFactCheckScripting"]))
products.append(.library(name: "PoliticalFactCheckResearch", targets: ["PoliticalFactCheckResearch"]))
products.append(.library(name: "PoliticalFactCheckVideoPlanning", targets: ["PoliticalFactCheckVideoPlanning"]))
var targets: [Target] = [
    .target(name: "PoliticalFactCheckVideoPlanning", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"]),
    .testTarget(name: "PoliticalFactCheckVideoPlanningTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting", "PoliticalFactCheckVideoPlanning"]),
    .target(name: "PoliticalFactCheckResearch", dependencies: ["PoliticalFactCheckCore"], resources: [.process("Resources")]),
    .testTarget(name: "PoliticalFactCheckResearchTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckResearch"]),
    .target(name: "PoliticalFactCheckCore"),
    .target(name: "PoliticalFactCheckScripting", dependencies: ["PoliticalFactCheckCore"], resources: [.process("Resources")]),
    .testTarget(name: "PoliticalFactCheckScriptingTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"]),
    .testTarget(name: "PoliticalFactCheckCoreTests", dependencies: ["PoliticalFactCheckCore"])
]
#if os(macOS)
products.append(.library(name: "PoliticalFactCheckAudio", targets: ["PoliticalFactCheckAudio"]))
targets.append(.target(name: "PoliticalFactCheckAudio", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckVideoPlanning"], resources: [.process("Resources")]))
targets.append(.testTarget(name: "PoliticalFactCheckAudioTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckVideoPlanning", "PoliticalFactCheckAudio"]))
products.append(.library(name: "PoliticalFactCheckExport", targets: ["PoliticalFactCheckExport"]))
targets.append(.target(name: "PoliticalFactCheckExport", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting"], resources: [.process("Resources")]))
targets.append(.testTarget(name: "PoliticalFactCheckExportTests", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting", "PoliticalFactCheckExport"]))
products.append(.library(name: "PoliticalFactCheckPersistence", targets: ["PoliticalFactCheckPersistence"]))
products.append(.library(name: "PoliticalFactCheckAppModel", targets: ["PoliticalFactCheckAppModel"]))
targets.append(.target(name: "PoliticalFactCheckPersistence", dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckScripting", "PoliticalFactCheckExport", "PoliticalFactCheckResearch"]))
targets.append(.target(name: "PoliticalFactCheckAppModel", dependencies: ["PoliticalFactCheckAudio", "PoliticalFactCheckVideoPlanning", "PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting", "PoliticalFactCheckExport", "PoliticalFactCheckResearch"]))
targets.append(.testTarget(name: "PoliticalFactCheckAppModelTests", dependencies: ["PoliticalFactCheckAudio", "PoliticalFactCheckVideoPlanning", "PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckAppModel", "PoliticalFactCheckScripting", "PoliticalFactCheckExport", "PoliticalFactCheckResearch"]))
targets.append(.testTarget(name: "PoliticalFactCheckPersistenceTests",
    dependencies: ["PoliticalFactCheckCore", "PoliticalFactCheckPersistence", "PoliticalFactCheckScripting", "PoliticalFactCheckExport", "PoliticalFactCheckResearch"]))
#endif

let package = Package(
    name: "PoliticalFactCheckCore",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
