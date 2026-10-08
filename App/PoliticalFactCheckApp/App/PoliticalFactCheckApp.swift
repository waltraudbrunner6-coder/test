import SwiftUI
import PoliticalFactCheckAppModel
import PoliticalFactCheckPersistence

@main
struct PoliticalFactCheckApp: App {
    @StateObject private var workspace: CaseWorkspaceModel

    @MainActor
    init() {
        let defaults = UserDefaults.standard
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("PoliticalFactCheck", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let store = try LocalCaseStore.at(url: directory.appendingPathComponent("Cases.store"))
            _workspace = StateObject(wrappedValue: CaseWorkspaceModel(store: store, defaults: defaults))
        } catch {
            _workspace = StateObject(wrappedValue: CaseWorkspaceModel(
                startupError: PoliticalFactCheckAppStartup.message(for: error), defaults: defaults))
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(workspace)
        }
        .defaultSize(width: 1180, height: 820)
    }
}

enum PoliticalFactCheckAppStartup {
    static func message(for error: Error) -> String {
        "Der lokale Faktencheck-Speicher konnte nicht geöffnet werden. \(String(describing: error))"
    }
}
