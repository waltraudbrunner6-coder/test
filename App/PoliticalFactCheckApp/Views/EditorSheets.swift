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
