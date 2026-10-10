import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckScripting
import PoliticalFactCheckExport
import PoliticalFactCheckPersistence

public enum WorkspaceErrorMessage {
    public static func describe(_ error: Error) -> String {
        if let error = error as? ScriptReviewError {
            switch error {
            case .currentEvaluationUnavailable: return "Keine aktuelle freigegebene Bewertung; zuerst die Bewertungsprüfung abschließen."
            case .ambiguousEvaluation: return "Mehrere aktuelle Bewertungen; Skripterzeugung ist bis zur Klärung blockiert."
            case .ambiguousScript: return "Mehrere Skripte derselben aktuellen Version; Prüfung ist blockiert."
            case .scriptUnavailable: return "Das aktuelle Skript fehlt."
            case .existingScriptRequiresReview: return "Vorhandenen Skriptentwurf zuerst prüfen."
            case .newVersionConfirmationRequired: return "Eine neue KI-Skriptversion muss ausdrücklich angefordert werden."
            case .invalidScript: return "Skript oder geprüfte Quellenreferenzen sind ungültig."
            case .confirmationRequired: return "Bestätige ausdrücklich die Prüfung von Fakten, Quellen, Interpretationen und Unsicherheiten."
            case .statementsNotReviewed: return "Alle Sätze müssen menschlich geprüft sein; die aktuelle Bewertung muss freigegeben bleiben."
            case .invalidSelection: return "Die Auswahl enthält keinen gültigen Satz oder gehört nicht zum aktuellen prüfbaren Skript."
            }
        }
        if let error = error as? EditorialPackageError {
            switch error {
            case .evaluationNotApproved: return "Keine gültige menschlich freigegebene Bewertung vorhanden."
            case .evaluationNeedsReview: return "Bewertung muss erneut geprüft werden; Export blockiert."
            case .scriptNotApproved: return "Ein menschlich freigegebenes Skript ist erforderlich."
            case .scriptEvaluationMismatch: return "Das Skript gehört nicht zur gewählten Bewertung."
            case .invalidScript: return "Das Skript oder seine Satzprüfungen sind ungültig."
            case .unsupportedVersion: return "Diese Redaktionspaket-Version wird nicht unterstützt."
            case .missingFile: return "Eine Paketdatei fehlt oder die Dateiliste ist ungültig."
            case .hashConflict: return "Eine Paketdatei stimmt nicht mit ihrem SHA-256 überein."
            case .methodologyConflict: return "Methodikinhalt oder Methodology-Hash stimmt nicht überein."
            case .invalidJSON: return "Das Redaktionspaket enthält ungültiges JSON."
            case .invalidReference: return "Das Redaktionspaket enthält beschädigte oder fremde Referenzen."
            case .invalidDomain: return "Die Domainvalidierung des Redaktionspakets ist fehlgeschlagen."
            case .caseAlreadyExists: return "Dieser Fall ist bereits vorhanden."
            case .nonPortableAttachment: return "Portable Export lokaler Anhänge wird noch nicht unterstützt."
            case .sensitiveContent: return "Das Paket enthält mögliche Zugangsdaten oder Netzwerk-Dumps; Vorgang blockiert."
            case .writeFailure: return "Das Redaktionspaket konnte nicht vollständig geschrieben werden."
            case .readFailure: return "Das Redaktionspaket konnte nicht sicher gelesen werden."
            case .invalidPackage: return "Paketinhalt und geprüfter Fallstand stimmen nicht überein."
            case .destinationExists: return "Am Ziel existiert bereits ein Paket. Wähle einen neuen Speicherort."
            }
        }
        if let error = error as? PersistenceError {
            switch error {
            case .scriptGeneration(let error): return describe(error)
            case .invalidAggregate: return "Der Fall enthält nicht genau ein vollständiges Versprechen."
            case .invalidDomain(let errors): return errors.map(describe).joined(separator: "\n")
            case .invalidEnum(let type, let value): return "Ein gespeicherter Status ist ungültig (\(type): \(value))."
            case .wrongIDType(let expected, _, _): return "Eine gespeicherte Verknüpfung erwartet den Typ \(expected)."
            case .identityMismatch(let kind, _): return "Der gespeicherte Datensatz \(kind) passt nicht zu seiner ID."
            case .missingEntity(let kind, _):
                switch kind {
                case "CriterionRevision": return "Das Kriterium fehlt oder gehört nicht zu den aktiven Kriterien dieses Falls."
                case "ActionRevision": return "Die Handlungsrevision fehlt oder gehört nicht zu diesem Fall."
                case "SourceExcerpt": return "Die ausgewählte Fundstelle ist in diesem Fall nicht vorhanden."
                default: return "Ein benötigter Datensatz fehlt: \(kind)."
                }
            case .duplicateID(let kind, _): return "Die ID eines Datensatzes ist doppelt vorhanden: \(kind)."
            case .corruptPayload(_): return "Ein gespeicherter Datensatz ist beschädigt und wurde nicht verändert."
            case .invalidValue(let detail): return "Ein gespeicherter Wert ist ungültig: \(detail)"
            case .unsupportedFormat(let version): return "Das Speicherformat \(version) wird nicht unterstützt."
            case .historyRemovalDenied(let kind, _): return "Der historische Datensatz \(kind) kann nicht entfernt werden."
            case .draftDeletionDenied(_): return "Dieser Fall enthält bereits geschützte historische Daten und kann nicht als Entwurf gelöscht werden."
            case .reviewUpdateRequired(_): return "Die Änderung erfordert eine erneute Prüfung der betroffenen Bewertung."
            case .immutableRecord(let kind, _): return "Der historische Datensatz \(kind) ist unveränderlich. Lege eine neue Revision an."
            case .storage(let operation, let detail): return "Speicherfehler bei \(operation): \(detail)"
            }
        }
        if let error = error as? OpenAIProviderError { return describe(error) }
        if let error = error as? ScriptGenerationError { return describe(error) }
        if let error = error as? DomainValidationError { return describe(error) }
        if let error = error as? WorkspaceInputError {
            switch error {
            case .reviewerNameMissing: return "Trage zuerst unter „Prüfername“ den Namen der menschlichen prüfenden Person ein."
            case .caseUnavailable: return "Der ausgewählte Fall ist nicht mehr verfügbar. Lade die Fallliste neu."
            case .invalidURL: return "Gib eine vollständige HTTP- oder HTTPS-URL ein oder verwende eine Dokumentkennung."
            case .quoteUnavailable: return "Das Originalzitat ist unbekannt und kann deshalb nicht verifiziert werden."
            case .storeUnavailable: return "Der lokale Speicher ist nicht geöffnet. Prüfe den angezeigten Startfehler."
            }
        }
        if let error = error as? ValueError {
            switch error {
            case .blankText: return "Bitte fülle alle erforderlichen Textfelder aus."
            case .invalidDateInterval, .invalidDatePrecision: return "Das Datum oder der Zeitraum ist ungültig."
            case .invalidTimeZone: return "Die angegebene Zeitzone ist ungültig."
            case .invalidHash: return "Der Quellenhash ist ungültig."
            }
        }
        return "Die Änderung konnte nicht gespeichert werden. Details: \(String(describing: error))"
    }

    private static func describe(_ error: OpenAIProviderError) -> String {
        switch error {
        case .missingAPIKey: return "OpenAI API key is not configured. Setze OPENAI_API_KEY ausschließlich in deiner lokalen Entwicklungsumgebung."
        case .invalidRequest: return "OpenAI konnte die Anfrage nicht verarbeiten. Prüfe die lokale Modellkonfiguration."
        case .authenticationFailed: return "OpenAI-Authentifizierung fehlgeschlagen. Prüfe den lokal gesetzten API-Key."
        case .permissionDenied: return "Keine Berechtigung für die OpenAI-Anfrage oder das konfigurierte Modell."
        case .rateLimited: return "OpenAI-Limit erreicht. Bitte später erneut versuchen."
        case .serviceUnavailable: return "OpenAI ist vorübergehend nicht verfügbar. Bitte später erneut versuchen."
        case .networkFailure: return "Die Verbindung zu OpenAI ist fehlgeschlagen. Es wurde kein Entwurf gespeichert."
        case .timeout: return "Die OpenAI-Anfrage hat zu lange gedauert. Bitte erneut versuchen."
        case .malformedResponse: return "OpenAI hat eine ungültige Antwort geliefert. Es wurde kein Entwurf gespeichert."
        case .structuredOutputMissing: return "In der OpenAI-Antwort fehlt der strukturierte Skriptentwurf."
        case .refused: return "Das Modell hat die Anfrage nicht ausgeführt."
        case .incompleteResponse: return "Die OpenAI-Antwort ist unvollständig. Es wurde kein Teilentwurf gespeichert."
        case .invalidProviderReferences: return "Der KI-Entwurf enthält ungültige Referenzen oder Tatsachensätze ohne geprüfte Fundstelle. Er wurde nicht gespeichert."
        case .previewChanged: return "Der Fall oder die Vorschau hat sich geändert. Öffne die Übertragungsvorschau erneut."
        }
    }

    private static func describe(_ error: ScriptGenerationError) -> String {
        switch error {
        case .evaluationUnavailable: return "Für den Skriptentwurf fehlt eine freigegebene Bewertung."
        case .evaluationNotApproved(let status):
            return status == .reviewRequired ? "Bewertung muss erneut geprüft werden." : "Skripte benötigen eine aktuell freigegebene Bewertung."
        case .snapshotUnavailable: return "Der Bewertungssnapshot fehlt."
        case .invalidSnapshot: return "Die Fundstellen oder Evidenz sind nicht geprüft oder passen nicht zum Bewertungssnapshot."
        case .unknownExcerptKey(let key): return "Unbekannte oder Snapshot-fremde Fundstelle: \(key). Der Entwurf wurde nicht gespeichert."
        case .unknownEvidenceKey(let key): return "Unbekannte oder Snapshot-fremde Evidenz: \(key). Der Entwurf wurde nicht gespeichert."
        case .factWithoutExcerpt: return "Ein Tatsachensatz benötigt mindestens eine geprüfte Fundstelle aus dem Snapshot."
        case .inconsistentEvidence(let key): return "Die Fundstellen passen nicht zur referenzierten Evidenz \(key)."
        case .invalidDuration: return "Die Zielzeit muss zwischen 30 und 60 Sekunden liegen."
        case .emptyOutput, .invalidPosition, .blankText, .duplicateKey: return "Ungültige Skriptausgabe: prüfe Texte, Positionen und doppelte Referenzen."
        case .providerFailure(let message): return "Skript-Provider fehlgeschlagen: \(message)"
        case .generationInProgress: return "Ein Skriptentwurf wird bereits erzeugt."
        }
    }

    private static func describe(_ error: DomainValidationError) -> String {
        switch error {
        case .evaluationRequiresReadyCase: return "Eine neue Bewertung verlangt einen bewertungsbereiten Fall."
        case .firstEvaluationOnly: return "Für diesen Fall wurde bereits ein Bewertungsstand begonnen. Verwende den vorhandenen Snapshot; Ersatzbewertungen folgen später."
        case .methodologyConflict: return "Methodikversion 1.0 fehlt oder kollidiert mit dem eingefrorenen Inhalt. Sie wurde nicht überschrieben."
        case .criterionReviewNotAllowed: return "Diese Kriteriumsbewertung kann nicht erneut oder nach historischer Freigabe geprüft werden."
        case .missingReference(let ref):
            switch ref.kind {
            case .methodology: return "Die referenzierte Methodikversion fehlt."
            case .caseRevision: return "Der referenzierte Bewertungssnapshot fehlt."
            default: return "Eine referenzierte Information fehlt (\(ref.kind))."
            }
        case .duplicateReference(let ref): return "Eine Information ist doppelt verknüpft (\(ref.kind))."
        case .relationshipMismatch(let ref):
            switch ref.kind {
            case .promiseRevision: return "Prüfe Originalzitat, Kontext und Sprecherzuordnung, bevor der Fall als geprüft markiert wird."
            case .evidenceLink: return "Die Evidenz gehört nicht zu diesem Kriterium oder der Gegenbeleg ist nicht in der verwendeten Evidenzauswahl enthalten."
            case .criterionRevision: return "Der Kriterienbezug passt nicht zur aktuellen PromiseRevision. Binde den Prüfrahmen neu und bestätige das Kriterium erneut."
            default: return "Die Verknüpfung passt fachlich nicht zusammen (\(ref.kind))."
            }
        case .originalQuoteNotVerified: return "Prüfe zuerst das Originalzitat anhand einer geprüften Fundstelle."
        case .speakerAssignmentUnavailable: return "Für die Sprecherprüfung fehlt ein vorhandener Sprecher-Akteur."
        case .historicalReadinessChangeDenied: return "Dieser Fall besitzt bereits einen Bewertungssnapshot oder eine Bewertung. Die direkte Neubindung ist gesperrt; eine spätere Neubewertung benötigt einen eigenen Vorgang."
        case .readinessRequiresDocumentedCase: return "Bestätige den Prüfrahmen eines dokumentierten Falls vor den weiteren Workflowübergängen."
        case .missingHumanReview: return "Eine menschliche Prüfung ist erforderlich. Prüfe vor Skriptfreigabe auch jeden einzelnen Satz."
        case .unknownVerifiedValue: return "Ein unbekannter oder nicht anwendbarer Wert darf nicht als verifiziert markiert sein."
        case .missingSourceIdentity: return "Die Quelle braucht eine URL oder Dokumentkennung."
        case .invalidRevisionNumber: return "Die Revisionsnummer muss größer als null sein."
        case .invalidReviewTime: return "Der Prüfzeitpunkt liegt vor der erstellten Revision."
        case .missingOriginalExcerpt: return "Für das Originalzitat fehlt eine konkrete Fundstelle."
        case .missingEvidenceExcerpt: return "Für die Evidenz fehlt eine Fundstelle."
        case .excerptNotVerified(_): return "Die Fundstelle muss zuerst menschlich geprüft werden."
        case .sourceVersionNotVerified(_): return "Die Quellenfassung muss zuerst menschlich geprüft werden."
        case .missingCriteria: return "Lege mindestens ein Prüfkriterium an."
        case .criterionNotConfirmed(_): return "Das Kriterium ist noch nicht menschlich bestätigt. Nach einer Neubindung muss es erneut bestätigt werden."
        case .weightWithoutJustification: return "Für die Gewichtung fehlt eine Begründung."
        case .snapshotMismatch: return "Die aktuelle Information stimmt nicht mit dem historischen Prüfstand überein."
        case .immutableContentChanged: return "Eine historische Revision ist unveränderlich. Lege eine neue Revision an."
        case .emptyEvidenceForNegativeJudgment: return "Eine negative Bewertung kann nicht ohne geprüfte Evidenz gespeichert werden."
        case .positiveJudgmentRequiresSupportingEvidence: return "Für diese Bewertung fehlt stützende Evidenz."
        case .evidenceLinkNotVerified: return "Der Evidenzbeleg muss zuerst geprüft werden."
        case .contraryActionRequiresContradictingEvidence: return "Für „gegenteilig gehandelt“ fehlt ein geprüfter widersprechender Beleg."
        case .missingNotVerifiableReason: return "Für „nicht überprüfbar“ fehlt ein strukturierter Grund."
        case .lowConfidenceNegativeJudgment: return "Eine negative Schlussbewertung braucht höhere Evidenzsicherheit."
        case .unreviewedCriterionEvaluation: return "Die Kriterienbewertung ist noch nicht menschlich geprüft."
        case .invalidDateRole(_, _): return "Das Datum hat eine unpassende fachliche Rolle. Evidenz benötigt einen Ereignis- oder Gültigkeitsbezug, kein Publikationsdatum."
        case .missingCutoff: return "Für die Bewertung fehlt ein Stichtag."
        case .eventAfterCutoff: return "Das Ereignis liegt nach dem Bewertungsstichtag."
        case .deadlineNotPassed: return "Die Frist ist noch nicht abgelaufen."
        case .missingReviewReason: return "Für die erneute Prüfung fehlt eine Begründung."
        case .scriptFactWithoutExcerpt: return "Eine Tatsachenaussage im Skript braucht eine Fundstelle."
        case .causalAttributionWithoutEvidence: return "Für die kausale Zurechnung fehlen geprüftes Material und Review."
        case .invalidCaseTransition(_, _): return "Dieser Workflow-Übergang ist nicht zulässig."
        case .invalidCriterionTransition(_, _): return "Dieser Kriterien-Übergang ist nicht zulässig."
        case .invalidExcerptTransition(_, _): return "Dieser Fundstellen-Übergang ist nicht zulässig."
        case .invalidEvaluationTransition(_, _): return "Dieser Bewertungs-Übergang ist nicht zulässig."
        case .invalidFactTransition(_, _): return "Dieser Verifikations-Übergang ist nicht zulässig."
        case .invalidScriptTransition(_, _): return "Dieser Skript-Übergang ist nicht zulässig."
        case .invalidEvidenceTransition(_, _): return "Dieser Evidenz-Übergang ist nicht zulässig."
        }
    }
}
