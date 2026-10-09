import SwiftUI
import AppKit
import PoliticalFactCheckCore
import PoliticalFactCheckAppModel
import PoliticalFactCheckPersistence

struct MainWindowView: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @State private var sheet: EditorSheet?
    @State private var showsResearchInbox = true

    var body: some View {
        VStack(spacing: 0) {
            if let error = workspace.errorMessage {
                ErrorBanner(message: error, dismiss: workspace.dismissError)
            }
            NavigationSplitView {
                sidebar
            } detail: {
                if showsResearchInbox {
                    ResearchInboxView(workspace: workspace) { id in
                        workspace.selectCase(id); showsResearchInbox = false
                    }
                } else if let politicalCase = workspace.selectedCase,
                   let graph = workspace.selectedContext {
                    CaseDetailView(politicalCase: politicalCase, graph: graph,
                                   workspace: workspace, sheet: $sheet)
                } else if workspace.cases.isEmpty {
                    EmptyCaseView { sheet = .newCase }
                } else {
                    ContentUnavailableView("Fall nicht geladen", systemImage: "exclamationmark.triangle",
                        description: Text("Lade die Fallliste neu oder wähle einen anderen Fall."))
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Automatisch Fälle finden", systemImage: "sparkle.magnifyingglass") {
                    showsResearchInbox = true
                    Task { await workspace.discoverPromises() }
                }.disabled(workspace.isDiscoveringPromises || workspace.isResearchingCases)
                Button("Recherche-Inbox", systemImage: "tray") { showsResearchInbox = true }

                Button("Neu laden", systemImage: "arrow.clockwise") { workspace.reload() }
                    .help("Lokale Fälle neu laden")
                Button("Redaktionspaket importieren", systemImage: "square.and.arrow.down") { chooseEditorialPackage() }
                Button("Neuer Fall", systemImage: "plus") { showsResearchInbox = false; sheet = .newCase }
                    .help("Einen ungeprüften Faktencheck-Fall anlegen")
                Button("Prüfername", systemImage: "person.crop.circle") { sheet = .reviewer }
                    .help("Lokalen menschlichen Prüfer festlegen")
            }
        }
        .sheet(item: $sheet) { selectedSheet in
            sheetContent(selectedSheet)
        }
    }

    private func chooseEditorialPackage() {
        let panel = NSOpenPanel()
        panel.title = "Redaktionspaket importieren"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if workspace.prepareEditorialImport(from: url) { sheet = .editorialImport }
    }

    private var sidebar: some View {
        List(selection: Binding(
            get: { workspace.selectedCaseID },
            set: { workspace.selectCase($0); showsResearchInbox = false }
        )) {
            ForEach(workspace.cases, id: \.id) { politicalCase in
                CaseSidebarRow(politicalCase: politicalCase,
                    reviewState: workspace.reviewStates[politicalCase.id])
                    .tag(politicalCase.id)
            }
        }
        .navigationTitle("Faktenchecks")
    }

    @ViewBuilder
    private func sheetContent(_ route: EditorSheet) -> some View {
        switch route {
        case .newCase:
            NewCaseSheet()
        case .newCriterion:
            if let selectedCase = workspace.selectedCase {
                NewCriterionSheet(caseID: selectedCase.id)
            }
        case .newSource:
            if let selectedCase = workspace.selectedCase {
                NewSourceSheet(caseID: selectedCase.id)
            }
        case .newAction:
            NewActionSheet()
        case .newEvidence:
            NewEvidenceSheet()
        case .reviewAction(let id):
            ActionReviewSheet(revisionID: id)
        case .promiseReadiness:
            PromiseReadinessSheet()
        case .manualEvaluation:
            ManualEvaluationSheet()
        case .openAITransmission:
            OpenAITransmissionSheet()
        case .manualScript(let evaluationID, let sourceID):
            ManualScriptSheet(evaluationID: evaluationID, sourceID: sourceID)
        case .editorialImport:
            EditorialImportSheet()
        case .reviewer:
            ReviewerSettingsSheet()
        }
    }
}

enum EditorSheet: Identifiable {
    case newCase, newCriterion, newSource, reviewer, newAction, newEvidence, promiseReadiness, manualEvaluation
    case openAITransmission, editorialImport
    case manualScript(EntityID<CaseEvaluation>, EntityID<ScriptDraft>?)
    case reviewAction(EntityID<ActionRevision>)
    var id: String {
        switch self {
        case .newCase: "newCase"
        case .newCriterion: "newCriterion"
        case .newSource: "newSource"
        case .reviewer: "reviewer"
        case .newAction: "newAction"
        case .newEvidence: "newEvidence"
        case .promiseReadiness: "promiseReadiness"
        case .manualEvaluation: "manualEvaluation"
        case .openAITransmission: "openAITransmission"
        case .editorialImport: "editorialImport"
        case .manualScript(let id, let source): "script-\(id.rawValue)-\(source?.rawValue.uuidString ?? "new")"
        case .reviewAction(let id): "reviewAction-\(id.rawValue.uuidString)"
        }
    }
}

struct EmptyCaseView: View {
    var create: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("Noch kein Faktencheck", systemImage: "text.magnifyingglass")
        } description: {
            Text("Lege einen Fall als ungeprüften Entwurf an. Es wird kein Demo-Fall gespeichert.")
        } actions: {
            Button("Neuen Fall anlegen", action: create)
                .buttonStyle(.borderedProminent)
        }
    }
}

struct CaseSidebarRow: View {
    let politicalCase: PoliticalFactCheckCore.Case
    let reviewState: CaseReviewState?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(politicalCase.title.value)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: 8) {
                Text(politicalCase.workflowState.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if reviewState == .reviewRequired {
                    Label("Erneute Prüfung", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ErrorBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Schließen", action: dismiss)
                .buttonStyle(.borderless)
        }
        .padding(12)
        .background(.orange.opacity(0.12))
    }
}

extension CaseWorkflowState {
    var displayName: String {
        switch self {
        case .candidate: "Kandidat"
        case .documented: "Dokumentiert"
        case .verified: "Verifiziert"
        case .readyForEvaluation: "Bewertungsbereit"
        case .evaluated: "Bewertet"
        case .approved: "Freigegeben"
        }
    }
}

#Preview("Empty workspace") {
    let store = try! LocalCaseStore.inMemory()
    MainWindowView()
        .environmentObject(CaseWorkspaceModel(store: store, defaults: UserDefaults(suiteName: "PoliticalFactCheckEmptyPreview") ?? .standard))
        .frame(width: 1100, height: 760)
}

#Preview("Sidebar row — synthetic") {
    let politicalCase = PoliticalFactCheckCore.Case(title: try! NonEmptyText("Synthetischer Preview-Fall"),
        promiseID: EntityID<Promise>(), currentPromiseRevisionID: EntityID<PromiseRevision>())
    CaseSidebarRow(politicalCase: politicalCase, reviewState: .reviewRequired)
        .padding().frame(width: 300)
}

struct ResearchInboxView: View {
    @ObservedObject var workspace: CaseWorkspaceModel
    var openCase: (EntityID<PoliticalFactCheckCore.Case>) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recherche-Inbox").font(.largeTitle)
                Text("KI-gefundene Fälle sind ungeprüfte Recherchekandidaten. Quellen und Kontext werden in den nächsten automatischen Prüfschritten weiter validiert.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Automatisch Fälle finden") { Task { await workspace.discoverPromises() } }
                        .buttonStyle(.borderedProminent).disabled(workspace.isDiscoveringPromises || workspace.isResearchingCases)
                    if workspace.isDiscoveringPromises {
                        ProgressView().controlSize(.small)
                        Text("Quellengruppen werden recherchiert …")
                        Button("Abbrechen") { workspace.cancelDiscovery() }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(workspace.pendingResearchCount) Kandidaten · bis zu 11 Recherche-Lanes pro Kandidat (ORIGINAL, 3 × SUPPORT/CONTRADICTION/CONTEXT, ASSESSMENT)").font(.caption)
                    Button("Alle Kandidaten automatisch vertiefen") { Task { await workspace.researchCandidates() } }
                        .disabled(workspace.isResearchingCases || workspace.isDiscoveringPromises || workspace.pendingResearchCount == 0)
                    if workspace.isResearchingCases {
                        ProgressView()
                        Text(workspace.researchProgress ?? "Recherche läuft …")
                        Button("Vertiefung abbrechen") { workspace.cancelCaseResearch() }
                    }
                    if let message = workspace.researchMessage { Text(message) }
                    if let error = workspace.researchErrorMessage { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
                }
                if let message = workspace.discoveryMessage { Text(message).textSelection(.enabled) }
                if let error = workspace.discoveryErrorMessage { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
                if workspace.researchInbox.isEmpty { Text("Noch keine ungeprüften Recherchekandidaten. Auch null Funde sind ein gültiges Rechercheergebnis.").foregroundStyle(.secondary) }
                ForEach(workspace.researchInbox) { item in
                    ResearchCandidateCard(item: item, researched: workspace.researchDossiers[item.id] != nil, open: { openCase(item.id) }, discard: { workspace.discardDiscoveryCandidate(id: item.id) })
                }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ResearchCandidateCard: View {
    let item: ResearchInboxItem
    let researched: Bool
    let open: () -> Void
    let discard: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(researched ? "Bereits vertieft recherchiert · KI-Recherche – ungeprüft" : "Ungeprüfter KI-Recherchekandidat").font(.caption).foregroundStyle(.orange)
            Text(item.candidate.title).font(.headline)
            Text(item.candidate.exactQuote).textSelection(.enabled)
            Text("Sprecher: " + (item.candidate.speakerName ?? "unbekannt") + " · Partei: " + (item.candidate.partyName ?? "unbekannt"))
            Text("Aussage: " + (item.candidate.statementDate ?? "unbekannt") + " · Genauigkeit: " + (item.candidate.statementDatePrecision ?? "unbekannt"))
            Text("Prüfbarkeit: \(item.score)/100 — keine Wahrheitsbewertung")
            Text(item.candidate.whyCheckable).foregroundStyle(.secondary)
            if let source = item.source, let url = URL(string: source.url) {
                Text(source.category?.displayName ?? "Quelle").font(.caption)
                Link(item.candidate.sourceTitle ?? source.title ?? source.domain, destination: url)
                Text(source.url).font(.caption).textSelection(.enabled)
            }
            ForEach(Array(item.candidate.uncertainties.enumerated()), id: \.offset) { _, uncertainty in
                Text("Unsicherheit: " + uncertainty).foregroundStyle(.secondary)
            }
            HStack {
                Button("Fall öffnen", action: open)
                Button("Kandidat verwerfen", role: .destructive, action: discard)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
