import SwiftUI
import PoliticalFactCheckCore
import PoliticalFactCheckAppModel
import PoliticalFactCheckPersistence

struct CaseDetailView: View {
    let politicalCase: PoliticalFactCheckCore.Case
    let graph: DomainContext
    @ObservedObject var workspace: CaseWorkspaceModel
    @Binding var sheet: EditorSheet?

    private var promise: PromiseRevision? { graph.find(politicalCase.currentPromiseRevisionID) }
    private var reviewLabel: String {
        switch workspace.selectedReviewState {
        case .upToDate: "Aktuell freigegeben / kein offener Review"
        case .reviewRequired: "Erneute Prüfung erforderlich"
        case .notYetApproved, .none: "Noch keine freigegebene Bewertung"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Überblick", systemImage: "doc.text") {
                    LabeledContent("Titel", value: politicalCase.title.value)
                    LabeledContent("Workflow", value: politicalCase.workflowState.displayName)
                    LabeledContent("Prüfstatus", value: reviewLabel)
                    LabeledContent("Erstellt", value: politicalCase.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Geändert", value: politicalCase.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                section("Versprechen", systemImage: "quote.opening") {
                    if let promise {
                        LabeledContent("Originalaussage") { Text(promise.quote.content.displayText).textSelection(.enabled) }
                        LabeledContent("Prüfthese") { Text(promise.thesis.value).textSelection(.enabled) }
                        LabeledContent("Sprecher") { Text(actorName(promise.speaker.content)) }
                        LabeledContent("Partei / Organisation") { Text(actorName(promise.party.content)) }
                        LabeledContent("Aussagezeitpunkt") { Text(promise.statementDate.content.displayText) }
                        LabeledContent("Zitatstatus") { Text(promise.quote.verification.displayName) }
                        if !promise.quote.excerptIDs.isEmpty {
                            Button("Originalzitat anhand geprüfter Fundstelle bestätigen") {
                                _ = workspace.verifyOriginalQuote()
                            }
                            .disabled(promise.quote.verification == .verified)
                        }
                        DisclosureGroup("Frühere Versprechen-Revisionen (nur lesbar)") {
                            ForEach(graph.promiseRevisions.filter { $0.promiseID == politicalCase.promiseID }.sorted {
                                $0.metadata.number < $1.metadata.number
                            }, id: \.id) { revision in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Revision \(revision.metadata.number) · \(revision.quote.verification.displayName)").font(.subheadline)
                                    Text(revision.quote.content.displayText)
                                    Text(revision.thesis.value).foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                        if politicalCase.workflowState == .candidate {
                            Button("Als dokumentiert markieren") { _ = workspace.markDocumented() }
                                .disabled(promise.quote.excerptIDs.isEmpty)
                        }
                    } else { Text("Aktuelle Versprechen-Revision fehlt.").foregroundStyle(.red) }
                }
                section("Kriterien", systemImage: "checklist") {
                    HStack { Spacer(); Button("Kriterium hinzufügen", systemImage: "plus") { sheet = .newCriterion } }
                    let active = politicalCase.activeCriterionRevisionIDs.compactMap { graph.find($0) }
                    if active.isEmpty { Text("Noch keine Kriterien.").foregroundStyle(.secondary) }
                    ForEach(active, id: \.id) { criterion in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(criterion.goal.value).font(.headline)
                            Text("Zielgruppe: \(criterion.targetGroup.value) · \(criterion.isCore ? "Kernkriterium" : "kein Kernkriterium")")
                                .foregroundStyle(.secondary)
                            Text("Frist: \(criterion.deadline.displayText)")
                            Text("Materialität: \(criterion.materialityRule.value)")
                            HStack {
                                Text(criterion.state.displayName)
                                if criterion.state == .draft {
                                    Button("Kriterium bestätigen") { _ = workspace.confirmCriterion(criterion.id) }
                                } else if let confirmation = criterion.confirmation {
                                    Text("Bestätigt: \(confirmation.reviewedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        DisclosureGroup("Frühere Kriterienrevisionen (nur lesbar)") {
                            ForEach(graph.criterionRevisions.filter { $0.criterionID == criterion.criterionID }.sorted {
                                $0.metadata.number < $1.metadata.number
                            }, id: \.id) { revision in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Revision \(revision.metadata.number) · \(revision.state.displayName)").font(.subheadline)
                                    Text(revision.goal.value)
                                    Text("Materialität: \(revision.materialityRule.value)").foregroundStyle(.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                section("Quellen und Fundstellen", systemImage: "books.vertical") {
                    HStack { Spacer(); Button("Quelle hinzufügen", systemImage: "plus") { sheet = .newSource } }
                    if graph.sources.isEmpty { Text("Noch keine manuell erfassten Quellen.").foregroundStyle(.secondary) }
                    ForEach(graph.sources, id: \.id) { source in
                        let versions = graph.sourceVersions.filter { $0.sourceID == source.id }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(versions.first?.title?.value ?? source.documentIdentifier?.value ?? source.canonicalURL?.absoluteString ?? "Quelle")
                                .font(.headline)
                            if let url = source.canonicalURL { Text(url.absoluteString).font(.caption).textSelection(.enabled) }
                            ForEach(versions, id: \.id) { version in
                                Text("Fassung · \(version.verification.displayName) · veröffentlicht: \(version.publicationDate.displayText) · abgerufen: \(version.retrievedAt.displayText)")
                                    .font(.caption).foregroundStyle(.secondary)
                                ForEach(graph.excerpts.filter { $0.sourceVersionID == version.id }, id: \.id) { excerpt in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Fundstelle: \(excerpt.locator.value) · \(excerpt.state.displayName)").font(.subheadline)
                                        Text(excerpt.text.value).textSelection(.enabled)
                                        Text(excerpt.context.value).font(.caption).foregroundStyle(.secondary)
                                        if excerpt.state == .unverified {
                                            Button("Fundstelle und Fassung als geprüft markieren") { _ = workspace.verifyExcerpt(excerpt.id) }
                                        }
                                    }.padding(.leading, 12)
                                }
                            }
                        }.padding(.vertical, 5)
                    }
                }
                section("Evidenz", systemImage: "text.magnifyingglass") {
                    if graph.evidenceLinks.isEmpty { Text("Noch keine Evidenzverknüpfungen.").foregroundStyle(.secondary) }
                    ForEach(graph.evidenceLinks, id: \.id) { link in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(graph.find(link.criterionRevisionID)?.goal.value ?? "Unbekanntes Kriterium").font(.headline)
                            Text("\(link.relationship.displayName) · \(link.directness.displayName) · \(link.status.displayName)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(link.rationale.value)
                            ForEach(link.excerptIDs, id: \.self) { id in
                                if let excerpt = graph.find(id) { Text("Fundstelle: \(excerpt.locator.value) — \(excerpt.text.value)").font(.caption) }
                            }
                        }.padding(.vertical, 5)
                    }
                }
                section("Bewertung", systemImage: "checkmark.seal") {
                    if graph.caseEvaluations.isEmpty { Text("Noch keine Bewertung").foregroundStyle(.secondary) }
                    ForEach(graph.caseEvaluations, id: \.id) { evaluation in
                        VStack(alignment: .leading, spacing: 5) {
                            LabeledContent("Kategorie", value: evaluation.category.displayName)
                            LabeledContent("Evidenzsicherheit", value: evaluation.confidence.displayName)
                            LabeledContent("Status", value: evaluation.status.displayName)
                            LabeledContent("Stichtag", value: evaluation.cutoff.displayText)
                            Text(evaluation.rationale.value).textSelection(.enabled)
                            Text("Historischer Snapshot: \(evaluation.caseRevisionID.rawValue.uuidString)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                if workspace.canDeleteSelectedDraft {
                    Button("Entwurf löschen", role: .destructive) { _ = workspace.deleteSelectedDraft() }
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(politicalCase.title.value)
    }

    @ViewBuilder private func section<Content: View>(_ title: String, systemImage: String,
                                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage).font(.title2.weight(.semibold))
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actorName(_ field: FieldValue<EntityID<Actor>>) -> String {
        switch field {
        case .known(let id): graph.find(id)?.name.value ?? "Akteur nicht gefunden"
        case .unknown(let reason): "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension FieldValue where Value == NonEmptyText {
    var displayText: String {
        switch self { case .known(let value): value.value; case .unknown(let reason): "Unbekannt: \(reason.value)"; case .notApplicable(let reason): "Nicht anwendbar: \(reason.value)" }
    }
}

private extension FieldValue where Value == DatedValue {
    var displayText: String {
        switch self { case .known(let value): value.displayText; case .unknown(let reason): "Unbekannt: \(reason.value)"; case .notApplicable(let reason): "Nicht anwendbar: \(reason.value)" }
    }
}

private extension DatedValue {
    var displayText: String {
        switch content {
        case .known(let interval):
            let start = interval.start?.formatted(date: .abbreviated, time: .omitted) ?? "offen"
            let end = interval.end?.formatted(date: .abbreviated, time: .omitted) ?? "offen"
            return start == end ? start : "\(start) – \(end)"
        case .unknown(let reason): "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension FactVerificationState {
    var displayName: String { switch self { case .unreviewed: "ungeprüft"; case .verified: "geprüft"; case .rejected: "abgelehnt"; case .superseded: "überholt" } }
}
private extension ExcerptVerificationState {
    var displayName: String { switch self { case .unverified: "ungeprüft"; case .verified: "geprüft"; case .rejected: "abgelehnt"; case .superseded: "überholt" } }
}
private extension CriterionRevisionState {
    var displayName: String { switch self { case .draft: "Draft"; case .confirmed: "bestätigt"; case .superseded: "überholt" } }
}
private extension EvaluationCategory {
    var displayName: String { switch self { case .fulfilled: "Erfüllt"; case .mostlyFulfilled: "Überwiegend erfüllt"; case .partiallyFulfilled: "Teilweise erfüllt"; case .notFulfilled: "Nicht erfüllt"; case .contraryAction: "Gegenteilig gehandelt"; case .notVerifiable: "Nicht überprüfbar" } }
}
private extension EvidenceConfidence {
    var displayName: String { switch self { case .high: "hoch"; case .medium: "mittel"; case .low: "niedrig" } }
}
private extension EvaluationStatus {
    var displayName: String { switch self { case .draft: "Entwurf"; case .needsReview: "Prüfung offen"; case .approved: "freigegeben"; case .reviewRequired: "erneute Prüfung erforderlich"; case .superseded: "überholt" } }
}
private extension EvidenceRelationship {
    var displayName: String { switch self { case .supports: "stützt"; case .contradicts: "widerspricht"; case .contextualizes: "kontextualisiert" } }
}
private extension EvidenceDirectness {
    var displayName: String { switch self { case .direct: "direkt"; case .indirect: "indirekt" } }
}

#Preview("Case detail — synthetic") {
    PreviewCaseDetail()
}

@MainActor private struct PreviewCaseDetail: View {
    @StateObject private var workspace: CaseWorkspaceModel
    @State private var sheet: EditorSheet?

    init() {
        let suite = "PoliticalFactCheckPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let model = try! LocalCaseStore.inMemory()
        _workspace = StateObject(wrappedValue: CaseWorkspaceModel(store: model, defaults: defaults))
    }

    var body: some View {
        Group {
            if let item = workspace.selectedCase, let context = workspace.selectedContext {
                CaseDetailView(politicalCase: item, graph: context, workspace: workspace, sheet: $sheet)
            } else { EmptyCaseView(create: {}) }
        }.frame(width: 850, height: 700)
            .task {
                guard workspace.cases.isEmpty else { return }
                workspace.reviewerName = "Synthetischer Preview-Prüfer"
                _ = workspace.createDraftCase(title: "Synthetischer Preview-Fall",
                    quote: "Eine erfundene Beispielaussage.", thesis: "Prüfe ein erfundenes Ziel.",
                    speakerName: "Synthetische Sprecherin", partyName: "Synthetische Organisation",
                    statementDate: nil)
            }
    }
}
