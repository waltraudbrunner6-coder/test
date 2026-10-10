import SwiftUI
import AppKit
import PoliticalFactCheckCore
import PoliticalFactCheckAppModel
import PoliticalFactCheckPersistence

struct CaseDetailView: View {
    let politicalCase: PoliticalFactCheckCore.Case
    let graph: DomainContext
    @ObservedObject var workspace: CaseWorkspaceModel
    @Binding var sheet: EditorSheet?
    @State private var scriptTargetSeconds: Double = 45

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
                automatedResearchSection
                promiseSection
                readinessSection
                criteriaSection
                sourcesSection
                actionsSection
                evidenceSection
                evaluationSection
                scriptSection
                exportSection
                deleteDraftSection
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(politicalCase.title.value)
    }

    private var automatedResearchSection: some View {
        section("Automatische Recherche", systemImage: "magnifyingglass") {
            if let dossier = workspace.researchDossiers[politicalCase.id] {
                if let plan = workspace.researchReviewPlan {
                    ResearchReviewQueueView(workspace: workspace, plan: plan).id(politicalCase.id)
                } else if let blocker = workspace.researchReviewBlocker { Text(blocker).foregroundStyle(.orange) }
                if workspace.scriptReviewPlan != nil { currentScriptActions }
                ResearchDossierView(dossier: dossier)
            } else if politicalCase.workflowState == .candidate,
                      workspace.researchInbox.contains(where: { $0.id == politicalCase.id }) {
                Text("KI-Recherche – ungeprüft. Bis zu 11 Recherche-Lanes; keine genaue Kostenschätzung verfügbar.").font(.caption)
                Button("Kandidaten automatisch vertiefen") { Task { await workspace.researchCandidates(ids: [politicalCase.id]) } }
                    .disabled(workspace.isResearchingCases || workspace.isDiscoveringPromises)
                if workspace.isResearchingCases { Text(workspace.researchProgress ?? "Recherche läuft …") }
            } else { Text("Kein automatisches Recherche-Dossier vorhanden.").foregroundStyle(.secondary) }
            if let error = workspace.researchErrorMessage { Text(error).foregroundStyle(.orange) }
        }
    }

    private var exportSection: some View {
        section("Export", systemImage: "square.and.arrow.up") {
            Text("Historischer geprüfter Stand als lokales Redaktionspaket, Formatversion 1.").font(.caption)
            ForEach(graph.scripts.filter { $0.status == .approved }, id: \.id) { script in
                if let summary = workspace.editorialExportSummary(scriptID: script.id) {
                    exportDetails(summary)
                    Button("Redaktionspaket exportieren") { chooseExportDestination(script, summary: summary) }
                }
            }
            if !graph.scripts.contains(where: { workspace.editorialExportSummary(scriptID: $0.id) != nil }) {
                Text("Export verlangt eine aktuell freigegebene Bewertung und ein gültiges menschlich freigegebenes Skript.").foregroundStyle(.secondary)
            }
        }
    }
    private func exportDetails(_ summary: EditorialPackageSummary) -> some View {
        VStack(alignment: .leading) {
            Text("Bewertung: \(summary.category.displayName)")
            Text("Stichtag: \(summary.cutoff.displayText)")
            Text("Methodik: \(summary.methodologyVersion) · Scriptversion: \(summary.scriptVersion) · Status: approved")
            Text("\(summary.statementCount) Statements · \(summary.sourceCount) Quellenfassungen · \(summary.excerptCount) Fundstellen · Paketformat \(summary.schemaVersion)")
        }.font(.caption)
    }
    private func chooseExportDestination(_ script: ScriptDraft, summary: EditorialPackageSummary) {
        let panel = NSSavePanel()
        panel.title = "Redaktionspaket exportieren"
        panel.canCreateDirectories = true
        let name = summary.title.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        panel.nameFieldStringValue = String((name.isEmpty ? "Fall" : name).prefix(80)) + ".politicalfactcheck"
        guard panel.runModal() == .OK, let selected = panel.url else { return }
        let destination = selected.pathExtension == "politicalfactcheck" ? selected : selected.appendingPathExtension("politicalfactcheck")
        _ = workspace.exportEditorialPackage(scriptID: script.id, to: destination)
    }

    private var scriptSection: some View {
        section("Skript", systemImage: "text.alignleft") {
            Text("KI-Entwürfe werden erst nach Übertragungsvorschau gesendet und bleiben ungeprüft.").font(.subheadline).foregroundStyle(.secondary)
            Text("Zielzeit ist ein Planwert; keine gemessene Sprechdauer.").font(.caption)
            Stepper("Zielzeit: \(Int(scriptTargetSeconds)) Sekunden", value: $scriptTargetSeconds, in: 30...60, step: 5)
            currentScriptActions
            if let plan = workspace.scriptReviewPlan, plan.scriptID != nil {
                ScriptReviewQueueView(workspace: workspace, plan: plan).id(plan.scriptID)
            } else if let blocker = workspace.scriptReviewBlocker {
                Text(blocker).foregroundStyle(.orange)
            }
            if let handoff = workspace.videoScriptHandoff { VideoHandoffPreview(handoff: handoff) }
            if graph.scripts.isEmpty { Text("Noch kein Skriptentwurf.").foregroundStyle(.secondary) }
            DisclosureGroup("Skriptfassungen und bestehende Einzelaktionen") {
                ForEach(graph.scripts.sorted { $0.createdAt < $1.createdAt }, id: \.id) { script in
                    scriptCard(script)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder private var currentScriptActions: some View {
        if let plan = workspace.scriptReviewPlan {
            HStack {
                if plan.generationAvailable {
                    Button("KI-Skript erzeugen") { prepareCurrentPreview(newVersion: false) }
                        .buttonStyle(.borderedProminent).disabled(workspace.isGeneratingScript)
                } else if plan.scriptStatus == .draft || plan.scriptStatus == .needsReview {
                    Text("Skriptprüfung fortsetzen · \(plan.reviewedCount)/\(plan.totalCount) Sätze geprüft")
                } else {
                    if plan.readyForVideo { Text("Skript freigegeben").foregroundStyle(.green) }
                    Button("Neue KI-Skriptversion erzeugen") { prepareCurrentPreview(newVersion: true) }
                        .disabled(workspace.isGeneratingScript)
                }
                Button("Manuellen Entwurf anlegen") { sheet = .manualScript(plan.evaluationID, nil) }
            }
            #if DEBUG
            Button("Lokaler Test-Provider – keine echte KI") {
                Task { await workspace.generateScript(evaluationID: plan.evaluationID, targetDurationSeconds: scriptTargetSeconds) }
            }.disabled(workspace.isGeneratingScript || !plan.generationAvailable)
            #endif
        }
    }

    private func prepareCurrentPreview(newVersion: Bool) {
        if workspace.prepareCurrentScriptPreview(targetDurationSeconds: scriptTargetSeconds, newVersion: newVersion) {
            sheet = .openAITransmission
        }
    }

    private func scriptCard(_ script: ScriptDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Version \(script.version) · \(script.status.scriptLabel)").font(.headline)
            Text("Zielzeit: \(Int(script.targetDurationSeconds)) Sekunden · \(script.createdAt.formatted())").font(.caption)
            Text("Evaluation: \(script.caseEvaluationID.rawValue.uuidString)").font(.caption).textSelection(.enabled)
            Text(scriptAuthor(script.author)).font(.caption)
            if case .ai(let provider, _) = script.author, script.status == .draft, !provider.value.hasPrefix("local-test") {
                Text("KI-Entwurf – ungeprüft").foregroundStyle(.orange)
            }
            if let review = script.approval {
                Text("Historisch freigegeben: \(graph.find(review.reviewerID)?.displayName.value ?? "Reviewer fehlt") · \(review.reviewedAt.formatted())").font(.caption)
            }
            ForEach(script.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }, id: \.id) { statement in
                scriptStatementRow(statement, script: script)
            }
            scriptLifecycleActions(script)
        }
    }

    private func scriptStatementRow(_ statement: ScriptStatement, script: ScriptDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(statement.position + 1). \(statement.kind.scriptLabel)").font(.subheadline)
            Text(statement.text.value).textSelection(.enabled)
            if let uncertainty = statement.uncertainty { Text("Unsicherheit: \(uncertainty.value)").foregroundStyle(.secondary) }
            if let review = statement.review {
                Text("Menschlich geprüft: \(graph.find(review.reviewerID)?.displayName.value ?? "Reviewer fehlt") · \(review.reviewedAt.formatted())").font(.caption)
            } else {
                Text("Ungeprüfter Satz").foregroundStyle(.orange)
                if (script.status == .draft || script.status == .needsReview), graph.find(script.caseEvaluationID)?.status == .approved {
                    Button("Statement prüfen") { workspace.reviewScriptStatement(statement.id) }
                }
            }
            scriptStatementSources(statement)
        }.padding(8)
    }

    private func scriptStatementSources(_ statement: ScriptStatement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(statement.excerptIDs, id: \.self) { id in
                if let excerpt = graph.find(id), let source = graph.find(excerpt.sourceVersionID) {
                    DisclosureGroup("\(source.title?.value ?? "Quellenfassung") · \(excerpt.locator.value)") {
                        HStack(alignment: .top, spacing: 16) {
                            Text(statement.text.value).frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(source.publisher?.value ?? "Herausgeber nicht erfasst")
                                Text("\(excerpt.locator.value) · \(excerpt.state.displayName)")
                                Text(excerpt.text.value).textSelection(.enabled)
                                Text(excerpt.context.value).font(.caption)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            ForEach(statement.evidenceLinkIDs, id: \.self) { id in
                if let link = graph.find(id) {
                    Text("Evidenz: \(link.relationship.displayName) · \(link.directness.displayName) · \(link.rationale.value)").font(.caption)
                }
            }
        }
    }

    @ViewBuilder private func scriptLifecycleActions(_ script: ScriptDraft) -> some View {
        if graph.find(script.caseEvaluationID)?.status == .approved {
            HStack {
                Button("Als neue Version bearbeiten") { sheet = .manualScript(script.caseEvaluationID, script.id) }
                if script.status == .draft {
                    Button("Skript zur Prüfung vorlegen") { workspace.submitScriptForReview(script.id) }
                } else if script.status == .needsReview {
                    Button("Skript freigeben") { workspace.approveScript(script.id) }
                }
            }
        } else {
            Text("Bewertung muss erneut geprüft werden").foregroundStyle(.orange)
        }
    }

    private func scriptAuthor(_ author: Authorship) -> String {
        switch author {
        case .human(let id): return "Manuell: \(graph.find(id)?.displayName.value ?? "Reviewer fehlt")"
        case .ai(let model, _): return "KI-/Provider-Herkunft: \(model.value)"
        case .system: return "System-Herkunft"
        }
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
            if politicalCase.workflowState == .readyForEvaluation && evaluations.isEmpty {
                Button(graph.caseRevisions.isEmpty ? "Neue Bewertung starten" : "Snapshot weiterbewerten") {
                    sheet = .manualEvaluation
                }
                Text("Methodik 1.0 · Kategorie und Evidenzsicherheit werden ausschließlich menschlich gewählt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
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
            evaluationDetails(evaluation)
            Text("Historischer Snapshot: \(evaluation.caseRevisionID.rawValue.uuidString)")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private func evaluationDetails(_ evaluation: CaseEvaluation) -> some View {
        Text("Methodik: \(graph.find(evaluation.methodologyVersionID)?.version.value ?? "Fehlt")")
        if let snapshot = graph.find(evaluation.caseRevisionID) {
            EvaluationSnapshotSummary(snapshot: snapshot, graph: graph)
        }
        assessmentTexts("Fakten", evaluation.facts)
        assessmentTexts("Interpretationen", evaluation.interpretations)
        assessmentTexts("Unsicherheiten", evaluation.uncertainties)
        Text("Nicht überprüfbar – Gründe: \(evaluation.notVerifiableReasons.map { $0.manualLabel }.joined(separator: ", "))")
            .font(.caption)
        ForEach(evaluation.criterionEvaluationIDs, id: \.self) { id in
            if let child = graph.find(id) { criterionEvaluationRow(child, parent: evaluation) }
        }
        ForEach(Array(workspace.evaluationWarnings(evaluation.id).enumerated()), id: \.offset) { entry in
            Label(entry.element, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        }
        if evaluation.status == .draft {
            Button("Bewertung zur Prüfung vorlegen") { workspace.submitEvaluationForReview(evaluation.id) }
        } else if evaluation.status == .needsReview {
            Button("Bewertung freigeben") { workspace.approveEvaluation(evaluation.id) }
            Text("Freigabe verlangt die separate menschliche Prüfung jedes Kriteriums.").font(.caption)
        } else if evaluation.status == .reviewRequired {
            Text("Erneute Prüfung erforderlich. Das historische Urteil und seine Freigabe bleiben erhalten; Ersatzreview folgt später.")
                .foregroundStyle(.orange)
        }
        if let approval = evaluation.approval {
            Text("Historische Freigabe: \(graph.find(approval.reviewerID)?.displayName.value ?? "Reviewer fehlt") · \(approval.reviewedAt.formatted())")
                .font(.caption)
        }
    }

    private func assessmentTexts(_ title: String, _ values: [NonEmptyText]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            ForEach(Array(values.enumerated()), id: \.offset) { entry in Text(entry.element.value) }
        }
    }

    private func criterionEvaluationRow(_ child: CriterionEvaluation, parent: CaseEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(graph.find(child.criterionRevisionID)?.goal.value ?? "Kriterium fehlt").font(.headline)
            Text("\(child.category.displayName) · \(child.confidence.displayName)")
            Text(child.rationale.value)
            assessmentTexts("Unsicherheiten", child.uncertainties)
            Text(child.notVerifiableReasons.map { $0.manualLabel }.joined(separator: ", "))
            ForEach(child.evidenceLinkIDs, id: \.self) { id in
                if let link = graph.find(id) {
                    Text("\(child.counterEvidenceLinkIDs.contains(id) ? "Gegenbeleg" : "Verwendeter Beleg"): \(link.relationship.displayName) · \(link.directness.displayName) · \(link.rationale.value)").font(.caption)
                }
            }
            if let review = child.review {
                Text("Menschlich geprüft: \(graph.find(review.reviewerID)?.displayName.value ?? "Fehlt") · \(review.reviewedAt.formatted())").font(.caption)
            } else {
                Text("Noch ungeprüft").font(.caption)
                if parent.status == .draft || parent.status == .needsReview {
                    Button("Kriteriumsbewertung prüfen") { workspace.reviewCriterionEvaluation(child.id) }
                }
            }
        }.padding(8)
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

private extension ScriptStatus {
    var scriptLabel: String {
        switch self {
        case .draft: return "Entwurf"
        case .needsReview: return "Zur Prüfung vorgelegt"
        case .approved: return "Freigegeben"
        case .superseded: return "Überholt (historisch erhalten)"
        }
    }
}
private extension ScriptStatementKind {
    var scriptLabel: String {
        switch self {
        case .fact: return "Tatsache"
        case .interpretation: return "Interpretation"
        case .question: return "Frage"
        case .qualification: return "Einschränkung"
        }
    }
}

struct ResearchDossierView: View {
    let dossier: DeepResearchRecordV1
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KI-Recherche – ungeprüft").font(.headline).foregroundStyle(.orange)
            Text("Recherchelauf abgeschlossen; Quellen, Kriterien und Evidenz nicht freigegeben.").font(.caption)
            Text(dossier.discovery.candidate.exactQuote).textSelection(.enabled)
            Text(dossier.result.originalSourceReview.context)
            criteriaAndCoverage
            developments
            evidenceCards
            assessments
            questionsAndSources
        }
    }
    private var criteriaAndCoverage: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorgeschlagene Kriterien und Suchabdeckung").font(.headline)
            ForEach(dossier.result.proposedCriteria, id: \.criterionKey) { criterion in
                Text(criterion.goal + " · Draft · " + (criterion.isCore ? "Kernkriterium" : "Teilbestandteil"))
                Text("Frist: " + (criterion.deadline ?? "unbekannt") + " · " + criterion.materialityRule).font(.caption)
            }
            ForEach(dossier.result.coverage, id: \.criterionKey) { coverage in
                Text(coverage.criterionKey + ": SUPPORT \(coverage.supportSearchPerformed ? "ausgeführt" : "fehlend") (\(coverage.supportSourceCount)), CONTRADICTION \(coverage.contradictionSearchPerformed ? "ausgeführt" : "fehlend") (\(coverage.contradictionSourceCount)), CONTEXT \(coverage.contextSearchPerformed ? "ausgeführt" : "fehlend") (\(coverage.contextSourceCount))").font(.caption)
                Text((coverage.blockedQueries + coverage.failedQueries + coverage.unresolvedQuestions).joined(separator: " · ")).foregroundStyle(.secondary)
            }
        }
    }
    private var developments: some View {
        VStack(alignment: .leading) {
            Text("Spätere Entwicklungen – ungeprüfte Action-Drafts").font(.headline)
            ForEach(dossier.result.developments, id: \.developmentKey) { development in
                Text(development.title + " · " + development.proceduralState)
                Text(development.description + " · Ereignis: " + (development.eventDate ?? "unbekannt")).font(.caption)
            }
        }
    }
    private var evidenceCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unterstützende Evidenz, Gegenbelege und Kontext – Drafts").font(.headline)
            ForEach(dossier.result.evidenceProposals, id: \.evidenceKey) { evidence in
                ResearchEvidenceCard(evidence: evidence, dossier: dossier)
            }
        }
    }
    private var assessments: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KI-Bewertungsvorschlag – noch keine freigegebene Bewertung").font(.headline)
            ForEach(dossier.result.criterionAssessmentDrafts, id: \.criterionKey) { assessment in
                Text(assessment.criterionKey + ": " + (assessment.suggestedCategory?.rawValue ?? "noRecommendation") + " · " + assessment.confidence.rawValue)
                Text(assessment.rationale)
                Text("Pro: " + assessment.supportingEvidenceKeys.joined(separator: ", ") + " · Contra: " + assessment.counterEvidenceKeys.joined(separator: ", ")).font(.caption)
                Text("KI-behauptete Fakten: " + assessment.facts.joined(separator: " · ")).font(.caption)
                Text("Interpretationen: " + assessment.interpretations.joined(separator: " · ")).font(.caption)
                Text((assessment.uncertainties + assessment.notVerifiableReasons.map { $0.rawValue }).joined(separator: " · ")).foregroundStyle(.secondary)
            }
            Text("Gesamtvorschlag: " + (dossier.result.overallAssessmentDraft.suggestedCategory?.rawValue ?? "noRecommendation") + " · " + dossier.result.overallAssessmentDraft.confidence.rawValue)
            Text(dossier.result.overallAssessmentDraft.rationale)
            Text((dossier.result.overallAssessmentDraft.uncertainties + dossier.result.overallAssessmentDraft.notVerifiableReasons.map { $0.rawValue }).joined(separator: " · ")).foregroundStyle(.secondary)
        }
    }
    private var questionsAndSources: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ungeklärte Fragen und Quellen").font(.headline)
            Text((dossier.result.uncertainties + dossier.result.originalSourceReview.uncertainties).joined(separator: " · "))
            ForEach(Array(dossier.result.issues.enumerated()), id: \.offset) { _, issue in Text(issue.laneID + ": " + issue.message).foregroundStyle(.orange) }
            ForEach(dossier.result.sources, id: \.claim.sourceKey) { source in
                if let url = URL(string: source.searchSource.url) {
                    Link(source.claim.title ?? source.searchSource.title ?? source.searchSource.domain, destination: url)
                    Text(source.category.rawValue + " · " + source.searchSource.url).font(.caption)
                }
            }
        }
    }
}
private struct ResearchEvidenceCard: View {
    let evidence: EvidenceProposal
    let dossier: DeepResearchRecordV1
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(evidence.relationship.rawValue + " · " + evidence.criterionKey + " · " + evidence.directness.rawValue).font(.headline)
            Text(evidence.rationale)
            Text("Zeitbezug (" + evidence.temporalRole.rawValue + "): " + (evidence.temporalDate ?? "unbekannt")).font(.caption)
            ForEach(dossier.result.excerpts.filter { evidence.excerptKeys.contains($0.excerptKey) }, id: \.excerptKey) { excerpt in
                Text(excerpt.text).textSelection(.enabled)
                Text(excerpt.locator + " · " + excerpt.context).font(.caption)
                if let source = dossier.result.sources.first(where: { $0.claim.sourceKey == excerpt.sourceKey }), let url = URL(string: source.searchSource.url) {
                    Link(source.claim.title ?? source.searchSource.domain, destination: url)
                    Text(source.searchSource.url).font(.caption)
                }
                Text(excerpt.uncertainties.joined(separator: " · ")).foregroundStyle(.secondary)
            }
            Text(evidence.uncertainties.joined(separator: " · ")).foregroundStyle(.secondary)
        }.padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ResearchReviewQueueView: View {
    @ObservedObject var workspace: CaseWorkspaceModel
    let plan: ResearchReviewPlan
    @State private var contextText = ""
    @State private var acknowledgeCounterEvidence = false
    @State private var explicitConfirmation = false
    @State private var checkedCriteria: Set<EntityID<CriterionEvaluation>> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recherche prüfen · KI-Review").font(.title2)
            Text("AI recherchiert. Mensch prüft die vorgeschlagenen Quellen und Schlussfolgerungen. Die App übernimmt geprüfte Inhalte ohne erneute manuelle Dateneingabe.").font(.caption)
            Text("\(plan.completedSteps)/6 Schritte · Original: \(label(plan.originalSource)) · Kriterien: \(plan.criteria.filter { $0.state == .reviewed }.count)/\(plan.criterionIDs.count) · Fundstellen: \(plan.excerptIDs.count)/\(plan.evidenceSources.count) · Evidenz: \(plan.evidenceIDs.count)/\(plan.evidence.count) · Bewertung: \(label(plan.assessment))").font(.caption)
            original
            criteria
            sources
            developments
            evidence
            assessment
        }.padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .onAppear { if contextText.isEmpty { contextText = plan.record.result.originalSourceReview.context } }
    }
    private func label(_ state: ResearchReviewItemState) -> String {
        switch state {
        case .open: return "offen"
        case .ready: return "bereit"
        case .reviewed: return "geprüft"
        case .notUsed: return "nicht verwendet"
        case .rejected: return "abgelehnt"
        case .blocked: return "blockiert"
        }
    }
    private var original: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("1. Originalaussage").font(.headline)
            Text(plan.record.discovery.candidate.exactQuote).textSelection(.enabled)
            Text("Sprecher: " + (plan.record.discovery.candidate.speakerName ?? "unbekannt") + " · Partei zum Aussagezeitpunkt: " + (plan.record.discovery.candidate.partyName ?? "unbekannt"))
            Text(plan.record.discovery.candidate.locator)
            Text("Aussagezeit: " + (plan.record.result.originalSourceReview.statementDate ?? "unbekannt"))
            Text(plan.record.result.originalSourceReview.context)
            Text(plan.record.result.originalSourceReview.uncertainties.joined(separator: " · ")).font(.caption)
            if let url = URL(string: plan.record.discovery.candidate.sourceURL) { Link(plan.record.discovery.candidate.sourceTitle ?? "Originalquelle", destination: url) }
            if let id = plan.originalExcerptID, plan.originalSource != .reviewed {
                HStack {
                    Button("Originalfundstelle geprüft") { workspace.performResearchReview(.excerpt(id, reject: false)) }
                        .disabled(workspace.selectedContext?.excerpts.contains { $0.id == id && $0.state == .rejected } == true || plan.originalSource == .ready)
                    Button("Originalfundstelle ablehnen") { workspace.performResearchReview(.excerpt(id, reject: true)) }.disabled(plan.originalSource == .ready)
                    Button("Originalzitat bestätigen und dokumentieren") { workspace.performResearchReview(.original) }.disabled(plan.originalSource != .ready)
                }
            }
        }
    }
    private var criteria: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("2. Prüfkriterien auswählen und bestätigen").font(.headline)
            ForEach(plan.record.result.proposedCriteria, id: \.criterionKey) { criterion in
                criterionReviewRow(for: criterion.criterionKey)
            }
            TextField("Prüfrahmen / Kontext prüfen oder korrigieren", text: $contextText, axis: .vertical)
            Text("Dieser Schritt bestätigt auch die Sprecherzuordnung anhand der geprüften Originalfundstelle und die ausdrücklich gewählten Kriterien.").font(.caption)
            Button("Prüfrahmen und gewählte Kriterien bestätigen") { workspace.performResearchReview(.frame(contextText)) }
                .disabled(workspace.selectedCase?.workflowState != .documented)
        }
    }
    private func criterionState(for key: String) -> ResearchReviewItemState {
        plan.criteria.first(where: { $0.key == key })?.state ?? .blocked
    }
    @ViewBuilder
    private func criterionReviewRow(for key: String) -> some View {
        if let criterion = plan.record.result.proposedCriteria.first(where: { $0.criterionKey == key }) {
            let state: ResearchReviewItemState = criterionState(for: key)
            let selectionDisabled: Bool = workspace.selectedCase?.workflowState != .documented || state == .notUsed
            let title: String = criterion.goal + " · " + label(state)
            let target: String = "Zielgruppe: \(criterion.targetGroup ?? "unbekannt") · Ausgangslage: \(criterion.baseline ?? "unbekannt")"
            let conditions: String = criterion.conditions?.joined(separator: "; ") ?? "unbekannt"
            let deadline: String = "Frist: \(criterion.deadline ?? "unbekannt") · Bedingungen: \(conditions)"
            let materiality: String = (criterion.isCore ? "Kernkriterium · " : "Teilbestandteil · ") + criterion.materialityRule
            let uncertainties: String = criterion.uncertainties.joined(separator: " · ")
            VStack(alignment: .leading) {
                Text(title)
                Text(target).font(.caption)
                Text(deadline).font(.caption)
                Text(materiality).font(.caption)
                Text(uncertainties).foregroundStyle(.secondary)
                HStack {
                    Button("Übernehmen") { workspace.performResearchReview(.criterion(key, use: true)) }
                    Button("Nicht verwenden") { workspace.performResearchReview(.criterion(key, use: false)) }
                }.disabled(selectionDisabled)
            }
        }
    }
    private var sources: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("3. Benötigte Fundstellen prüfen").font(.headline)
            Text("Unbenutzte Fundstellen können ungeprüft bleiben. Ablehnen bedeutet eine ausdrückliche fachliche Ablehnung.").font(.caption)
            ForEach(plan.record.result.excerpts, id: \.excerptKey) { excerpt in
                sourceReviewRow(for: excerpt.excerptKey)
            }
        }
    }
    private func excerptState(for key: String) -> ResearchReviewItemState {
        plan.evidenceSources.first(where: { $0.key == key })?.state ?? .blocked
    }
    private func evidenceUsage(for excerptKey: String) -> String {
        let keys: [String] = plan.record.result.evidenceProposals
            .filter { $0.excerptKeys.contains(excerptKey) }
            .map { $0.evidenceKey }
        return keys.joined(separator: ", ")
    }
    private func sourceLink(for sourceKey: String) -> (title: String, url: URL)? {
        guard let source = plan.record.result.sources.first(where: { $0.claim.sourceKey == sourceKey }),
              let url = URL(string: source.searchSource.url) else { return nil }
        return (source.claim.title ?? source.searchSource.url, url)
    }
    private func draftExcerptID(for key: String) -> EntityID<SourceExcerpt>? {
        guard let raw = plan.record.bindings?.excerpts[key] else { return nil }
        return EntityID<SourceExcerpt>(raw)
    }
    @ViewBuilder
    private func sourceReviewRow(for key: String) -> some View {
        if let excerpt = plan.record.result.excerpts.first(where: { $0.excerptKey == key }) {
            let state: ResearchReviewItemState = excerptState(for: key)
            let reviewDisabled: Bool = state != .ready
            let detail: String = "\(excerpt.locator) · \(excerpt.context) · Ereignis: \(excerpt.eventDate ?? "unbekannt")"
            let usage: String = "Verwendung: " + evidenceUsage(for: key)
            let uncertainties: String = excerpt.uncertainties.joined(separator: " · ")
            let stateLabel: String = label(state)
            let link = sourceLink(for: excerpt.sourceKey)
            let id: EntityID<SourceExcerpt>? = draftExcerptID(for: key)
            VStack(alignment: .leading) {
                Text(excerpt.text).textSelection(.enabled)
                Text(detail).font(.caption)
                Text(usage).font(.caption)
                Text(uncertainties).foregroundStyle(.secondary)
                if let link { Link(link.title, destination: link.url) }
                Text(stateLabel)
                if let id {
                    HStack {
                        Button("Fundstelle geprüft") { workspace.performResearchReview(.excerpt(id, reject: false)) }
                        Button("Fundstelle ablehnen") { workspace.performResearchReview(.excerpt(id, reject: true)) }
                    }.disabled(reviewDisabled)
                }
            }
        }
    }
    private var developments: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("4. Entwicklungen").font(.headline)
            ForEach(plan.record.result.developments, id: \.developmentKey) { development in
                ResearchDevelopmentReviewCard(workspace: workspace, development: development,
                    state: plan.developments.first { $0.key == development.developmentKey }?.state ?? .blocked)

            }
        }
    }
    private var evidence: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("5. Evidenzzuordnung").font(.headline)
            ForEach(plan.record.result.evidenceProposals, id: \.evidenceKey) { proposal in
                ResearchEvidenceCard(evidence: proposal, dossier: plan.record)
                Text("Geprüfte Fundstellen: " + proposal.excerptKeys.compactMap { plan.excerptIDs[$0]?.rawValue.uuidString }.joined(separator: ", ")).font(.caption)
                if let key = proposal.developmentKey { Text("Geprüfte Entwicklung: " + (plan.actionIDs[key]?.rawValue.uuidString ?? "noch ungeprüft")).font(.caption) }
                HStack {
                    Button("Evidenz geprüft & übernehmen") { workspace.performResearchReview(.evidence(proposal.evidenceKey, use: true)) }
                        .disabled(plan.evidence.first { $0.key == proposal.evidenceKey }?.state != .ready)
                    Button("Evidenz nicht verwenden") { workspace.performResearchReview(.evidence(proposal.evidenceKey, use: false)) }
                        .disabled(plan.evidence.first { $0.key == proposal.evidenceKey }?.state == .reviewed || plan.evidence.first { $0.key == proposal.evidenceKey }?.state == .notUsed)
                }
                Text(label(plan.evidence.first { $0.key == proposal.evidenceKey }?.state ?? .blocked))
            }
        }
    }
    private var assessment: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("6. KI-Bewertungsvorschlag – menschliche Prüfung erforderlich").font(.headline)
            Text("Bewertungsstichtag: " + plan.record.researchCutoff.formatted(date: .numeric, time: .shortened))
            Text("Gesamt: " + (plan.record.result.overallAssessmentDraft.suggestedCategory?.rawValue ?? "KI gibt keine belastbare Empfehlung."))
            Text(plan.record.result.overallAssessmentDraft.rationale)
            ForEach(plan.record.result.criterionAssessmentDrafts, id: \.criterionKey) { row in
                Text(row.criterionKey + " · " + (row.suggestedCategory?.rawValue ?? "Keine belastbare Empfehlung") + " · " + row.confidence.rawValue)
                Text(row.rationale)
                Text("Pro: " + row.supportingEvidenceKeys.joined(separator: ", ") + " · Contra: " + row.counterEvidenceKeys.joined(separator: ", ")).font(.caption)
                Text((row.uncertainties + row.notVerifiableReasons.map { $0.rawValue }).joined(separator: " · ")).font(.caption)
            }
            ForEach(Array(plan.blockingIssues.enumerated()), id: \.offset) { _, blocker in Text(blocker).foregroundStyle(.orange) }
            ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in Text(warning).foregroundStyle(.orange) }
            if !plan.warnings.isEmpty { Toggle("Nicht übernommene Gegenbelege bewusst geprüft", isOn: $acknowledgeCounterEvidence) }
            if let evaluation = workspace.selectedContext?.caseEvaluations.last {
                evaluationReview(evaluation)
            } else {
                Button("Bewertungsentwurf mit angezeigtem Stichtag übernehmen") { workspace.performResearchReview(.assessment(acknowledgeOmittedCounterEvidence: acknowledgeCounterEvidence)) }
                    .disabled(plan.assessment != .ready || (!plan.warnings.isEmpty && !acknowledgeCounterEvidence))
                Text("Keine automatische Freigabe. Manueller Bewertungseditor bleibt verfügbar.").font(.caption)
            }
        }
    }
    private func evaluationReview(_ evaluation: CaseEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(evaluation.status == .approved ? "Menschlich freigegeben – Skript erzeugen ist im bestehenden Skriptbereich verfügbar." : "Menschlicher Bewertungsentwurf")
            Text(evaluation.rationale.value)
            ForEach(workspace.selectedContext?.criterionEvaluations.filter { $0.caseEvaluationID == evaluation.id } ?? [], id: \.id) { child in
                Text(child.rationale.value + " · " + child.category.displayName)
                Text("Pro: " + child.evidenceLinkIDs.map { $0.rawValue.uuidString }.joined(separator: ", ") + " · Contra: " + child.counterEvidenceLinkIDs.map { $0.rawValue.uuidString }.joined(separator: ", ")).font(.caption)
                Text(child.uncertainties.map { $0.value }.joined(separator: " · ")).font(.caption)
                Toggle("Diese Kriteriumsbewertung geprüft", isOn: Binding(get: { checkedCriteria.contains(child.id) }, set: { value in
                    if value { checkedCriteria.insert(child.id) } else { checkedCriteria.remove(child.id) }
                })).disabled(evaluation.status != .draft)
            }
            if evaluation.status == .draft {
                Toggle("Ich habe Originalquelle, verwendete Belege, Gegenbelege, Unsicherheiten und alle Kriteriumsbewertungen geprüft.", isOn: $explicitConfirmation)
                Button("Bewertung vollständig geprüft und freigeben") {
                    workspace.performResearchReview(.approval(evaluation.id, checked: checkedCriteria, confirmation: explicitConfirmation, acknowledgeOmittedCounterEvidence: acknowledgeCounterEvidence))
                }.disabled(!explicitConfirmation || checkedCriteria != Set(evaluation.criterionEvaluationIDs) || (!plan.warnings.isEmpty && !acknowledgeCounterEvidence))
            }
        }
    }
}

private struct ResearchDevelopmentReviewCard: View {
    @ObservedObject var workspace: CaseWorkspaceModel
    let development: ProposedDevelopment
    let state: ResearchReviewItemState
    @State private var scope = ""
    @State private var eventDate = ""
    var body: some View {
        VStack(alignment: .leading) {
            Text(development.title + " · " + development.type.rawValue + " · " + development.proceduralState)
            Text(development.description)
            Text("Fundstellen: " + development.excerptKeys.joined(separator: ", ")).font(.caption)
            Text(development.uncertainties.joined(separator: " · "))
            TextField("Geprüfter Umfang – fehlende Angaben ergänzen", text: $scope)
            TextField("Geprüftes Ereignisdatum: JJJJ, JJJJ-MM oder JJJJ-MM-TT", text: $eventDate)
            HStack {
                Button("Übernehmen und prüfen") { workspace.performResearchReview(.correctedDevelopment(development.developmentKey, scope: scope, eventDate: eventDate)) }
                    .disabled(state != .ready || scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || eventDate.isEmpty)
                Button("Nicht verwenden") { workspace.performResearchReview(.development(development.developmentKey, use: false)) }
                    .disabled(state == .reviewed || state == .notUsed)
            }
            Text(state == .reviewed ? "menschlich geprüft" : state == .notUsed ? "nicht verwendet" : "Fundstellen und Handlungsfelder prüfen")
        }.onAppear { scope = development.scope ?? ""; eventDate = development.eventDate ?? "" }
    }
}

@MainActor private struct ScriptReviewQueueView: View {
    @ObservedObject var workspace: CaseWorkspaceModel
    let plan: ScriptReviewPlan
    @State private var selected: Set<EntityID<ScriptStatement>> = []
    @State private var confirmed = false
    private var editable: Bool { plan.scriptStatus == .draft || plan.scriptStatus == .needsReview }
    private var originLabel: String {
        guard let id = plan.scriptID, let script = workspace.selectedContext?.find(id) else { return "Skript" }
        if case .ai = script.author { return "KI-Skript" }
        return "Manuelles Skript"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Skript prüfen").font(.headline)
            Text("\(originLabel): \(plan.scriptStatus?.scriptLabel ?? "Status fehlt") · \(plan.reviewedCount)/\(plan.totalCount) Sätze menschlich geprüft · Version \(plan.scriptVersion ?? 0)")
            ForEach(plan.statementItems, id: \.statementID) { item in
                ScriptReviewStatementRow(item: item, editable: editable, selected: selection(item.statementID))
            }
            ForEach(Array(plan.blockingIssues.enumerated()), id: \.offset) { entry in
                Text(WorkspaceErrorMessage.describe(entry.element)).foregroundStyle(.orange)
            }
            if editable, let scriptID = plan.scriptID {
                Button("Markierte Sätze als geprüft übernehmen") {
                    if workspace.reviewScriptStatements(scriptID: scriptID, selected: selected) { selected.removeAll() }
                }.disabled(selected.isEmpty || workspace.isGeneratingScript || !plan.blockingIssues.isEmpty)
                if plan.readyForApproval {
                    Text("Alle \(plan.totalCount) Sätze menschlich geprüft.")
                    Toggle("Ich habe Fakten, Quellen, Interpretationen und Unsicherheiten geprüft.", isOn: $confirmed)
                    Button("Skript freigeben") {
                        workspace.approveReviewedScript(scriptID, explicitConfirmation: confirmed)
                    }.buttonStyle(.borderedProminent).disabled(!confirmed || workspace.isGeneratingScript)
                }
            }
        }.onChange(of: plan.readyForApproval) { _, _ in confirmed = false }
    }

    private func selection(_ id: EntityID<ScriptStatement>) -> Binding<Bool> {
        Binding(get: { selected.contains(id) }, set: { value in
            if value { selected.insert(id) } else { selected.remove(id) }
        })
    }
}

private struct ScriptReviewStatementRow: View {
    let item: ScriptReviewItem
    let editable: Bool
    @Binding var selected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(item.position + 1). \(item.kind.scriptLabel)").font(.headline)
            Text(item.text).textSelection(.enabled)
            if let uncertainty = item.uncertainty { Text("Unsicherheit: \(uncertainty)").foregroundStyle(.secondary) }
            ForEach(item.sourceSummaries, id: \.excerptID) { source in
                ScriptReviewSourceView(source: source)
            }
            if item.reviewState == .reviewed {
                Label("Menschlich geprüft", systemImage: "checkmark.circle")
            } else if editable {
                Toggle("Satz geprüft – Auswahl vor Übernahme", isOn: $selected)
            } else { Text("Nicht menschlich geprüft").foregroundStyle(.orange) }
        }.padding(10).background(Color.secondary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ScriptReviewSourceView: View {
    let source: ScriptReviewSourceSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(source.title ?? "Quellentitel nicht erfasst").font(.subheadline)
            Text(source.publisher ?? "Herausgeber nicht erfasst").font(.caption)
            if let url = source.url { Link(url.absoluteString, destination: url) }
            else { Text("URL nicht erfasst").font(.caption) }
            Text("Fundstelle: \(source.locator)").font(.caption)
            Text(source.exactExcerptText).textSelection(.enabled)
            ForEach(Array(source.relationships.enumerated()), id: \.offset) { entry in
                Text("Evidenzbeziehung: \(entry.element.displayName)").font(.caption)
            }
        }.padding(.leading, 8)
    }
}

private struct VideoHandoffPreview: View {
    let handoff: VideoScriptHandoffV1
    private var factCount: Int { handoff.scenes.filter { $0.kind == .fact && !$0.sourceOverlays.isEmpty }.count }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bereit für Video", systemImage: "checkmark.circle").font(.headline)
            Text("\(handoff.scenes.count) Szenen · geplante Länge: \(Int(handoff.targetDurationSeconds)) s · \(factCount) Fakten-Szenen mit Quellenhinweis")
            Text("Video-Pipeline folgt in Phase 6. Dauern sind Planwerte, keine gemessene Sprechdauer.").font(.caption)
            DisclosureGroup("Video-Vorschau") {
                ForEach(handoff.scenes, id: \.statementID) { scene in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Szene \(scene.position + 1) · \(scene.kind.scriptLabel) · geplante Dauer: \(scene.estimatedDurationSeconds, specifier: "%.1f") s").font(.headline)
                        Text(scene.narrationText)
                        if let uncertainty = scene.uncertainty { Text("Unsicherheit: \(uncertainty)").font(.caption) }
                        ForEach(scene.sourceOverlays, id: \.excerptID) { overlay in
                            Text("\(overlay.sourceTitle ?? "Titel nicht erfasst") · \(overlay.locator)").font(.caption)
                        }
                    }.padding(.vertical, 6)
                }
            }
        }
    }
}
