# Implementierungsnotizen: fachlicher Swift-Core

## Struktur und Prüfstand

Eigenständiges Swift Package `PoliticalFactCheckCore`, Swift-Tools-Version 5.9, ohne externe Dependencies und ohne Plattformbindung. `Domain/` enthält Werttypen, typisierte UUID-IDs, Datenobjekte und reine Änderungsfunktionen; `Validation/` enthält strukturierte Fehler, Warnungen, Übergangsregeln und Validatoren. Foundation dient ausschließlich grundlegenden Werten wie UUID, Datum und URL. `DomainContext` ist ein expliziter, unveränderlicher Validierungseingang mit auflösbaren Referenzen, kein Speicher oder Repository-Service.

90 XCTest-Testmethoden (73 bestehende unverändert, 17 zusätzliche Review-Tests) verwenden ausschließlich synthetische Akteure, Quellen und Versprechen. Die Methodik-Fixture ist ausdrücklich `TEST-FIXTURE-ONLY`; eine redaktionelle MethodologyVersion 1.0 wurde nicht erstellt. Getestet werden sollen auch der vollständige Fallgraph, Parteienneutralität, historische Referenzen sowie Veröffentlichung 2025 / Ereignis 2021 / Stichtag 2022.

Der Ausgangsstand `b114ee40015e28c17e26cd1555ba555f63100e6b` ist laut ausdrücklich bestätigtem Nutzerbericht erfolgreich auf macOS-15 mit Apple Swift 6.1.2 kompiliert und getestet: 90 Tests, 0 Fehler, GitHub-Actions-Lauf „Validate domain core and clarify review workflow“. Damit ist dieser Domain-Core als `DOMAIN CORE READY` bestätigt.

Lokal bleiben `swift` und `swiftc` nicht verfügbar (`command not found`, Exit 127). Die neue Phase 2.2 ergänzt ein separates SwiftData-Target und 42 weitere Tests; diese benötigen einen eigenen macOS-CI-Nachweis. Die bestehende `.github/workflows/swift-tests.yml` führt beide Targets aus. Die lokale GitHub-CLI meldet weiterhin fehlerhafte Authentifizierung; daraus wird kein erfolgreiches neues CI-Ergebnis abgeleitet. Einzelheiten zu Persistenzabbildung, atomaren Operationen und verbleibenden Grenzen stehen in [persistence-notes.md](persistence-notes.md).

## Swift-Repräsentation und konservative Präzisierungen

- Alle Beziehungen verwenden `EntityID<T>`; beispielsweise ist eine Actor-ID keine Reviewer-ID. Erforderliche Einzelbeziehungen sind nicht optional. Validatoren prüfen zusätzlich, ob die referenzierte ID tatsächlich existiert. Ein ResearchTask kann strukturell nicht die Fundstelle eines EvidenceLink bilden.
- `NonEmptyText` erhält den Originaltext und verweigert leere oder ausschließlich aus Leerzeichen bestehende Werte. `FieldValue<T>` unterscheidet bekannt, unbekannt mit Grund und nicht anwendbar mit Grund. `AssertedValue<T>` trennt Herkunft, Verifikation und menschlichen Prüfvermerk. Eine nach menschlicher Prüfung bestätigte KI-Extraktion darf weiterhin `aiExtracted` als Herkunft behalten.
- Der eigene `DateInterval` unterstützt offene Grenzen und eine explizite Endkonvention; bei gleichzeitiger Verwendung von Foundation ist der Typ gegebenenfalls mit `PoliticalFactCheckCore.DateInterval` zu qualifizieren. Präzision liegt einmal in `DatedValue`. Tages-, Monats- und Jahrespräzision werden als begrenzte Intervalle repräsentiert; Kalendergrenzen und die richtige Zeitzone muss der Erfassende festlegen. Unbekannte oder den Stichtag überlappende Ereigniszeiten erzeugen einen menschlichen Prüfhinweis. Das Publikationsdatum einer späteren Quelle erzeugt höchstens einen Rückblickhinweis, keinen automatischen Ausschluss.
- Quellenmetadaten wie Titel und Herausgeber liegen an SourceVersion, damit historische Fassungen ihre Metadaten behalten. Source hält die gemeinsame Identität, nicht den historischen Text. Lokale Kopie und Hash sind nur Metadaten; der Core liest keine Datei und berechnet keinen Hash.
- CriterionRevision enthält zusätzlich die konkrete PromiseRevision-ID. Damit ist festgelegt, welche Auslegung des Versprechens die Messlatte betrifft. CaseRevision speichert konkrete Revision-IDs und eingefrorene Prüfzustände; keine zweite Kopie der Inhaltstexte.
- Alle Domain-Objekte sind Werttypen mit `let`-Feldern. Inhaltliche Änderungen benötigen neue Werte und bei Revisionen neue IDs. Kontrollierte Statuswechsel erhalten die ID und den Inhalt. `RevisionRules` verweigert den Austausch historischen Inhalts unter derselben ID; spätere Speicheroperationen müssen diese Grenze ebenfalls verwenden. SourceVersion und PromiseRevision werden vollständig unveränderlich behandelt: Änderungen von Feldverifikation benötigen dort eine neue Fassung, nicht eine Änderung der alten Fassung.
- Neue Kriterienrevisionen und verifizierte zusätzliche Evidenz liefern die neuen Werte sowie ReviewRequests und aktualisierte operative Evaluationszustände als gemeinsames Ergebnis. Die aufrufende Schicht muss dieses Ergebnis später zusammenhängend speichern. Historische Kategorie, Freigabe, Manifest und Begründung bleiben erhalten. Weder eine neue CaseRevision noch eine politische Neubewertung wird automatisch erfunden.
- ReviewerIdentity ist ausschließlich menschlich; KI-Modell und Promptversion gehören zu Authorship. Der Core kann eine angegebene menschliche Identität strukturell prüfen, aber nicht feststellen, wer tatsächlich vor dem Rechner sitzt.
- Es gibt keinen automatischen Kategorienrechner. Validatoren prüfen die Voraussetzungen einer menschlich gewählten Kategorie. Freigegebene positive Kategorien brauchen stützende Evidenz; negative Kategorien brauchen relevante Evidenz, `contraryAction` widersprechende geprüfte Evidenz. Diese Mindestprüfungen ersetzen keine inhaltliche Entscheidung.

## Technische Reichweite der Invarianten

Die Nummern beziehen sich auf die Anforderungen dieses Implementierungsschritts. „Vollständig“ bezeichnet die technische Struktur bei Verwendung der Validierungs- und Änderungsfunktionen, keine Aussage über politische Wahrheit.

| Regeln | Technisch umgesetzt | Grenze |
| --- | --- | --- |
| 2, 3, 5 | Pflichtreferenzen, Auflösung SourceVersion / CriterionRevision, ResearchTask getrennt von EvidenceLink | Keine journalistische Wahrheit ableitbar. |
| 1, 4, 14, 15 | Verifiziertes Zitat und Tatsachensatz benötigen geprüfte Fundstellen; Zitat muss in einer zitierten Fundstelle wortgleich vorliegen; Handlung allein genügt nicht | Authentizität, richtige Auswahl und Kontext bleiben menschlich. |
| 6, 13 | Freigabe benötigt eine auflösbare menschliche ReviewerIdentity und Prüfzeit | Tatsächliche Identität oder eine vorgetäuschte Prüfung ist ohne Benutzerkonten nicht nachweisbar. |
| 7, 8, 9 | Leere Evidenz und bloße Kontextlinks tragen kein negatives Urteil; widersprechender Link für contraryAction; strukturierter Grund und nichtleere Begründung für notVerifiable | Aussagekraft, Vollständigkeit der Gegenbelege und Angemessenheit der Gründe bleiben fachlich. Niedrige Evidenzsicherheit sperrt abschließendes notFulfilled / contraryAction. |
| 10, 11 | Neue Revisions-ID, unveränderliche historische Werte, Replacement-Prüfung und abhängige Review-Markierung | Der Core liefert reine Ergebnisse; Phase 2.2 ergänzt transaktionale Speicherung und Audit-Schreibvorgänge im separaten Persistenzmodul. |
| 12 | Datumsrollen getrennt; Stichtag gegen Ereignis/Gültigkeit; zukünftiges Ereignis abgewiesen, spätere Veröffentlichung zulässig | Unscharfe Zeiträume und das tatsächliche Ereignisdatum brauchen menschliche Klärung. |
| 16, 17 | Bestätigte aktive Kriterien für readyForEvaluation; nur spezifizierte, benachbarte Workflowübergänge | Ob Messlatte, Materialitätsregel und Tatsachen ausreichend sind, entscheidet ein Mensch. |

Der Core enthält keine Lösch-, Speicher-, Import- oder Audit-Automatik. AuditEntry ist ein fachlicher Datenwert. Phase 2.2 ergänzt Serialisierung und Wiederladen außerhalb des unveränderten Core.

## Verbindlich gelöste Review-Semantik

CaseWorkflowState beschreibt monoton erreichte Reife. Der Case-Validator akzeptiert `approved`, wenn mindestens eine gültige historisch menschlich freigegebene Evaluation existiert, auch bei `reviewRequired` oder `superseded`. Aktuelle Arbeitsrevisionen müssen diese historische Evaluation nicht nachträglich ersetzen. Die ursprünglichen Freigabemetadaten bleiben unverändert und müssen weiter auflösbar sein.

`CaseReviews.state(of:in:)` liefert rein abgeleitet `notYetApproved`, `reviewRequired` oder `upToDate`. Es validiert seine Eingaben und verlangt für das Auflösen eines historischen Reviews eine freigegebene Ersatz-Evaluation über `replacesEvaluationID` und ein Manifest der aktuellen Revisionen/verifizierten Links. Ein anderer neuer Befund oder ein Entwurf genügt nicht. Ersatzbeziehungen werden auf Zugehörigkeit, auflösbare historische Freigabe, zeitliche Reihenfolge und Zyklen geprüft. Die vorherige Workflow-Frage ist damit fachlich gelöst; es wird kein zusätzlicher Zustand gespeichert und keine historische Kategorie verändert.

## Offene Implementierungsfragen

1. Phase 2.2 definiert atomare Persistenzoperationen für neue Evidenz und Kriterienrevisionen inklusive Review-Markierungen und Audits. Ein produktiver Freigabeworkflow sowie vollständige Archivierung und Datenschutzlöschung bleiben spätere Aufgaben.
2. Vollständige Inhaltsverifikation, Kriterienmaterialität, politische Zurechnung, tatsächliche menschliche Prüfung und Gesamtkategorie bleiben redaktionelle Entscheidungen. Eine produktive MethodologyVersion muss vor der ersten produktiven Freigabe verbindlich festgelegt werden.

Die drei verbindlichen Spezifikationsdokumente wurden ausschließlich für die vorgegebene Workflow-/Review-Semantik und deren Ersatzbeziehungen präzisiert. Der Domain-Core hängt weiterhin nicht von SwiftData ab; SwiftData liegt ausschließlich im neuen Persistenzmodul. SwiftUI, AppKit, Netzwerk, Recherche, KI-API, Dateiimport, Export, Video und Voiceover wurden nicht implementiert.

## Phase 3.2b – kleine erforderliche Core-Präzisierungen

Die einmalige separate menschliche Prüfung einer CriterionEvaluation benötigt einen kontrollierten Lifecycle-Wechsel von unreviewed/nil zu reviewed/HumanReview. RevisionRules erlauben dafür ausschließlich diesen Wechsel unter derselben ID; normalisierte Inhaltsfelder müssen exakt identisch sein. Wiederholte oder rückwirkende Änderung des Prüfers sowie jede Kategorie-/Begründungs-/Evidenzänderung bleiben verboten. Die Store-Operation erlaubt diesen Prüfschritt nur vor historischer Freigabe der Elternbewertung und prüft Reviewer und Zeitpunkt. Die bestehenden Bewertungsvalidatoren und Kategorien bleiben unverändert.

CaseReviews berücksichtigt beim erwarteten Handlungsmanifest neben aktuellen Arbeitsköpfen auch explizite ActionRevision-Referenzen aktuell verified EvidenceLinks. Ein neuer Snapshot muss für Referenzschließung auch einen älteren Handlungsstand einschließen können, wenn ein geprüfter Beleg auf ihn verweist. Ohne diese kleine Präzisierung könnte ein erstmalig korrekt freigegebener geschlossener Snapshot fälschlich reviewRequired anzeigen. Neue Arbeitsköpfe oder nicht abgedeckte geprüfte Links erzeugen weiterhin Reviewbedarf; ein Regressionstest deckt beide gleichzeitig benötigten Handlungsrevisionen ab.

MethodologyVersion 1.0 ist kanonisch und eingefroren, mit festem ID-/Metadatenstand und SHA-256 der neuen Methodikdatei. Bewertungsinhalt wird ausschließlich menschlich eingegeben. Keine automatische Gesamtwertung. Snapshot und persistierter Entwurf bleiben immutable Inhalte; Prüfung/Status sind getrennte Akte. Der vor Entwurfsspeicherung gewählte Stichtag wird noch nicht im CaseRevision gespeichert, da dieser bestehende Typ keinen Stichtag enthält. Beim Fortsetzen ist eine erneute explizite Auswahl erforderlich; die Evaluation speichert ihn dauerhaft. Freie Draft-Inhaltskorrektur über neue Datensätze und Ersatzreview bleiben spätere Aufgaben, keine stille In-place-Änderung.
