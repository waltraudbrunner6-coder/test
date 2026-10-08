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
    private var activeCriteria: [CriterionRevision] {
        politicalCase.activeCriterionRevisionIDs.compactMap { graph.find($0) }
    }
    private var promiseHistory: [PromiseRevision] {
        graph.promiseRevisions.filter { $0.promiseID == politicalCase.promiseID }
            .sorted { $0.metadata.number < $1.metadata.number }
    }
    private var evaluations: [CaseEvaluation] { graph.caseEvaluations }

    private var reviewLabel: String {
        switch workspace.selectedReviewState {
        case .upToDate: return "Aktuell freigegeben / kein offener Review"
        case .reviewRequired: return "Erneute Prüfung erforderlich"
        case .notYetApproved, .none: return "Noch keine freigegebene Bewertung"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                overviewSection
                promiseSection
                readinessSection
                criteriaSection
                sourcesSection
                actionsSection
                evidenceSection
                evaluationSection
                deleteDraftSection
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(politicalCase.title.value)
    }

    private var overviewSection: some View {
        section("Überblick", systemImage: "doc.text") {
            LabeledContent("Titel", value: politicalCase.title.value)
            LabeledContent("Workflow", value: politicalCase.workflowState.displayName)
            LabeledContent("Prüfstatus", value: reviewLabel)
            LabeledContent("Erstellt", value: politicalCase.createdAt.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Geändert", value: politicalCase.modifiedAt.formatted(date: .abbreviated, time: .shortened))
        }
    }

    @ViewBuilder private var promiseSection: some View {
        section("Versprechen", systemImage: "quote.opening") {
            if let promise {
                promiseFacts(promise)
                promiseActions(promise)
                promiseHistoryDisclosure
            } else {
                Text("Aktuelle Versprechen-Revision fehlt.").foregroundStyle(.red)
            }
        }
    }

    private func promiseFacts(_ value: PromiseRevision) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            LabeledContent("Originalaussage") { Text(value.quote.content.displayText).textSelection(.enabled) }
            LabeledContent("Prüfthese") { Text(value.thesis.value).textSelection(.enabled) }
            LabeledContent("Sprecher") { Text(actorName(value.speaker.content)) }
            LabeledContent("Partei / Organisation") { Text(actorName(value.party.content)) }
            LabeledContent("Aussagezeitpunkt") { Text(value.statementDate.content.displayText) }
            LabeledContent("Zitatstatus") { Text(value.quote.verification.displayName) }
            promiseContextAndSpeaker(value)
        }
    }

    private func promiseContextAndSpeaker(_ value: PromiseRevision) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            LabeledContent("Kontext", value: value.context.content.displayText)
            LabeledContent("Kontextstatus", value: value.context.verification.displayName)
            assertionExcerpts(value.context.excerptIDs)
            LabeledContent("Sprecherstatus", value: value.speaker.verification.displayName)
            assertionExcerpts(value.speaker.excerptIDs)
        }
    }

    private func assertionExcerpts(_ ids: [EntityID<SourceExcerpt>]) -> some View {
        ForEach(ids, id: \.self) { id in
            if let excerpt = graph.find(id) {
                Text("\(excerptSource(excerpt)) · \(excerpt.locator.value) — \(excerpt.text.value)").font(.caption)
            }
        }
    }

    private var readinessSection: some View {
        section("Bewertungsreife", systemImage: "checklist.checked") {
            if let promise {
                LabeledContent("Originalzitat", value: promise.quote.verification.displayName)
                LabeledContent("Kontext", value: promise.context.verification.displayName)
                LabeledContent("Sprecherzuordnung", value: promise.speaker.verification.displayName)
            }
            LabeledContent("Aktive Kriterien", value: String(activeCriteria.count))
            LabeledContent("Bestätigt / Draft", value: "\(activeCriteria.filter { $0.state == .confirmed }.count) / \(activeCriteria.filter { $0.state == .draft }.count)")
            LabeledContent("Workflow", value: politicalCase.workflowState.displayName)
            readinessActions
            Text("Diese Anzeige dient der Orientierung. Der Core prüft jeden Statuswechsel. Bewertungsreife ist noch keine Bewertung.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var readinessActions: some View {
        if politicalCase.workflowState == .documented {
            Button("Prüfrahmen bestätigen") { sheet = .promiseReadiness }
            Button("Fall als geprüft markieren") { workspace.markVerified() }
                .disabled(!workspace.canAdvanceReadiness(to: .verified))
            if !workspace.canAdvanceReadiness(to: .verified) {
                Text("Bestätige zunächst Originalzitat, Kontext und Sprecherzuordnung.").font(.caption).foregroundStyle(.secondary)
            }
        } else if politicalCase.workflowState == .verified {
            Button("Zur Bewertung vorbereiten") { workspace.prepareForEvaluation() }
                .disabled(!workspace.canAdvanceReadiness(to: .readyForEvaluation))
            if !workspace.canAdvanceReadiness(to: .readyForEvaluation) {
                Text("Mindestens ein aktives Kriterium muss für den aktuellen Prüfrahmen menschlich bestätigt sein. Neu angebundene Draft-Kriterien müssen erneut bestätigt werden.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func promiseActions(_ value: PromiseRevision) -> some View {
        if !value.quote.excerptIDs.isEmpty {
            Button("Originalzitat anhand geprüfter Fundstelle bestätigen") {
                _ = workspace.verifyOriginalQuote()
            }
            .disabled(value.quote.verification == .verified)
        }
        if politicalCase.workflowState == .candidate {
            Button("Als dokumentiert markieren") { _ = workspace.markDocumented() }
                .disabled(value.quote.excerptIDs.isEmpty)
        }
    }

    private var promiseHistoryDisclosure: some View {
        DisclosureGroup("Frühere Versprechen-Revisionen (nur lesbar)") {
            ForEach(promiseHistory, id: \.id) { revision in
                promiseHistoryRow(revision)
            }
        }
    }

    private func promiseHistoryRow(_ revision: PromiseRevision) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Revision \(revision.metadata.number) · \(revision.quote.verification.displayName)")
                .font(.subheadline)
            Text(revision.quote.content.displayText)
            Text(revision.thesis.value).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var criteriaSection: some View {
        section("Kriterien", systemImage: "checklist") {
            HStack {
                Spacer()
                Button("Kriterium hinzufügen", systemImage: "plus") { sheet = .newCriterion }
            }
            if activeCriteria.isEmpty {
                Text("Noch keine Kriterien.").foregroundStyle(.secondary)
            }
            ForEach(activeCriteria, id: \.id) { criterion in
                criterionCard(criterion)
            }
        }
    }

    private func criterionCard(_ criterion: CriterionRevision) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(criterion.goal.value).font(.headline)
            Text("Zielgruppe: \(criterion.targetGroup.value) · \(criterion.isCore ? "Kernkriterium" : "kein Kernkriterium")")
                .foregroundStyle(.secondary)
            Text("Frist: \(criterion.deadline.displayText)")
            Text("Materialität: \(criterion.materialityRule.value)")
            criterionConfirmation(criterion)
            criterionHistoryDisclosure(criterion)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func criterionConfirmation(_ criterion: CriterionRevision) -> some View {
        HStack {
            Text(criterion.state.displayName)
            if criterion.state == .draft {
                Button("Kriterium bestätigen") { _ = workspace.confirmCriterion(criterion.id) }
            } else if let confirmation = criterion.confirmation {
                Text("Bestätigt: \(confirmation.reviewedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func criterionHistoryDisclosure(_ criterion: CriterionRevision) -> some View {
        DisclosureGroup("Frühere Kriterienrevisionen (nur lesbar)") {
            ForEach(criterionHistory(criterion), id: \.id) { revision in
                criterionHistoryRow(revision)
            }
        }
    }

    private func criterionHistory(_ criterion: CriterionRevision) -> [CriterionRevision] {
        graph.criterionRevisions.filter { $0.criterionID == criterion.criterionID }
            .sorted { $0.metadata.number < $1.metadata.number }
    }

    private func criterionHistoryRow(_ revision: CriterionRevision) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Revision \(revision.metadata.number) · \(revision.state.displayName)").font(.subheadline)
            Text(revision.goal.value)
            Text("Materialität: \(revision.materialityRule.value)").foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var sourcesSection: some View {
        section("Quellen und Fundstellen", systemImage: "books.vertical") {
            HStack {
                Spacer()
                Button("Quelle hinzufügen", systemImage: "plus") { sheet = .newSource }
            }
            if graph.sources.isEmpty {
                Text("Noch keine manuell erfassten Quellen.").foregroundStyle(.secondary)
            }
            ForEach(graph.sources, id: \.id) { source in
                sourceCard(source)
            }
        }
    }

    private func sourceCard(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sourceTitle(source)).font(.headline)
            if let url = source.canonicalURL {
                Text(url.absoluteString).font(.caption).textSelection(.enabled)
            }
            ForEach(sourceVersions(for: source), id: \.id) { version in
                sourceVersionCard(version)
            }
        }
        .padding(.vertical, 5)
    }

    private func sourceTitle(_ source: Source) -> String {
        sourceVersions(for: source).first?.title?.value
            ?? source.documentIdentifier?.value
            ?? source.canonicalURL?.absoluteString
            ?? "Quelle"
    }

    private func sourceVersions(for source: Source) -> [SourceVersion] {
        graph.sourceVersions.filter { $0.sourceID == source.id }
    }

    private func sourceVersionCard(_ version: SourceVersion) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Fassung · \(version.verification.displayName) · veröffentlicht: \(version.publicationDate.displayText) · abgerufen: \(version.retrievedAt.displayText)")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(excerpts(for: version), id: \.id) { excerpt in
                excerptRow(excerpt)
            }
        }
    }

    private func excerpts(for version: SourceVersion) -> [SourceExcerpt] {
        graph.excerpts.filter { $0.sourceVersionID == version.id }
    }

    private func excerptRow(_ excerpt: SourceExcerpt) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fundstelle: \(excerpt.locator.value) · \(excerpt.state.displayName)").font(.subheadline)
            Text(excerpt.text.value).textSelection(.enabled)
            Text(excerpt.context.value).font(.caption).foregroundStyle(.secondary)
            if excerpt.state == .unverified {
                Button("Fundstelle und Fassung als geprüft markieren") {
                    _ = workspace.verifyExcerpt(excerpt.id)
                }
            }
        }
        .padding(.leading, 12)
    }

    private var actionsSection: some View {
        section("Handlungen / Entwicklungen", systemImage: "list.bullet.rectangle") {
            Button("Handlung hinzufügen") { sheet = .newAction }
            if politicalCase.currentActionRevisionIDs.isEmpty {
                Text("Noch keine Handlungen erfasst.").foregroundStyle(.secondary)
            }
            ForEach(politicalCase.currentActionRevisionIDs, id: \.self) { id in
                if let revision = graph.find(id) {
                    actionRow(revision)
                    if revision.description.verification == .unreviewed && revision.eventDate.verification == .unreviewed && revision.scope.verification == .unreviewed {
                        Button("Handlung prüfen") { sheet = .reviewAction(revision.id) }
                    }
                    DisclosureGroup("Historische Handlungsrevisionen (nur lesend)") {
                        ForEach(graph.actionRevisions.filter { $0.actionID == revision.actionID && $0.id != revision.id }.sorted { $0.metadata.number < $1.metadata.number }, id: \.id) { old in
                            actionRow(old)
                        }
                    }
                }
            }
            Text("Eine Handlung ist noch keine Bewertung. Es wird keine Verantwortung aus Parteizugehörigkeit abgeleitet.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func actionRow(_ revision: ActionRevision) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(revision.title.value) · Revision \(revision.metadata.number)").font(.headline)
            LabeledContent("Typ", value: revision.type.displayName)
            LabeledContent("Verfahrensstatus", value: revision.proceduralState.value)
            LabeledContent("Beschreibung", value: revision.description.content.knownValue?.value ?? "Unbekannt")
            LabeledContent("Bereich", value: revision.scope.content.knownValue?.value ?? "Unbekannt")
            LabeledContent("Ereignisdatum", value: actionDate(revision))
            Text("Beschreibung: \(revision.description.verification.displayName) · Datum: \(revision.eventDate.verification.displayName) · Bereich: \(revision.scope.verification.displayName)")
                .font(.caption).foregroundStyle(.secondary)
            if let level = revision.institutionalLevel { LabeledContent("Institutionelle Ebene", value: level.value) }
            if let identifier = revision.objectIdentifier { LabeledContent("Objektkennung", value: identifier.value) }
            ForEach(revision.excerptIDs, id: \.self) { id in
                if let excerpt = graph.find(id) {
                    Text("\(excerptSource(excerpt)) · \(excerpt.locator.value) · \(excerpt.state.displayName) — \(excerpt.text.value)").font(.caption)
                }
            }
        }.padding(.vertical, 5)
    }

    private func excerptSource(_ excerpt: SourceExcerpt) -> String {
        guard let version = graph.find(excerpt.sourceVersionID), let source = graph.find(version.sourceID) else { return "Quelle fehlt" }
        return version.title?.value ?? source.canonicalURL?.absoluteString ?? source.documentIdentifier?.value ?? "Gespeicherte Quelle"
    }

    private func actionDate(_ revision: ActionRevision) -> String {
        guard let start = revision.eventDate.content.knownValue?.content.knownValue?.start else { return "Unbekannt" }
        return start.formatted(date: .abbreviated, time: .omitted)
    }

    private var evidenceSection: some View {
        section("Evidenz", systemImage: "text.magnifyingglass") {
            Button("Evidenz hinzufügen") { sheet = .newEvidence }
                .disabled(workspace.confirmedCriteria.isEmpty || workspace.verifiedExcerpts.isEmpty)
            if workspace.confirmedCriteria.isEmpty {
                Text("Bestätige zunächst ein aktives Kriterium.").font(.caption).foregroundStyle(.secondary)
            }
            if workspace.verifiedExcerpts.isEmpty {
                Text("Prüfe zunächst eine Fundstelle.").font(.caption).foregroundStyle(.secondary)
            }
            if graph.evidenceLinks.isEmpty {
                Text("Noch keine Evidenzverknüpfungen.").foregroundStyle(.secondary)
            }
            ForEach(graph.evidenceLinks, id: \.id) { link in
                evidenceRow(link)
            }
        }
    }

    private func evidenceRow(_ link: EvidenceLink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(criterionTitle(for: link)).font(.headline)
            Text("\(link.relationship.displayName) · \(link.directness.displayName) · \(link.status.displayName)")
                .font(.caption).foregroundStyle(.secondary)
            Text(link.rationale.value)
            if let id = link.actionRevisionID, let action = graph.find(id) {
                Text("Handlung: \(action.title.value) · Revision \(action.metadata.number)").font(.caption)
            }
            if link.status == .draft {
                Button("Evidenz zur Prüfung vorlegen") { workspace.requestEvidenceReview(link.id) }
                    .disabled(!workspace.canTransitionEvidence(link, to: .needsReview))
            } else if link.status == .needsReview {
                Button("Evidenz prüfen") { workspace.verifyEvidence(link.id) }
                    .disabled(!workspace.canTransitionEvidence(link, to: .verified))
            }
            ForEach(link.excerptIDs, id: \.self) { id in
                if let excerpt = graph.find(id) {
                    Text("Fundstelle: \(excerpt.locator.value) — \(excerpt.text.value)").font(.caption)
                }
            }
        }
        .padding(.vertical, 5)
    }

    private func criterionTitle(for link: EvidenceLink) -> String {
        graph.find(link.criterionRevisionID)?.goal.value ?? "Unbekanntes Kriterium"
    }

    private var evaluationSection: some View {
        section("Bewertung", systemImage: "checkmark.seal") {
            if evaluations.isEmpty {
                Text("Noch keine Bewertung").foregroundStyle(.secondary)
            }
            ForEach(evaluations, id: \.id) { evaluation in
                evaluationCard(evaluation)
            }
        }
    }

    private func evaluationCard(_ evaluation: CaseEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            LabeledContent("Kategorie", value: evaluation.category.displayName)
            LabeledContent("Evidenzsicherheit", value: evaluation.confidence.displayName)
            LabeledContent("Status", value: evaluation.status.displayName)
            LabeledContent("Stichtag", value: evaluation.cutoff.displayText)
            Text(evaluation.rationale.value).textSelection(.enabled)
            Text("Historischer Snapshot: \(evaluation.caseRevisionID.rawValue.uuidString)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var deleteDraftSection: some View {
        if workspace.canDeleteSelectedDraft {
            Button("Entwurf löschen", role: .destructive) { _ = workspace.deleteSelectedDraft() }
        }
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
        case .known(let id): return graph.find(id)?.name.value ?? "Akteur nicht gefunden"
        case .unknown(let reason): return "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): return "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension FieldValue where Value == NonEmptyText {
    var displayText: String {
        switch self {
        case .known(let value): return value.value
        case .unknown(let reason): return "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): return "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension FieldValue where Value == DatedValue {
    var displayText: String {
        switch self {
        case .known(let value): return value.displayText
        case .unknown(let reason): return "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): return "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension DatedValue {
    var displayText: String {
        switch content {
        case .known(let interval):
            let start = interval.start?.formatted(date: .abbreviated, time: .omitted) ?? "offen"
            let end = interval.end?.formatted(date: .abbreviated, time: .omitted) ?? "offen"
            return start == end ? start : "\(start) – \(end)"
        case .unknown(let reason): return "Unbekannt: \(reason.value)"
        case .notApplicable(let reason): return "Nicht anwendbar: \(reason.value)"
        }
    }
}

private extension FactVerificationState {
    var displayName: String {
        switch self {
        case .unreviewed: return "ungeprüft"
        case .verified: return "geprüft"
        case .rejected: return "abgelehnt"
        case .superseded: return "überholt"
        }
    }
}
private extension ExcerptVerificationState {
    var displayName: String {
        switch self {
        case .unverified: return "ungeprüft"
        case .verified: return "geprüft"
        case .rejected: return "abgelehnt"
        case .superseded: return "überholt"
        }
    }
}
private extension CriterionRevisionState {
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .confirmed: return "bestätigt"
        case .superseded: return "überholt"
        }
    }
}
private extension EvaluationCategory {
    var displayName: String {
        switch self {
        case .fulfilled: return "Erfüllt"
        case .mostlyFulfilled: return "Überwiegend erfüllt"
        case .partiallyFulfilled: return "Teilweise erfüllt"
        case .notFulfilled: return "Nicht erfüllt"
        case .contraryAction: return "Gegenteilig gehandelt"
        case .notVerifiable: return "Nicht überprüfbar"
        }
    }
}
private extension EvidenceConfidence {
    var displayName: String {
        switch self {
        case .high: return "hoch"
        case .medium: return "mittel"
        case .low: return "niedrig"
        }
    }
}
private extension EvaluationStatus {
    var displayName: String {
        switch self {
        case .draft: return "Entwurf"
        case .needsReview: return "Prüfung offen"
        case .approved: return "freigegeben"
        case .reviewRequired: return "erneute Prüfung erforderlich"
        case .superseded: return "überholt"
        }
    }
}
private extension EvidenceRelationship {
    var displayName: String {
        switch self {
        case .supports: return "stützt"
        case .contradicts: return "widerspricht"
        case .contextualizes: return "kontextualisiert"
        }
    }
}
private extension EvidenceDirectness {
    var displayName: String {
        switch self {
        case .direct: return "direkt"
        case .indirect: return "indirekt"
        }
    }
}
private extension EvidenceLinkStatus {
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .needsReview: return "Prüfung erforderlich"
        case .verified: return "geprüft"
        case .rejected: return "abgelehnt"
        case .superseded: return "überholt"
        }
    }
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
