import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

enum EditorialDocuments {
    static func render(graph: DomainContext, input: ScriptGenerationInput, script: ScriptDraft, report: EditorialCaseReportV1) throws -> [String: Data] {
        let title = graph.cases[0].title.value
        let cutoff = date(input.evaluation.cutoff)
        let statements = script.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }
        let header = "# \(escape(title))\n\nBewertung: \(category(input.evaluation.category))\n\nBewertungsstichtag: \(cutoff)\n\nMethodologyVersion: \(input.methodology.version.value)\n\nScriptversion: \(script.version) · Status: approved\n\nZielzeit: \(script.targetDurationSeconds) Sekunden (Planwert, nicht gemessen)\n"
        func excerptKeys(_ statement: ScriptStatement) -> String {
            input.excerpts.filter { statement.excerptIDs.contains($0.excerpt.id) }.map { $0.key }.joined(separator: ", ")
        }
        func evidenceKeys(_ statement: ScriptStatement) -> String {
            input.evidence.filter { statement.evidenceLinkIDs.contains($0.link.id) }.map { $0.key }.joined(separator: ", ")
        }
        var scriptText = header + "\n## Laufender Skripttext\n\n"
        for statement in statements {
            scriptText += "[\(kind(statement.kind))] \(escape(statement.text.value))\n\n"
            if !statement.excerptIDs.isEmpty { scriptText += "Quellen: \(excerptKeys(statement))\n\n" }
            if let uncertainty = statement.uncertainty { scriptText += "Unsicherheit: \(escape(uncertainty.value))\n\n" }
        }
        var sourcesText = "# Quellenblatt\n\nKonkrete gespeicherte Quellenfassungen; keine aktuelle URL-Prüfung oder Nachladung.\n"
        let relevantVersionIDs = Set(report.sourceVersions.map { $0.id.value })
        let relevantExcerptIDs = Set(report.excerpts.map { $0.id.value })
        for source in input.sources where relevantVersionIDs.contains(source.version.id.rawValue) {
            let value = source.version
            sourcesText += "\n## \(source.key) · \(escape(value.title?.value ?? "Titel nicht dokumentiert"))\n\n"
            sourcesText += "Publisher: \(escape(value.publisher?.value ?? "nicht dokumentiert"))\n\nAutor: \(escape(value.author?.value ?? "nicht dokumentiert"))\n\n"
            sourcesText += "URL: \(escape((value.finalURL ?? value.requestedURL ?? graph.find(value.sourceID)?.canonicalURL)?.absoluteString ?? "nicht dokumentiert"))\n\n"
            if let archive = value.archiveURL { sourcesText += "Archiv-URL: \(escape(archive.absoluteString))\n\n" }
            sourcesText += "SourceVersion: \(value.id.rawValue.uuidString)\n\nPublikation: \(date(value.publicationDate))\n\nAbruf: \(date(value.retrievedAt))\n\n"
            sourcesText += "Verifikation: \(String(describing: value.verification)); im Snapshot: verified\n\n"
            for item in input.excerpts where item.excerpt.sourceVersionID == value.id && relevantExcerptIDs.contains(item.excerpt.id.rawValue) {
                sourcesText += "### \(item.key) · \(escape(item.excerpt.locator.value))\n\n\(escape(item.excerpt.text.value))\n\nKontext: \(escape(item.excerpt.context.value))\n\n"
                let positions = statements.filter { $0.excerptIDs.contains(item.excerpt.id) }.map { String($0.position) }
                sourcesText += "ScriptStatement-Positionen: \(positions.isEmpty ? "kein direkter Satzbezug; Bewertungs-/Versprechenskontext" : positions.joined(separator: ", "))\n\n"
            }
        }
        var storyboard = header + "\n## Szenengrundlage\n\nJeder Satz ist ein möglicher Szenenabschnitt. Keine Einzeldauer gemessen. Visualplanung folgt in Phase 5.\n"
        for statement in statements {
            storyboard += "\n### Position \(statement.position) · \(kind(statement.kind))\n\n\(escape(statement.text.value))\n\n"
            storyboard += "Quellen: \(excerptKeys(statement))\n\nEvidence: \(evidenceKeys(statement))\n\nUnsicherheit: \(escape(statement.uncertainty?.value ?? "keine am Satz dokumentiert"))\n\nVisualhinweis: Noch festzulegen\n"
        }
        let readme = """
        # PoliticalFactCheck Editorial Package

        Fall: \(escape(title))

        Case: \(graph.cases[0].id.rawValue.uuidString)

        Evaluation: \(input.evaluation.id.rawValue.uuidString)

        Script: \(script.id.rawValue.uuidString), Version \(script.version)

        Methodik: \(input.methodology.version.value)

        Bewertungsstichtag: \(cutoff)

        Formatversion: 1

        Historischer menschlich geprüfter Stand. Spätere Entwicklungen sind nicht automatisch enthalten.
        case-report.json enthält die gewählte redaktionelle Sicht; case-archive.json den vollständigen lokalen Fallverlauf einschließlich ungeprüfter historischer/aktueller Arbeitsdaten. Diese sind durch das Paket nicht neu freigegeben.
        Das Paket enthält Reviewer- und Auditmetadaten für Nachvollziehbarkeit. Vor Weitergabe sind Datenschutz, Quellenrechte und Aufbewahrung redaktionell zu prüfen.
        SHA-256 erkennt Byteänderungen, ist keine digitale Signatur oder Echtheitsbestätigung des Herausgebers.
        Import ist offline, ohne Merge oder UUID-Umschreibung. Lokale Anhänge werden in Format 1 nicht unterstützt.
        """
        return ["script.md": Data(scriptText.utf8), "sources.md": Data(sourcesText.utf8), "storyboard.md": Data(storyboard.utf8), "README.md": Data(readme.utf8)]
    }
    static func date(_ value: DatedValue) -> String {
        switch value.content {
        case .known(let interval):
            return "\(interval.start.map { PortableJSON.utc($0) } ?? "offener Beginn") – \(interval.end.map { PortableJSON.utc($0) } ?? "offenes Ende") (\(String(describing: value.precision)); \(String(describing: value.role)))"
        case .unknown(let reason): return "Unbekannt: \(escape(reason.value))"
        case .notApplicable(let reason): return "Nicht anwendbar: \(escape(reason.value))"
        }
    }
    static func category(_ value: EvaluationCategory) -> String {
        switch value {
        case .fulfilled: return "erfüllt"
        case .mostlyFulfilled: return "überwiegend erfüllt"
        case .partiallyFulfilled: return "teilweise erfüllt"
        case .notFulfilled: return "nicht erfüllt"
        case .contraryAction: return "gegenteilig gehandelt"
        case .notVerifiable: return "nicht überprüfbar"
        }
    }
    private static func kind(_ value: ScriptStatementKind) -> String {
        switch value {
        case .fact: return "Fact / Tatsache"
        case .interpretation: return "Interpretation"
        case .question: return "Frage"
        case .qualification: return "Einschränkung"
        }
    }
    private static func escape(_ text: String) -> String {
        var value = text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        for character in ["\\", "`", "*", "_", "[", "]", "#", "!", "|"] {
            value = value.replacingOccurrences(of: character, with: "\\" + character)
        }
        return value
    }
}
