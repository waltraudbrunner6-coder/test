import SwiftUI
import PoliticalFactCheckAppModel
import PoliticalFactCheckCore

struct NewCaseSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var quote = ""
    @State private var thesis = ""
    @State private var speaker = ""
    @State private var party = ""
    @State private var statementDate = ""
    @State private var dateError: String?

    var body: some View {
        Form {
            TextField("Arbeitstitel", text: $title)
            TextField("Sprechername", text: $speaker)
            TextField("Partei / Organisation", text: $party)
            TextField("Aussagezeitpunkt (optional, JJJJ-MM-TT)", text: $statementDate)
            TextField("Originalaussage", text: $quote, axis: .vertical).lineLimit(3...7)
            TextField("Prüfthese", text: $thesis, axis: .vertical).lineLimit(2...5)
            Text("Alle Angaben beginnen ungeprüft. Für eine Fundstelle kannst du nach dem Anlegen eine Quelle erfassen.")
                .font(.caption).foregroundStyle(.secondary)
            if let dateError { Text(dateError).foregroundStyle(.red) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Entwurf anlegen") {
                    guard let date = parseOptionalDate(statementDate) else {
                        if !statementDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            dateError = "Verwende das Datumsformat JJJJ-MM-TT."
                            return
                        }
                        dateError = nil
                        if workspace.createDraftCase(title: title, quote: quote, thesis: thesis,
                            speakerName: speaker, partyName: party, statementDate: nil) != nil { dismiss() }
                        return
                    }
                    dateError = nil
                    if workspace.createDraftCase(title: title, quote: quote, thesis: thesis,
                        speakerName: speaker, partyName: party, statementDate: date) != nil { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 520)
        .environment(\.locale, Locale(identifier: "de_AT"))
    }
}

struct NewCriterionSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    let caseID: EntityID<PoliticalFactCheckCore.Case>
    @State private var goal = ""
    @State private var targetGroup = ""
    @State private var deadline = ""
    @State private var isCore = true
    @State private var materiality = ""
    @State private var validationMessage: String?

    var body: some View {
        Form {
            TextField("Zielzustand", text: $goal, axis: .vertical).lineLimit(2...4)
            TextField("Zielgruppe / Umfang", text: $targetGroup)
            TextField("Frist (optional, JJJJ-MM-TT)", text: $deadline)
            Toggle("Kernkriterium", isOn: $isCore)
            TextField("Materialitätsregel", text: $materiality, axis: .vertical).lineLimit(2...4)
            Text("Das Kriterium wird als Draft gespeichert und muss vor einer Bewertung menschlich bestätigt werden.")
                .font(.caption).foregroundStyle(.secondary)
            if let validationMessage { Text(validationMessage).foregroundStyle(.red) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Draft anlegen") {
                    let parsed = parseOptionalDate(deadline)
                    if !deadline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsed == nil {
                        validationMessage = "Verwende das Datumsformat JJJJ-MM-TT."
                        return
                    }
                    validationMessage = nil
                    if workspace.addCriterionDraft(caseID: caseID, goal: goal, targetGroup: targetGroup,
                        deadline: parsed, isCore: isCore, materialityRule: materiality) != nil { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 500)
    }
}

struct NewSourceSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    let caseID: EntityID<PoliticalFactCheckCore.Case>
    @State private var url = ""
    @State private var documentID = ""
    @State private var title = ""
    @State private var publisher = ""
    @State private var publicationDate = ""
    @State private var locator = ""
    @State private var excerpt = ""
    @State private var context = ""
    @State private var language = "de"
    @State private var validationMessage: String?

    var body: some View {
        Form {
            TextField("URL (optional)", text: $url)
            TextField("Dokumentkennung (optional)", text: $documentID)
            TextField("Titel", text: $title)
            TextField("Herausgeber (optional)", text: $publisher)
            TextField("Publikationsdatum (optional, JJJJ-MM-TT)", text: $publicationDate)
            TextField("Fundstelle (Seite, Absatz, Artikel …)", text: $locator)
            TextField("Textauszug", text: $excerpt, axis: .vertical).lineLimit(3...7)
            TextField("Kontext", text: $context, axis: .vertical).lineLimit(2...5)
            TextField("Sprache", text: $language)
            Text("Die URL wird nur gespeichert; es erfolgt kein Abruf. Neue Fundstellen beginnen ungeprüft.")
                .font(.caption).foregroundStyle(.secondary)
            if let validationMessage { Text(validationMessage).foregroundStyle(.red) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Quelle speichern") {
                    let date = parseOptionalDate(publicationDate)
                    if !publicationDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && date == nil {
                        validationMessage = "Verwende für das Publikationsdatum JJJJ-MM-TT."
                        return
                    }
                    validationMessage = nil
                    if workspace.addSource(caseID: caseID, urlText: url, documentIdentifier: documentID,
                        title: title, publisher: publisher, publicationDate: date, locator: locator,
                        excerptText: excerpt, excerptContext: context, language: language) { dismiss() }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(20).frame(width: 560)
    }
}

struct ReviewerSettingsSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        Form {
            TextField("Name des Prüfers", text: $name)
            Text("Diese lokale Identität kennzeichnet menschliche Prüfungen. Es gibt kein Benutzerkonto.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Speichern") {
                    workspace.reviewerName = name
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 420)
        .onAppear { name = workspace.reviewerName }
    }
}

private func parseOptionalDate(_ value: String) -> Date? {
    let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !clean.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    return formatter.date(from: clean)
}

#Preview("New case") {
    NewCaseSheet().environmentObject(CaseWorkspaceModel(startupError: "Preview only"))
}

struct NewActionSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var typeIndex = 0
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = ""
    @State private var proceduralState = ""
    @State private var scope = ""
    @State private var institution = ""
    @State private var identifier = ""
    @State private var excerpts: Set<EntityID<SourceExcerpt>> = []
    @State private var dateError: String?
    private let types: [ActionType] = [.vote, .initiative, .resolution, .implementation, .development, .other]

    var body: some View {
        ScrollView {
            Form {
                fields
                if let graph = workspace.selectedContext {
                    ExcerptSelection(graph: graph, options: graph.excerpts, selected: $excerpts)
                }
                Text("Beschreibung, Ereignisdatum und Bereich beginnen ungeprüft. Keine automatische Akteurszurechnung.")
                    .font(.caption).foregroundStyle(.secondary)
                if let dateError { Text(dateError).foregroundStyle(.red) }
                WorkspaceFormError()
                HStack {
                    Button("Abbrechen") { dismiss() }
                    Spacer()
                    Button("Handlung speichern", action: save).keyboardShortcut(.defaultAction)
                }
            }.padding(20)
        }.frame(width: 600, height: 650)
    }

    private var fields: some View {
        Group {
            Picker("Typ", selection: $typeIndex) {
                ForEach(types.indices, id: \.self) { index in Text(types[index].displayName).tag(index) }
            }
            TextField("Titel", text: $title)
            TextField("Beschreibung", text: $description, axis: .vertical).lineLimit(2...5)
            TextField("Ereignisdatum (JJJJ-MM-TT)", text: $eventDate)
            TextField("Verfahrens-/Umsetzungsstatus", text: $proceduralState)
            TextField("Geltungs-/Zielbereich", text: $scope)
            TextField("Institutionelle Ebene (optional)", text: $institution)
            TextField("Objektkennung (optional)", text: $identifier)
        }
    }

    private func save() {
        guard let date = parseOptionalDate(eventDate), let dated = try? manualDay(date, role: .event) else {
            dateError = "Gib ein Ereignisdatum im Format JJJJ-MM-TT ein."
            return
        }
        dateError = nil
        if workspace.addAction(type: types[typeIndex], title: title, description: description, eventDate: dated,
            proceduralState: proceduralState, scope: scope, institutionalLevel: institution,
            objectIdentifier: identifier, excerptIDs: orderedExcerpts(excerpts, in: workspace.selectedContext)) != nil { dismiss() }
    }
}

struct ActionReviewSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    let revisionID: EntityID<ActionRevision>
    @State private var excerpts: Set<EntityID<SourceExcerpt>> = []

    var body: some View {
        ScrollView {
            Form {
                if let graph = workspace.selectedContext, let revision = graph.find(revisionID) {
                    Text(revision.title.value).font(.headline)
                    Text(revision.description.content.knownValue?.value ?? "Unbekannt")
                    Text("Bereich: \(revision.scope.content.knownValue?.value ?? "Unbekannt")")
                    if let date = revision.eventDate.content.knownValue?.content.knownValue?.start {
                        Text("Ereignisdatum: \(date.formatted(date: .abbreviated, time: .omitted))")
                    }
                    Text("Bestätige anhand der ausgewählten Fundstellen Beschreibung, Ereignisdatum und Geltungsbereich. Die alte Revision bleibt erhalten.")
                    ExcerptSelection(graph: graph, options: workspace.verifiedExcerpts, selected: $excerpts)
                    WorkspaceFormError()
                    HStack {
                        Button("Abbrechen") { dismiss() }
                        Spacer()
                        Button("Handlung menschlich prüfen") {
                            if workspace.verifyAction(revisionID, excerptIDs: orderedExcerpts(excerpts, in: graph)) { dismiss() }
                        }.disabled(excerpts.isEmpty)
                    }
                } else {
                    Text("Die Handlungsrevision ist nicht mehr verfügbar.")
                    Button("Schließen") { dismiss() }
                }
            }.padding(20)
        }.frame(width: 600, height: 500)
    }
}

struct NewEvidenceSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var criterionID: EntityID<CriterionRevision>?
    @State private var actionID: EntityID<ActionRevision>?
    @State private var excerpts: Set<EntityID<SourceExcerpt>> = []
    @State private var relationshipIndex = 0
    @State private var directnessIndex = 0
    @State private var temporalIndex = 0
    @State private var rationale = ""
    @State private var date = ""
    @State private var endDate = ""
    @State private var dateError: String?
    private let relationships: [EvidenceRelationship] = [.supports, .contradicts, .contextualizes]
    private let directness: [EvidenceDirectness] = [.direct, .indirect]

    var body: some View {
        ScrollView {
            Form {
                criteriaAndAction
                classification
                TextField("Fachliche Begründung", text: $rationale, axis: .vertical).lineLimit(2...5)
                temporalFields
                if let graph = workspace.selectedContext {
                    ExcerptSelection(graph: graph, options: workspace.verifiedExcerpts, selected: $excerpts)
                }
                Text("Die Verknüpfung beginnt als Draft. Beziehung und Direktheit sind keine Bewertungskategorie. Die menschliche Prüfung erfolgt anschließend separat.")
                    .font(.caption).foregroundStyle(.secondary)
                if let dateError { Text(dateError).foregroundStyle(.red) }
                WorkspaceFormError()
                HStack {
                    Button("Abbrechen") { dismiss() }
                    Spacer()
                    Button("Evidenz-Draft speichern", action: save)
                        .disabled(criterionID == nil || excerpts.isEmpty).keyboardShortcut(.defaultAction)
                }
            }.padding(20)
        }.frame(width: 620, height: 660)
    }

    private var criteriaAndAction: some View {
        Group {
            Picker("Bestätigtes Kriterium", selection: $criterionID) {
                Text("Bitte auswählen").tag(nil as EntityID<CriterionRevision>?)
                ForEach(workspace.confirmedCriteria, id: \.id) { criterion in
                    Text(criterion.goal.value).tag(Optional(criterion.id))
                }
            }
            Picker("Handlungsrevision (optional)", selection: $actionID) {
                Text("Keine Handlung").tag(nil as EntityID<ActionRevision>?)
                if let graph = workspace.selectedContext {
                    ForEach(graph.actionRevisions, id: \.id) { action in
                        Text("\(action.title.value) · Revision \(action.metadata.number)").tag(Optional(action.id))
                    }
                }
            }
        }
    }

    private var classification: some View {
        Group {
            Picker("Beziehung", selection: $relationshipIndex) {
                Text("stützt").tag(0)
                Text("widerspricht").tag(1)
                Text("kontextualisiert").tag(2)
            }
            Picker("Direktheit", selection: $directnessIndex) {
                Text("direkt").tag(0)
                Text("indirekt").tag(1)
            }
        }
    }

    private var temporalFields: some View {
        Group {
            Picker("Zeitlicher Bezug", selection: $temporalIndex) {
                Text("Ereignisdatum").tag(0)
                Text("Gültigkeitszeitraum").tag(1)
            }
            TextField(temporalIndex == 0 ? "Ereignisdatum (JJJJ-MM-TT)" : "Beginn (JJJJ-MM-TT)", text: $date)
            if temporalIndex == 1 { TextField("Ende, einschließlich (JJJJ-MM-TT)", text: $endDate) }
            Text("Nicht das Publikationsdatum der Quelle verwenden.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard let criterionID, let start = parseOptionalDate(date) else {
            dateError = "Wähle ein Kriterium und gib ein gültiges Bezugsdatum ein."
            return
        }
        do {
            let temporal: DatedValue
            if temporalIndex == 0 {
                temporal = try manualDay(start, role: .event)
            } else {
                guard let end = parseOptionalDate(endDate), end >= start else {
                    dateError = "Gib ein gültiges Ende ab dem Beginn des Zeitraums ein."
                    return
                }
                let interval = try PoliticalFactCheckCore.DateInterval(start: start, end: end.addingTimeInterval(86_400))
                temporal = try DatedValue(role: .validity, precision: .interval, content: .known(interval), timeZoneIdentifier: "UTC")
            }
            dateError = nil
            if workspace.addEvidenceDraft(criterionRevisionID: criterionID,
                excerptIDs: orderedExcerpts(excerpts, in: workspace.selectedContext), actionRevisionID: actionID,
                relationship: relationships[relationshipIndex], directness: directness[directnessIndex],
                rationale: rationale, temporalReference: temporal) != nil { dismiss() }
        } catch { dateError = "Das Datum oder der Zeitraum ist ungültig." }
    }
}

private struct ExcerptSelection: View {
    let graph: DomainContext
    let options: [SourceExcerpt]
    @Binding var selected: Set<EntityID<SourceExcerpt>>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vorhandene Fundstellen auswählen").font(.headline)
            if options.isEmpty { Text("Keine geeigneten Fundstellen vorhanden.").foregroundStyle(.secondary) }
            ForEach(options, id: \.id) { excerpt in
                Toggle(isOn: Binding(get: { selected.contains(excerpt.id) }, set: { checked in
                    if checked { selected.insert(excerpt.id) } else { selected.remove(excerpt.id) }
                })) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sourceLabel(excerpt)).font(.caption)
                        Text("\(excerpt.locator.value) · \(status(excerpt))").font(.caption)
                        Text(excerpt.text.value).textSelection(.enabled)
                    }
                }.toggleStyle(.checkbox)
            }
        }
    }

    private func sourceLabel(_ excerpt: SourceExcerpt) -> String {
        guard let version = graph.find(excerpt.sourceVersionID), let source = graph.find(version.sourceID) else { return "Quelle nicht verfügbar" }
        return version.title?.value ?? source.canonicalURL?.absoluteString ?? source.documentIdentifier?.value ?? "Gespeicherte Quelle"
    }

    private func status(_ excerpt: SourceExcerpt) -> String {
        switch excerpt.state {
        case .unverified: "ungeprüft"
        case .verified: "geprüft"
        case .rejected: "abgelehnt"
        case .superseded: "überholt"
        }
    }
}

private struct WorkspaceFormError: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    var body: some View {
        if let message = workspace.errorMessage { Text(message).foregroundStyle(.red) }
    }
}

private func manualDay(_ date: Date, role: DateRole) throws -> DatedValue {
    try DatedValue(role: role, precision: .day,
        content: .known(PoliticalFactCheckCore.DateInterval(start: date, end: date.addingTimeInterval(86_400))),
        timeZoneIdentifier: "UTC")
}

private func orderedExcerpts(_ selected: Set<EntityID<SourceExcerpt>>, in graph: DomainContext?) -> [EntityID<SourceExcerpt>] {
    graph?.excerpts.filter { selected.contains($0.id) }.map(\.id) ?? []
}

extension ActionType {
    var displayName: String {
        switch self {
        case .vote: "Abstimmung"
        case .initiative: "Initiative"
        case .resolution: "Beschluss"
        case .implementation: "Umsetzung"
        case .development: "Entwicklung"
        case .other: "Sonstiges"
        }
    }
}

struct PromiseReadinessSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var contextText = ""
    @State private var contextExcerpts: Set<EntityID<SourceExcerpt>> = []
    @State private var speakerExcerpts: Set<EntityID<SourceExcerpt>> = []

    var body: some View {
        ScrollView {
            Form {
                Text("Prüfrahmen bestätigen").font(.headline)
                TextField("Konkreter Kontext", text: $contextText, axis: .vertical).lineLimit(3...6)
                contextSelection
                speakerSelection
                Text("Die Prüfung erzeugt eine neue PromiseRevision. Alle aktiven Kriterien werden neu angebunden und müssen erneut menschlich bestätigt werden. Vorhandene Evidenz bleibt an ihrer bisherigen Kriterienrevision; sie wird nicht automatisch neu zugeordnet.")
                    .font(.caption).foregroundStyle(.secondary)
                WorkspaceFormError()
                HStack {
                    Button("Abbrechen") { dismiss() }
                    Spacer()
                    Button("Kontext und Sprecher menschlich bestätigen", action: confirm)
                        .disabled(contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || contextExcerpts.isEmpty || speakerExcerpts.isEmpty)
                }
            }.padding(20)
        }.frame(width: 640, height: 660)
        .onAppear {
            if let graph = workspace.selectedContext, let politicalCase = workspace.selectedCase {
                contextText = graph.find(politicalCase.currentPromiseRevisionID)?.context.content.knownValue?.value ?? ""
            }
        }
    }

    @ViewBuilder private var contextSelection: some View {
        if let graph = workspace.selectedContext {
            Text("Fundstellen für den Kontext").font(.headline)
            ExcerptSelection(graph: graph, options: workspace.verifiedExcerpts, selected: $contextExcerpts)
        }
    }

    @ViewBuilder private var speakerSelection: some View {
        if let graph = workspace.selectedContext, let politicalCase = workspace.selectedCase,
           let revision = graph.find(politicalCase.currentPromiseRevisionID),
           let id = revision.speaker.content.knownValue, let actor = graph.find(id) {
            Text("Sprecherzuordnung: \(actor.name.value)").font(.headline)
            Text("Wähle ausdrücklich die Fundstellen, die diesen bestehenden Sprecher belegen. Die Partei wird damit nicht verifiziert.")
                .font(.caption).foregroundStyle(.secondary)
            ExcerptSelection(graph: graph, options: workspace.verifiedExcerpts, selected: $speakerExcerpts)
        } else {
            Text("Kein bestehender Sprecher-Akteur verfügbar.").foregroundStyle(.red)
        }
    }

    private func confirm() {
        if workspace.verifyPromiseForEvaluationReadiness(contextText: contextText,
            contextExcerptIDs: orderedExcerpts(contextExcerpts, in: workspace.selectedContext),
            speakerExcerptIDs: orderedExcerpts(speakerExcerpts, in: workspace.selectedContext)) { dismiss() }
    }
}

// Local form state is not a second domain model. All choices start explicitly unset.
private struct AssessmentFormState {
    var categoryIndex = -1
    var confidenceIndex = -1
    var rationale = ""
    var uncertainties = ""
    var reasons: Set<Int> = []
    func domain() throws -> ManualAssessment {
        guard evaluationCategories.indices.contains(categoryIndex), confidenceValues.indices.contains(confidenceIndex) else {
            throw EvaluationFormError.explicitChoicesRequired
        }
        return try ManualAssessment(category: evaluationCategories[categoryIndex], rationale: NonEmptyText(rationale),
            confidence: confidenceValues[confidenceIndex], uncertainties: assessmentLines(uncertainties),
            notVerifiableReasons: notVerifiableReasons.enumerated().filter { reasons.contains($0.offset) }.map { $0.element })
    }
}
private struct CriterionFormState: Identifiable {
    let id: EntityID<CriterionRevision>
    var assessment = AssessmentFormState()
    var evidence: Set<EntityID<EvidenceLink>> = []
    var counterEvidence: Set<EntityID<EvidenceLink>> = []
}
private enum EvaluationFormError: Error { case explicitChoicesRequired }
private let evaluationCategories: [EvaluationCategory] = [.fulfilled, .mostlyFulfilled, .partiallyFulfilled, .notFulfilled, .contraryAction, .notVerifiable]
private let confidenceValues: [EvidenceConfidence] = [.high, .medium, .low]
private let notVerifiableReasons: [NotVerifiableReason] = [.unclearPromise, .openDeadline, .conditionNotMet, .missingEvidence, .unclearAttribution, .conflictingSources, .researchBlocked]
private func assessmentLines(_ value: String) throws -> [NonEmptyText] {
    try value.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }.map { try NonEmptyText($0) }
}

struct ManualEvaluationSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var cutoffText = ""
    @State private var cutoff: DatedValue?
    @State private var snapshotID: EntityID<CaseRevision>?
    @State private var criteria: [CriterionFormState] = []
    @State private var overall = AssessmentFormState()
    @State private var facts = ""
    @State private var interpretations = ""
    @State private var formError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Manuelle Bewertung · Methodik 1.0").font(.title2)
                Text("Kein automatisches Urteil. Materialität, Zurechnung und Gesamturteil entscheidet der Mensch.")
                if let snapshotID, let graph = workspace.selectedContext, let snapshot = graph.find(snapshotID) {
                    Text("Bewertungsstichtag: \(cutoffText) (UTC)").font(.headline)
                    EvaluationSnapshotSummary(snapshot: snapshot, graph: graph)
                    criterionEditors(snapshot, graph: graph)
                    overallEditor
                    Button("Bewertungsentwurf speichern", action: saveDraft).buttonStyle(.borderedProminent)
                } else {
                    startEditor
                }
                if let formError { Text(formError).foregroundStyle(.red) }
                WorkspaceFormError()
                Button("Schließen") { dismiss() }
                Text("Der gespeicherte Snapshot bleibt unverändert. Ungespeicherte Texte gehen beim Schließen verloren; beim Fortsetzen ist der Stichtag erneut ausdrücklich einzugeben.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }.frame(minWidth: 760, minHeight: 650)
    }

    private var startEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bewertungsstichtag (JJJJ-MM-TT, UTC)", text: $cutoffText)
            Text("Der Stichtag begrenzt den bewerteten Sachstand. Publikationsdatum und Ereignisdatum bleiben getrennt.")
                .font(.caption)
            Button("Stichtag bestätigen und Snapshot öffnen", action: start)
        }
    }
    private func criterionEditors(_ snapshot: CaseRevision, graph: DomainContext) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($criteria) { $input in
                if let criterion = graph.find(input.id) {
                    ManualCriterionEditor(criterion: criterion, snapshot: snapshot, graph: graph, input: $input)
                }
            }
        }
    }
    private var overallEditor: some View {
        GroupBox("Gesamtbewertung – separate menschliche Entscheidung") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Die Kriterienbewertungen sind Kontext; es gibt keine mathematische Aggregation.").font(.caption)
                AssessmentFields(state: $overall)
                TextField("Fakten – ein menschlicher Tatsachenbefund pro Zeile", text: $facts, axis: .vertical).lineLimit(3...8)
                TextField("Interpretationen – eine Einordnung pro Zeile", text: $interpretations, axis: .vertical).lineLimit(3...8)
                Text("Der Entwurf beginnt ungeprüft. Kriteriumsprüfung, Vorlage und Freigabe erfolgen anschließend getrennt im Fall.")
                    .font(.caption)
            }.padding(8)
        }
    }
    private func start() {
        formError = nil
        guard let date = parseOptionalDate(cutoffText) else {
            formError = "Bitte einen gültigen Bewertungsstichtag eingeben (JJJJ-MM-TT)."; return
        }
        do {
            let chosen = try manualDay(date, role: .evaluationCutoff)
            let existing = workspace.selectedContext?.caseRevisions.first
            guard let id = existing?.id ?? workspace.startEvaluationSnapshot(cutoff: chosen),
                  let graph = workspace.selectedContext, let snapshot = graph.find(id) else { return }
            cutoff = chosen
            snapshotID = id
            criteria = snapshot.criteria.map { CriterionFormState(id: $0.id) }
        } catch { formError = WorkspaceErrorMessage.describe(error) }
    }
    private func saveDraft() {
        guard let snapshotID, let cutoff, let graph = workspace.selectedContext, let snapshot = graph.find(snapshotID) else { return }
        do {
            let inputs = try criteria.map { input in
                let links = snapshot.evidenceLinks.filter { input.evidence.contains($0.id) }.map { $0.id }
                return try ManualCriterionAssessment(criterionRevisionID: input.id, assessment: input.assessment.domain(),
                    evidenceLinkIDs: links, counterEvidenceLinkIDs: links.filter { input.counterEvidence.contains($0) })
            }
            let id = try workspace.createEvaluationDraft(snapshotID: snapshotID, cutoff: cutoff, criteria: inputs,
                overall: overall.domain(), facts: assessmentLines(facts), interpretations: assessmentLines(interpretations))
            if id != nil { dismiss() }
        } catch EvaluationFormError.explicitChoicesRequired {
            formError = "Kategorie und Evidenzsicherheit müssen für jedes Kriterium und das Gesamturteil ausdrücklich gewählt werden."
        } catch { formError = WorkspaceErrorMessage.describe(error) }
    }
}

private struct AssessmentFields: View {
    @Binding var state: AssessmentFormState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Kategorie", selection: $state.categoryIndex) {
                Text("Ausdrücklich wählen").tag(-1)
                ForEach(evaluationCategories.indices, id: \.self) { index in Text(evaluationCategories[index].manualLabel).tag(index) }
            }
            Picker("Evidenzsicherheit", selection: $state.confidenceIndex) {
                Text("Ausdrücklich wählen").tag(-1)
                ForEach(confidenceValues.indices, id: \.self) { index in Text(confidenceValues[index].manualLabel).tag(index) }
            }
            Text("Qualitative Beleglage, keine Wahrheitswahrscheinlichkeit.").font(.caption)
            TextField("Begründung (erforderlich)", text: $state.rationale, axis: .vertical).lineLimit(3...8)
            TextField("Unsicherheiten – eine pro Zeile", text: $state.uncertainties, axis: .vertical).lineLimit(2...6)
            if state.categoryIndex == 5 { reasonChoices }
        }
    }
    private var reasonChoices: some View {
        VStack(alignment: .leading) {
            Text("Nicht überprüfbar – mindestens einen Grund wählen")
            ForEach(notVerifiableReasons.indices, id: \.self) { index in
                Toggle(notVerifiableReasons[index].manualLabel, isOn: Binding(
                    get: { state.reasons.contains(index) },
                    set: { chosen in if chosen { state.reasons.insert(index) } else { state.reasons.remove(index) } }))
            }
        }
    }
}

private struct ManualCriterionEditor: View {
    let criterion: CriterionRevision
    let snapshot: CaseRevision
    let graph: DomainContext
    @Binding var input: CriterionFormState
    private var links: [EvidenceLink] {
        snapshot.evidenceLinks.filter { $0.state == .verified }.compactMap { graph.find($0.id) }
            .filter { $0.criterionRevisionID == criterion.id }
    }
    var body: some View {
        GroupBox(criterion.goal.value) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Kernkriterium: \(criterion.isCore ? "Ja" : "Nein")")
                Text("Materialität: \(criterion.materialityRule.value)")
                Text("Frist: \(criterion.deadline.content.knownValue?.end?.formatted() ?? "Unbekannt / offen")")
                Text("Revision: \(criterion.id.rawValue.uuidString)").font(.caption)
                if links.isEmpty { Text("Keine geprüfte Evidenz zu diesem Snapshot-Kriterium.").foregroundStyle(.secondary) }
                ForEach(links, id: \.id) { link in evidenceChoice(link) }
                AssessmentFields(state: $input.assessment)
            }.padding(8)
        }
    }
    private func evidenceChoice(_ link: EvidenceLink) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle("Verwenden: \(link.relationship.manualLabel) · \(link.directness.manualLabel) · \(link.rationale.value)",
                isOn: Binding(get: { input.evidence.contains(link.id) }, set: { selected in
                    if selected { input.evidence.insert(link.id) }
                    else { input.evidence.remove(link.id); input.counterEvidence.remove(link.id) }
                }))
            Toggle("Innerhalb der Auswahl als Gegenbeleg kennzeichnen", isOn: Binding(
                get: { input.counterEvidence.contains(link.id) }, set: { selected in
                    if selected && input.evidence.contains(link.id) { input.counterEvidence.insert(link.id) }
                    else { input.counterEvidence.remove(link.id) }
                })).disabled(!input.evidence.contains(link.id))
            if let actionID = link.actionRevisionID, let action = graph.find(actionID) {
                Text("Handlung: \(action.title.value) · Revision \(action.metadata.number)").font(.caption)
            }
            ForEach(link.excerptIDs, id: \.self) { id in
                if let excerpt = graph.find(id) {
                    Text("\(graph.find(excerpt.sourceVersionID)?.title?.value ?? "Quellenfassung") · \(excerpt.locator.value) — \(excerpt.text.value)").font(.caption)
                }
            }
        }.padding(.vertical, 5)
    }
}

struct EvaluationSnapshotSummary: View {
    let snapshot: CaseRevision
    let graph: DomainContext
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unveränderlicher Snapshot: \(snapshot.id.rawValue.uuidString)").font(.caption)
            Text("PromiseRevision: \(snapshot.promiseRevisionID.rawValue.uuidString)").font(.caption)
            ForEach(snapshot.criteria, id: \.id) { entry in
                Text("Kriterium: \(graph.find(entry.id)?.goal.value ?? "Fehlt") · \(entry.id.rawValue.uuidString)").font(.caption)
            }
            Text("\(snapshot.actionRevisionIDs.count) Handlungsrevisionen · \(snapshot.evidenceLinks.count) geprüfte Evidenzlinks · \(snapshot.sourceVersions.count) Quellenfassungen · \(snapshot.excerpts.count) Fundstellen")
                .font(.caption)
            Text("Erstellt: \(snapshot.metadata.createdAt.formatted()) · Methodik 1.0").font(.caption)
        }
    }
}

private extension EvaluationCategory {
    var manualLabel: String {
        switch self {
        case .fulfilled: "Erfüllt"
        case .mostlyFulfilled: "Überwiegend erfüllt"
        case .partiallyFulfilled: "Teilweise erfüllt"
        case .notFulfilled: "Nicht erfüllt"
        case .contraryAction: "Gegenteilig gehandelt"
        case .notVerifiable: "Nicht überprüfbar"
        }
    }
}
private extension EvidenceConfidence {
    var manualLabel: String {
        switch self { case .high: "Hoch"; case .medium: "Mittel"; case .low: "Niedrig" }
    }
}
private extension EvidenceRelationship {
    var manualLabel: String {
        switch self { case .supports: "stützt"; case .contradicts: "widerspricht"; case .contextualizes: "kontextualisiert" }
    }
}
private extension EvidenceDirectness {
    var manualLabel: String { self == .direct ? "direkt" : "indirekt" }
}
extension NotVerifiableReason {
    var manualLabel: String {
        switch self {
        case .unclearPromise: "Unklare Aussage"
        case .openDeadline: "Offene Frist"
        case .conditionNotMet: "Bedingung nicht eingetreten"
        case .missingEvidence: "Entscheidende Evidenz fehlt"
        case .unclearAttribution: "Zurechnung ungeklärt"
        case .conflictingSources: "Quellenkonflikt"
        case .researchBlocked: "Recherchezugriff blockiert"
        }
    }
}

// Local form data only. Saving always creates new Domain IDs and resets every review.
private struct ScriptStatementForm: Identifiable {
    let id = UUID()
    var text = ""
    var kindIndex = 1
    var excerptKeys = ""
    var evidenceKeys = ""
    var uncertainty = ""
}

struct ManualScriptSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    let evaluationID: EntityID<CaseEvaluation>
    let sourceID: EntityID<ScriptDraft>?
    @State private var input: ScriptGenerationInput?
    @State private var forms: [ScriptStatementForm] = [ScriptStatementForm()]
    @State private var target: Double = 45
    @State private var message: String?
    private let kinds: [ScriptStatementKind] = [.fact, .interpretation, .question, .qualification]
    private let labels = ["Tatsache", "Interpretation", "Frage", "Einschränkung"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sourceID == nil ? "Manueller Skriptentwurf" : "Neue Skriptversion").font(.title2)
            Text("Alte Inhalte bleiben erhalten. Neue Sätze beginnen ungeprüft.").font(.caption)
            Stepper("Zielzeit: \(Int(target)) Sekunden", value: $target, in: 30...60, step: 5)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    referenceList
                    ForEach(Array(forms.indices), id: \.self) { index in statementEditor(index) }
                    Button("Satz hinzufügen") { forms.append(ScriptStatementForm()) }
                }
            }
            if let message { Text(message).foregroundStyle(.red) }
            if let error = workspace.errorMessage { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Als neuen Entwurf speichern") { save() }.disabled(input == nil)
            }
        }.padding(20).frame(width: 700, height: 620).onAppear { load() }
    }

    private var referenceList: some View {
        DisclosureGroup("Verfügbare Snapshot-Fundstellen und Evidenz") {
            if let input {
                ForEach(input.excerpts, id: \.key) { item in
                    Text("\(item.key) · \(item.sourceKey) · \(item.excerpt.locator.value): \(item.excerpt.text.value)")
                        .font(.caption).textSelection(.enabled)
                }
                ForEach(input.evidence, id: \.key) { item in
                    Text("\(item.key) · \(item.excerptKeys.joined(separator: ", ")): \(item.link.rationale.value)")
                        .font(.caption).textSelection(.enabled)
                }
            }
        }
    }

    private func statementEditor(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Satz \(index + 1)").font(.headline)
            Picker("Typ", selection: $forms[index].kindIndex) {
                ForEach(0..<labels.count, id: \.self) { Text(labels[$0]).tag($0) }
            }
            TextField("Text", text: $forms[index].text, axis: .vertical).lineLimit(2...6)
            TextField("Fundstellenkeys, durch Komma getrennt (Tatsache: erforderlich)", text: $forms[index].excerptKeys)
            TextField("Evidenzkeys, durch Komma getrennt (optional)", text: $forms[index].evidenceKeys)
            TextField("Unsicherheit (optional)", text: $forms[index].uncertainty)
            HStack {
                Button("Nach oben") { forms.swapAt(index, index - 1) }.disabled(index == 0)
                Button("Nach unten") { forms.swapAt(index, index + 1) }.disabled(index + 1 == forms.count)
                Button("Satz entfernen") { forms.remove(at: index) }
            }
            Divider()
        }
    }

    private func load() {
        do {
            let loaded = try workspace.scriptInput(evaluationID: evaluationID)
            input = loaded
            guard let sourceID, let graph = workspace.selectedContext, let source = graph.find(sourceID) else { return }
            guard source.caseEvaluationID == evaluationID else { throw ValueError.blankText }
            target = min(60, max(30, source.targetDurationSeconds))
            forms = try source.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }.map { statement in
                let ex = try statement.excerptIDs.map { id -> String in
                    guard let item = loaded.excerpts.first(where: { $0.excerpt.id == id }) else { throw ValueError.blankText }
                    return item.key
                }
                let ev = try statement.evidenceLinkIDs.map { id -> String in
                    guard let item = loaded.evidence.first(where: { $0.link.id == id }) else { throw ValueError.blankText }
                    return item.key
                }
                return ScriptStatementForm(text: statement.text.value, kindIndex: kinds.firstIndex(of: statement.kind)!,
                    excerptKeys: ex.joined(separator: ", "), evidenceKeys: ev.joined(separator: ", "),
                    uncertainty: statement.uncertainty?.value ?? "")
            }
        } catch { input = nil; message = "Der freigegebene Snapshot oder die Skriptreferenzen konnten nicht geladen werden: \(error)" }
    }

    private func keys(_ text: String) -> [String] {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        return text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    private func save() {
        let output = ScriptGenerationOutput(statements: forms.enumerated().map { index, form in
            GeneratedScriptStatement(position: index, text: form.text, kind: kinds[form.kindIndex],
                referencedExcerptKeys: keys(form.excerptKeys), referencedEvidenceKeys: keys(form.evidenceKeys),
                uncertainty: form.uncertainty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : form.uncertainty)
        })
        if workspace.createManualScript(evaluationID: evaluationID, output: output, targetDurationSeconds: target) != nil { dismiss() }
    }
}

struct OpenAITransmissionSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("An OpenAI übertragene Daten").font(.title2)
            Text("Die angezeigten Auszüge werden zur Skripterstellung an OpenAI übertragen.")
            Text("Die KI-Ausgabe ist ein ungeprüfter Entwurf und verändert die freigegebene Bewertung nicht.").font(.caption)
            Text("Nur Daten des freigegebenen Snapshots. Keine Recherche, keine Tools.").font(.caption)
            transmissionContent
            if let error = workspace.errorMessage { Text(error).foregroundStyle(.red) }
            if workspace.isGeneratingScript { ProgressView("OpenAI erstellt den ungeprüften Entwurf …") }
            HStack {
                Button("Abbrechen") { workspace.dismissOpenAIPreview(); dismiss() }.disabled(workspace.isGeneratingScript)
                Spacer()
                Button("An OpenAI senden") {
                    Task { if await workspace.sendOpenAIScript() != nil { dismiss() } }
                }.disabled(workspace.isGeneratingScript || workspace.openAITransmissionPreview == nil)
            }
        }.padding(20).frame(width: 720, height: 650)
        .interactiveDismissDisabled(workspace.isGeneratingScript)
        .onDisappear { workspace.dismissOpenAIPreview() }
    }
    @ViewBuilder private var transmissionContent: some View {
        if let preview = workspace.openAITransmissionPreview {
            LabeledContent("Modell", value: preview.configuration.model)
            LabeledContent("Zielzeit", value: "\(Int(preview.input.targetDurationSeconds)) Sekunden")
            LabeledContent("Bewertung", value: preview.input.evaluation.category.manualLabel)
            LabeledContent("Kriterien / EvidenceLinks / Fundstellen",
                value: "\(preview.input.criteria.count) / \(preview.input.evidence.count) / \(preview.input.excerpts.count)")
            Text("Vollständige Nutzdaten: Originalversprechen, Bewertung, Kriterien, Quellen/Locators und Unsicherheiten. Dieser Text wird unverändert gesendet.").font(.caption)
            ScrollView {
                Text(preview.contentJSON).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Die Vorschau ist nicht mehr gültig. Schließe das Fenster und öffne sie erneut.").foregroundStyle(.orange)
            Spacer()
        }
    }
}


struct EditorialImportSheet: View {
    @EnvironmentObject private var workspace: CaseWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Redaktionspaket importieren").font(.title2)
            if let summary = workspace.editorialImportPreview {
                Text("Fall: \(summary.title)")
                Text("Bewertung: \(summary.category.manualLabel)")
                Text("Stichtag: \(summary.cutoffText)")
                Text("Methodik: \(summary.methodologyVersion) · Scriptversion: \(summary.scriptVersion)")
                if let date = summary.exportedAt { Text("Exportzeit: \(date.formatted())") }
                Text("Historischer geprüfter Stand. Keine Nachladung, kein Merge, keine neue politische Bewertung.").font(.caption)
            }
            if let error = workspace.errorMessage { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Abbrechen") { workspace.dismissEditorialImport(); dismiss() }
                Spacer()
                Button("Importieren") { if workspace.confirmEditorialImport() { dismiss() } }
                    .disabled(workspace.editorialImportPreview == nil)
            }
        }.padding(20).frame(width: 620)
        .onDisappear { workspace.dismissEditorialImport() }
    }
}
