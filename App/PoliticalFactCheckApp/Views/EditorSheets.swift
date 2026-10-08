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
