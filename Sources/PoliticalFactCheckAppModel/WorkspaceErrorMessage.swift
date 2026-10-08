import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckPersistence

public enum WorkspaceErrorMessage {
    public static func describe(_ error: Error) -> String {
        if let error = error as? PersistenceError {
            switch error {
            case .invalidAggregate: return "Der Fall enthält nicht genau ein vollständiges Versprechen."
            case .invalidDomain(let errors): return errors.map(describe).joined(separator: "\n")
            case .invalidEnum(let type, let value): return "Ein gespeicherter Status ist ungültig (\(type): \(value))."
            case .wrongIDType(let expected, _, _): return "Eine gespeicherte Verknüpfung erwartet den Typ \(expected)."
            case .identityMismatch(let kind, _): return "Der gespeicherte Datensatz \(kind) passt nicht zu seiner ID."
            case .missingEntity(let kind, _): return "Ein benötigter Datensatz fehlt: \(kind)."
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

    private static func describe(_ error: DomainValidationError) -> String {
        switch error {
        case .missingReference(let ref): return "Eine referenzierte Information fehlt (\(ref.kind))."
        case .duplicateReference(let ref): return "Eine Information ist doppelt verknüpft (\(ref.kind))."
        case .relationshipMismatch(let ref): return "Die Verknüpfung passt fachlich nicht zusammen (\(ref.kind))."
        case .missingHumanReview: return "Für diese Verifikation ist eine menschliche Prüfung erforderlich."
        case .unknownVerifiedValue: return "Ein unbekannter oder nicht anwendbarer Wert darf nicht als verifiziert markiert sein."
        case .missingSourceIdentity: return "Die Quelle braucht eine URL oder Dokumentkennung."
        case .invalidRevisionNumber: return "Die Revisionsnummer muss größer als null sein."
        case .invalidReviewTime: return "Der Prüfzeitpunkt liegt vor der erstellten Revision."
        case .missingOriginalExcerpt: return "Für das Originalzitat fehlt eine konkrete Fundstelle."
        case .missingEvidenceExcerpt: return "Für die Evidenz fehlt eine Fundstelle."
        case .excerptNotVerified(_): return "Die Fundstelle muss zuerst menschlich geprüft werden."
        case .sourceVersionNotVerified(_): return "Die Quellenfassung muss zuerst menschlich geprüft werden."
        case .missingCriteria: return "Lege mindestens ein Prüfkriterium an."
        case .criterionNotConfirmed(_): return "Das Kriterium ist noch nicht menschlich bestätigt."
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
        case .invalidDateRole(_, _): return "Das Datum hat eine unpassende fachliche Rolle."
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
