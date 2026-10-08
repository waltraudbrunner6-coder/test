# PoliticalFactCheck Editorial Package – Format 1

## Status und Architektur

Phase 4.3 implementiert Offline-Export/Wiederimport eines redaktionell freigegebenen Falls. Extern bestätigte Basis: 68a45367a3b5af0ba0817617fc114415e520d5db, Apple Swift 6.1.2, 370 erfolgreiche Tests, nativer arm64-App-Build erfolgreich. Der neue Stand benötigt einen eigenen CI-Nachweis.

`PoliticalFactCheckExport` ist ein separates macOS-Package-Target (Foundation, CryptoKit, Core, Scripting), ohne SwiftData/SwiftUI/Netzwerk. Core bleibt unverändert und ohne Codable-Erweiterungen. Das Exportmodul verantwortet explizite v1-DTOs, Mapping, Gate, Kodierung, Dokumentdarstellung, Hashes und Datei-I/O. Persistence importiert den validierten Graphen atomar; AppModel lädt frische Fälle und koordiniert Vorschau/Bestätigung. Native Panels existieren ausschließlich in der App.

Die transportbezogenen DTO-Mappings sind als eigene v1-Kopie der bereits geprüften feldweisen Domain-Mappings eingefroren. Sie sind unabhängig von den internen Persistenz-DTOs und binären Store-Payloads; spätere Persistenzänderungen ändern den Vertrag nicht automatisch. Diese bewusste Duplikation benötigt bei künftigen Domain-Erweiterungen einen expliziten Format-/Mappingreview. Keine Repository-/Migration-Frameworks.

## Verzeichnis und Manifest

Ein neues Verzeichnis `<Fall>.politicalfactcheck/` enthält exakt:

```
manifest.json
case-report.json
case-archive.json
script.md
sources.md
storyboard.md
methodology.md
README.md
```

Kein ZIP, keine Drittanbieterbibliothek, keine Anhänge, keine automatische Veröffentlichung. Das Manifest enthält `schemaVersion: 1`, `packageType: "PoliticalFactCheck Editorial Package"`, `exportFormatVersion: "1"`, exportedAt, Case-/Evaluation-/CaseRevision-/Script-UUID, Scriptversion, MethodologyVersion-ID/Version/Hash und eine Liste `{filename, sha256, byteCount}` aller sieben Nutzdateien. Das Manifest hasht sich nicht selbst. SHA-256 wird über die tatsächlich geschriebenen UTF-8-/JSON-Bytes berechnet; es ist keine Signatur oder Bestätigung von Echtheit/menschlicher Identität.

Die Dateiliste ist fest; zusätzliche Dateien, fehlende/duplizierte Namen, symbolische Links und fremde Dateipfade werden abgewiesen. Lesen begrenzt jede Datei auf 16 MiB und das Paket auf 64 MiB. Ziel muss explizit ausgewählt werden und neu sein; vorhandene Ziele werden nicht ersetzt. Der Export schreibt vollständig in ein temporäres Geschwisterverzeichnis und verschiebt erst danach an das Ziel. Bei Fehler bleibt kein teilweise erzeugtes Zielpaket. Ein lokaler Writer bleibt Voraussetzung; keine koordinierte Mehrprozess-/Angreifer-Dateisystem-Garantie.

## Publication Gate

Gewählte CaseEvaluation muss aktuell approved mit HumanReview sein, gewähltes Script approved mit HumanReview und derselben Evaluation-ID. DomainValidator prüft Skript, Satzreviews, Tatsachenbelege, Snapshotbindung, Evaluation, Kriterien, Quellen/Evidenz und gesamten Graphen. CaseReviews darf keinen offenen Reviewbedarf zeigen. Draft, needsReview, reviewRequired und superseded sind für die ausgewählte Ausgabe gesperrt. Andere historische Fassungen bleiben im Archiv mit tatsächlichem Status erhalten; durch Export werden sie nicht neu freigegeben.

Das AppModel prüft für die Anzeige über dieselbe Exportvalidierung. Vor Dateischreiben lädt es den Fall frisch und prüft nochmals. Keine vereinfachte UI-Freigabe, politische Neubewertung oder automatische Satzprüfung.

## case-report.json – ausgewählte redaktionelle Sicht

`EditorialCaseReportV1` besitzt feste Codable-Felder: schemaVersion, title, caseID, originalPromise (vollständige konkrete Revision mit Wortlaut, Aussagezeit, Kontext und asserted Identitätsbezügen), speaker/party (dokumentierte Actor-Datensätze oder nil), criteria, evaluation, criterionEvaluations, methodology, evidenceLinks, actions, participations, sources, sourceVersions, excerpts, reviewers, script, statements, statementSources und referenceKeys.

Evaluation und Kinder enthalten unverändert Stichtag, Kategorie, Confidence, Begründung, Fakten/Interpretationen/Unsicherheiten, NotVerifiableReasons, verwendete/Gegenbeleg-IDs und Reviews/Approvals. statementSources bindet Satz-ID an lesbare EX-/EV-Keys; referenceKeys löst SRC-/EX-/EV-Keys explizit auf Entitätstyp und konkrete UUID auf. Relevante Fundstellen umfassen gewählte Skript-/Bewertungsbelege sowie Original-/Handlungskontext; Quellenfassungen sind konkret. Reihenfolge des Skripts folgt position. Keine freie [String: Any]-Berichtsstruktur, keine generierten politischen Formulierungen.

## case-archive.json – vollständiger verlustfreier Fall

`PortableCaseArchiveV1` besteht aus schemaVersion und graph. graph besitzt feste Arrays für reviewers, cases, actors, affiliations, promises, promiseRevisions, criteria, criterionRevisions, sources, sourceVersions, excerpts, actions, actionRevisions, participations, evidenceLinks, caseRevisions, criterionEvaluations, caseEvaluations, methodologies, researchTasks, auditEntries, scripts und statements.

Jede fachliche UUID wird als `{kind, value}` mit exakter Entitätstypkennung transportiert. Falsche Typkennung oder fehlende Referenz wird abgewiesen; UUIDs werden niemals neu erzeugt. Alle Domainfelder sind explizit gemappt: Herkunft, asserted values, Datum/Präzision/Rolle/Zeitzoneninformation, Kontext, Reviews, Status, operative Reviewgründe und ursprüngliche Freigaben. CaseRevision bleibt ID-Manifest mit eingefrorenen Statuswerten. Kein Umbiegen historischer Referenzen auf aktuelle Heads.

Unbekannt und nicht anwendbar bleiben explizite Enumobjekte mit Grund, nicht leerer Ersatztext. Die v1-Enumdarstellung ist die eingefrorene Codable-Form, etwa `{ "known": { "_0": ... } }`, `{ "unknown": { "_0": "Grund" } }`, `{ "notApplicable": { "_0": "Grund" } }`; Authorship entsprechend human/ai/system. Normale Domainstatuswerte sind explizit gemappte Strings. Unbekannte Enums, unbekannte JSON-Felder oder Typformen sind Fehler, keine Defaults.

Historisch superseded Quellen/Fundstellen behalten tatsächlichen operativen Status und ursprüngliche Prüfung; ein Domain-validierter Snapshot kann deren frühere Verifikation belegen. Bei zusätzlicher Prüfung alter PromiseRevisions werden ausschließlich entsprechende Statusdiagnosen für diese nachweislich im Snapshot verifizierten IDs akzeptiert. Keine Änderung gespeicherter Werte oder allgemeine Lockerung des Core. Historische Audits werden unverändert übernommen. Case-eigene Objekte müssen zu genau einem Case/Promise gehören; fremde Eltern und verwaiste Kinder/Auditreferenzen sind verboten. Geteilte Quellen/Akteure/Reviewer werden mit ihren benötigten Referenzen vollständig mitgeführt.

Das vollständige Archiv kann noch ungeprüfte Arbeits-/Recherchetexte und ältere Skriptfassungen enthalten. Nur der ausgewählte Bericht/das ausgewählte Skript ist finale redaktionelle Ausgabe. Reviewer- und Auditmetadaten sind personenbezogene fachliche Nachvollziehbarkeit, keine API-Zugangsdaten; vor Weitergabe sind Rechte und Datenschutz zu prüfen.

## Datumswerte und Determinismus

Jeder absolute Date-Wert wird als `{utc, referenceSeconds}` gespeichert: utc ist ISO-8601 UTC mit Fractional Seconds und Z; referenceSeconds ist die roundtripfähige Double-Zahl der Sekunden seit 2001-01-01T00:00:00Z (Swift/Foundation Referenzepoche). Die UTC-Anzeige besitzt Millisekunden, der zusätzliche exakte Wert erhält auch feinere Date-Präzision unverändert. Decode baut Date aus referenceSeconds und verlangt identische UTC-Darstellung; Konflikte und nicht finite Werte werden abgewiesen. DatedValue behält Rolle, Präzision, Unknown-Grund, offene Intervallgrenzen und endInclusive separat. Zeitzonenmetadaten bleiben fachliche Originaldaten; serialisierte absolute Zeit ist UTC.

JSON-Schlüssel sind sortiert. Äußere Graph-Arrays ohne fachliche Reihenfolge sind nach UUID sortiert. Referenzlisten und Snapshotreihenfolgen bleiben unverändert: sie bestimmen unter anderem stabile SRC-/EX-/EV-Keys. Sätze werden im Bericht/Markdown nach position sortiert. Gleicher fachlicher Graph und gleicher exportedAt erzeugen dieselben Bytes. Bei anderem exportedAt ändert sich nur manifest.json.

## Menschenlesbare Dokumente und Methodik

script.md enthält Falltitel, Kategorie, Stichtag, Methodik, Scriptversion/-status, Zielzeit als ungemessenen Planwert, geordnete freigegebene Texte mit Fact/Interpretation/Frage/Einschränkung, Quellenkeys und vorhandenen Unsicherheiten. sources.md enthält relevante Quellenfassung, Titel/Publisher/Autor/URL/Archiv-URL soweit vorhanden, Publikations-/Abrufdatum, Verifikation, Locator, Excerpt/Kontext und Satzpositionen. Fehlende Metadaten werden ausdrücklich als nicht dokumentiert angezeigt. Kein URL-Abruf.

storyboard.md verwendet jeden vorhandenen Satz als möglichen Abschnitt: Position, Typ, Text, EX-/EV-Keys, Unsicherheit und **Visualhinweis: Noch festzulegen**. Keine Bilder, Motive, Visualideen oder Einzelszenendauern werden erfunden. Visualplanung folgt in Phase 5.

methodology.md ist bytegleich die gebündelte kanonische docs/methodology-v1.0.md. Version 1 exportiert die gespeicherte kanonische MethodologyVersion 1.0; ID, vollständige Metadaten und SHA-256 müssen übereinstimmen. Hashkonflikt blockiert. Zukünftige Methodikfassungen benötigen bewusst neue Unterstützung, kein stilles Ersetzen.

README.md benennt Case, Evaluation, Script, Methodik und Stichtag, den historischen Stand, fehlende automatische Aktualisierung, Archiv-/Berichtsunterschied und die Grenzen von Hashes. Markdown-Darstellung fügt ausschließlich Struktur/Labels und neutrale Platzhalter hinzu. Markdown-/HTML-Metazeichen werden escaped; keine neue politische Interpretation. Bei Import werden Bericht und Markdown erneut aus dem Archiv abgeleitet und mit Paketinhalt verglichen, damit auch separat geänderte Texte bei neu berechnetem Hash nicht akzeptiert werden.

## Import, Kollisionen und Transaktion

Paket auswählen → vollständig lesen → Manifest/Schema/Dateiliste/Bytehashes/Methodology prüfen → DTO Decode/Referenzmapping → DomainValidator/Graph-/Zusatzprüfung → Publication Gate → Bericht/Dokumentgleichheit → Importvorschau. Vor Bestätigung wird nichts gespeichert. Bei Bestätigung wird das Paket erneut vollständig geprüft; Zusammenfassung und Manifest müssen unverändert sein.

LocalCaseStore.importEditorialPackage verwendet genau eine vorhandene frische ModelContext-Transaktion. Existiert die Case-ID bereits: **Dieser Fall ist bereits vorhanden.** Kein Merge, Überschreiben oder UUID-Umschreiben. Identische gemeinsam genutzte Datensätze, etwa kanonische Methodik, können wiederverwendet werden; unterschiedliche Inhalte unter vorhandener ID scheitern an den bestehenden Store-Prüfungen mit vollständigem Rollback. Kein Teilimport, keine neuen Audit-Zeitpunkte und keine automatische Reparatur. Nach Import wird der Case frisch geladen; fachliche Gleichheit umfasst IDs, Revisionen, Snapshots, Bewertungen, Approvals, Evidenz, Skripte, Aufgaben und Audits.

## Secrets, Portabilität und Grenzen

Der Vertrag enthält keine Environment-/UserDefaults-/OpenAI-Laufzeitstruktur. Kein API-Key, Authorization, safety_identifier, HTTP-Request/Response-Dump oder Netzwerkfehlerobjekt wird exportiert. Ein konservativer Markercheck blockiert zusätzlich offensichtlich in Freitext eingefügte Credential-/Request-Dumps statt sie still zu entfernen. Er ist keine allgemeine Geheimniserkennung für beliebige manuell eingetragene Texte; Sensitivitätsprüfung bleibt redaktionell. AI-Provider-/Prompt-Herkunft eines gespeicherten Skripts bleibt zulässig.

Jegliche localCopyReference sowie file:-URLs/absolute lokale URL-Pfade verursachen den kontrollierten Fehler „Portable Export lokaler Anhänge wird noch nicht unterstützt.“ Keine still verlorenen Referenzen, kein attachments-Subsystem. Externe HTTP-URLs werden ausschließlich als gespeicherte Daten übernommen.

Version 1 hat noch keine Migration, unterstützt keine ZIP-Kompression, digitalen Signaturen, Anhänge, Merge, Backup beliebiger Drafts, Video, TTS, Visualrecherche, Cloud oder Publishing. Hashes und formal erhaltene HumanReviews beweisen keine politische Wahrheit oder Herkunft eines fremden Pakets. Reimport verbessert keine Quellenlage und trifft kein neues Urteil.


## Tests und tatsächlicher Prüfstand

85 neue Tests: 66 Export, 9 Persistence, 10 AppModel. Erwartet **455 insgesamt**: 139 Core, 71 Scripting, 119 Persistence, 60 AppModel, 66 Export. Alle 370 bisherigen Testdateien bleiben bytegleich. Offline-Tests umfassen Publication Gate, Dateihashes, kanonischen Methodikhash, exakte Zeitwerte, UUID-/Enum-/Graphintegrität, Bericht/Markdown, deterministische Ausgabe, veränderte Dateien trotz aktualisierter Hashes, fremde IDs, lokale Anhänge, Secrets-Marker, Symlinks, atomare Verzeichnisablage, historische Revisionen/Approvals/Snapshotstatus, frischen Store und vollständigen Rollback bei ID-Konflikten sowie Importvorschau/Abbrechen/Bestätigung. Keine echten politischen Testdaten oder API-Anfragen.

Tatsächliche lokale Aufrufe: swift --version, swift test und xcodebuild scheitern mit Exit 127 (command not found). git diff --check ist erfolgreich. gh run list liefert Forbidden. Der unveränderte macOS-15-Workflow führt nach Push zuerst swift test und danach den nativen arm64-App-Build aus. Für diesen neuen Stand sind weder Test- noch Build-Erfolg behauptet; externe CI-Verifikation steht aus.

Die gestagte Diff-Prüfung meldet ausschließlich die absichtlich bytegleich kopierte abschließende Leerzeile der kanonischen Methodikressource. Alle übrigen Dateien bestehen git diff --cached --check. Die Ressource wird wegen ihres eingefrorenen SHA-256 nicht getrimmt.
