# VideoScriptHandoffV1 – interner Transfer für Phase 6

VideoScriptHandoff ist kein neues journalistisches Urteil. Er enthält ausschließlich bereits freigegebene Skript- und Quelleninformationen.

Das separate, plattformneutrale PoliticalFactCheckVideoPlanning-Target verwendet Foundation, Core und Scripting (für die gemeinsame konservative aktuelle Bewertung-/Skriptselektion). Es enthält keine SwiftUI-, SwiftData-, Provider-, Audio- oder Renderlogik. Die Werte werden nicht separat persistiert oder exportiert; Editorial Package Format 1 bleibt unverändert.

## Werte

| Wert | Felder |
| --- | --- |
| VideoScriptHandoffV1 | caseID, evaluationID, scriptID, scriptVersion, targetDurationSeconds, scenes |
| VideoSceneV1 | position, statementID, kind, narrationText, uncertainty, excerptIDs, evidenceLinkIDs, sourceOverlays, estimatedDurationSeconds |
| SourceOverlayV1 | sourceVersionID, sourceTitle?, publisher?, url?, locator, excerptID |

Alle IDs sind die bestehenden typisierten EntityIDs. Texte sind unveränderte Strings aus NonEmptyText; unbekannte Metadaten bleiben nil. Keine neu formulierten Citation-Texte, Motive oder politische Aussagen. Overlays verwenden ausschließlich vorhandene verifizierte Fundstellen und verifizierte Quellenfassungen; URL-Reihenfolge: finalURL → requestedURL → archiveURL → bestehende Source.canonicalURL. Locator bleibt exakt erhalten.

## Builder und Gates

VideoScriptHandoffBuilder.build(scriptID:in:) ist eine pure Funktion mit strukturierten VideoHandoffErrors. Er verlangt:

- aktuell eindeutig ausgewählte approved Evaluation und ihre aktuelle höchste Skriptfassung;
- ScriptDraft approved, ursprüngliche menschliche Approval vorhanden;
- alle referenzierten Sätze vorhanden und menschlich reviewed;
- gültigen vollständigen DomainContext und gültiges Skript;
- endliche Zielzeit im bestehenden Bereich 30…60 Sekunden;
- für jede referenzierte Fundstelle vorhandene, geprüfte Quellenfassung;
- für jeden Tatsachensatz mindestens ein Quellenoverlay.

Ältere approved Versionen bleiben historische Freigaben, sind bei einer neueren Draftfassung jedoch keine aktuelle Videoeingabe. draft, needsReview, superseded sowie nachträgliches Evaluation.reviewRequired blockieren. Es wird niemals auf ein altes Urteil zurückgefallen oder fehlendes Material repariert. Unprüfbare Eingaben erzeugen keinen Teilhandoff.

## Deterministische Szenen und Dauer

Genau ein freigegebener Satz ergibt eine Basisszene, nach Position sortiert. Narration, Satztyp, Unsicherheit und Referenzarrays werden exakt übernommen. Overlay-Reihenfolge entspricht der unveränderlichen excerptIDs-Reihenfolge; die Funktion erzeugt keine zufälligen IDs und keine Zeitstempel.

Gewicht pro Satz = max(1, Anzahl durch Unicode-Whitespace getrennter Wörter). Planzeit wird proportional zum Gesamtgewicht verteilt; die letzte Szene erhält den Float-Rest. Damit entspricht die Summe innerhalb kleiner Float-Toleranz exakt targetDurationSeconds. Default bleibt 45 Sekunden. estimatedDurationSeconds ist ausdrücklich keine gemessene oder garantierte Sprechdauer. Keine zusätzlichen Mindest-/Maximaldauern oder Sprachmodelle in dieser Version.

Interpretation, Frage und Einschränkung benötigen keine Overlays; vorhandene geprüfte Referenzen bleiben erhalten. Satztyp und Unsicherheit dürfen in Phase 6 nicht als automatisches Faktenurteil umgedeutet werden. Spätere Verarbeitung muss vor Verwendung des flüchtigen Handoffs die aktuellen Gates erneut prüfen; ein einmal abgeleiteter Wert ist keine dauerhafte Freigabeberechtigung.

## Nicht enthalten

TTS, Untertitel, Bildmotive, Visualsuche, Personenbilder, B-Roll, Kameraführung, Animation, Musik, Rendering, Cloud, Upload und Publishing sind nicht implementiert. Der Vertrag ist noch kein externer Dateiformat-/Codable-Vertrag. Journalistische Wahrheit und semantische Quellenabdeckung bleiben menschliche Verantwortung. Reale Swift-/macOS-Verifikation des neuen Targets steht aus; Offline-Tests und unveränderte CI prüfen es nach Push.
