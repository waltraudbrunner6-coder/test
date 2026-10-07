# Lokale Persistenz – Phase 2.2

## Aufbau

`PoliticalFactCheckCore` und seine 90 bisherigen Domain-Tests bleiben unverändert. Das separate Swift-Package-Target `PoliticalFactCheckPersistence` hängt nur vom Core, Foundation und SwiftData ab. Es ist ausschließlich auf macOS verfügbar; das Package verlangt dort macOS 14 oder neuer. Swift-Tools-Version bleibt 5.9. Der Core kann weiterhin ohne SwiftData auf anderen Plattformen verwendet werden. Keine externen Dependencies.

`PersistenceSchemaV1` enthält 23 konkrete SwiftData-Modelle, einschließlich der bereits vorhandenen minimalen Script-Typen. Jeder Datensatz speichert seine fachliche UUID, eine Formatnummer und eine binäre Property-List-Repräsentation seiner expliziten DTO-Felder. Der Case-Datensatz enthält zusätzlich ein geordnetes Manifest aller zum geladenen Fallgraphen gehörenden IDs. Es handelt sich nicht um einen einzigen serialisierten Fall: Jede fachliche Entität besitzt einen eigenständigen Datensatz.

Diese kompakte Abbildung verzichtet bewusst auf SwiftData-Objektbeziehungen. Beziehungen werden als UUID plus überprüfter Entitätstyp gespeichert und beim Laden explizit aufgelöst. Source → SourceVersion → SourceExcerpt, konkrete Kriterien-/Handlungsrevisionen, Beteiligungen und Evaluation-Eltern bleiben dadurch eindeutig. Historische CaseRevision-Manifeste enthalten weiterhin konkrete IDs und eingefrorene Zustände, keine Verweise auf wechselnde aktuelle Objekte. Dies ist interne Speicherung, keine Import-/Export-Funktion.

## Mapping und Fehler

`Mapping/DomainRecords.swift` bildet jedes Domain-Feld explizit in beide Richtungen ab. Gemeinsame DTOs erhalten Herkunft, unbekannt/nicht anwendbar mit Grund, Verifikation, Fundstellen, menschliche Prüfvermerke, Datumsrollen, Präzision und offene Intervallgrenzen. UUIDs werden nicht neu erzeugt. Domain-IDs bleiben typisiert; falsche gespeicherte Typkennungen werden abgewiesen.

Alle Reads und Writes validieren den vollständigen DomainContext mit den bestehenden Domain-Validatoren. Zusätzlich prüft die Persistenz die Fallzugehörigkeit, Manifest-Mitgliedschaft, referenzierte Datensätze, Duplikate, Rückbeziehungen von Evaluations-/Script-Kindern und die Übereinstimmung zwischen Datensatz-ID und Payload-ID. Ungültige Enums, fehlende Felder, beschädigte Payloads, unbekannte Formatnummern und fachliche Fehler liefern strukturierte `PersistenceError`-Werte. Keine Reparatur, Default-Ersatzwerte oder politische Bewertung.

## Store und Transaktionen

`LocalCaseStore` bietet `inMemory()`, `at(url:)`, `saveCase`, `loadCase`, `listCases` und `deleteDraftCase`. Ein Save erwartet genau einen vollständigen, referenziell geschlossenen Case-Graphen. Gemeinsame Akteure, Quellen oder Reviewer können in mehreren Fallmanifesten vorkommen; erstmaliges Einbringen einer bereits gespeicherten ID mit anderem Inhalt wird verweigert. Vor dem Commit werden auch die übrigen gespeicherten Fälle validiert, damit gemeinsame Daten keine fremden Referenzen beschädigen. Eine Entwurfs-Löschung prüft ebenfalls die anderen Manifeste vor der Bereinigung.

Jede Operation verwendet einen frischen ModelContext; Autosave ist deaktiviert. Ein Schreibvorgang speichert erst nach sämtlichen Prüfungen einmalig, Fehler führen zu Rollback. Es werden keine verwalteten SwiftData-Objekte an Aufrufer zurückgegeben. `@MainActor` serialisiert die synchronen Operationen für den vorgesehenen einzelnen lokalen Writer. Die App soll eine Store-Instanz pro Container verwenden.

Konkrete Fachoperationen:

- `addVerifiedEvidence`: geprüften Link, DomainChanges-Review-Markierungen und AuditEntry-Datensätze gemeinsam speichern.
- `reviseCriterion`: neue Kriterienrevision mit neuer ID anlegen, optional menschlich bestätigen, aktuelle IDs aktualisieren und Review-Markierungen sowie Audits gemeinsam speichern.
- Bereits freigegebene abhängige Skripte erhalten dabei gemäß bestehendem Core den erlaubten operativen Status `superseded`: Text, Version, ursprüngliche Freigabe und Statements bleiben unverändert; der Statuswechsel wird ebenfalls auditiert. Der Core erlaubt kein aktuell freigegebenes Skript zu einer reviewbedürftigen Bewertung.

Historische Kategorien, Begründungen, Reviewer, Freigabezeitpunkte, Methodik und Snapshots bleiben erhalten. CaseWorkflowState bleibt monoton; aktueller Reviewbedarf wird weiterhin ausschließlich durch `CaseReviews.state` abgeleitet. Ein vollständiger `saveCase` darf die durch neue geprüfte Evidenz oder veränderte aktuelle Kriterien ausgelösten Review-Markierungen nicht umgehen. Eine neue Freigabe wird explizit als neue Evaluation mit neuem Snapshot und Ersatzbeziehung gespeichert, niemals automatisch erzeugt.

## Unveränderlichkeit und Löschen

Vor einem Update einer vorhandenen ID greifen `RevisionRules.validateReplacement` und zusätzliche Identitätsprüfungen. PromiseRevision, SourceVersion, ActionRevision und CaseRevision können nicht überschrieben werden; bestätigte/geprüfte Werte erlauben ausschließlich die vom Core vorgesehenen Statuswechsel. MethodologyVersion, AuditEntry und ScriptStatement werden ebenfalls konservativ unveränderlich gespeichert.

Es gibt keine Cascade-Delete-Regeln und keine automatische Datenbereinigung. Ein bestehender Fall darf über `saveCase` keine zuvor gespeicherten IDs aus seinem Manifest entfernen, auch keine momentan unreferenzierten Fundstellen. Historische Löschung wird verweigert. `deleteDraftCase` ist ausschließlich für candidate/documented ohne Snapshots, Evaluationen oder Skripte erlaubt. Es entfernt nur Datensätze, die kein anderes Fallmanifest verwendet. Vollständige Datenschutzlöschung und Archivierungsoberfläche bleiben spätere Aufgaben.

## Schema und Migration

SwiftData-Schema-Version: **1.0.0**, Payload-Format: **1**. `PersistenceMigrationPlan` registriert die erste Version ohne Migrationsstufen. Spätere Versionen erhalten eigene VersionedSchema-Typen und explizite MigrationStages sowie DTO-/Payload-Migrationen. Migrationen müssen UUIDs, Revisionsinhalte und historische Manifeste erhalten. Unbekannte Payload-Formate werden derzeit abgewiesen.

## Tests und Prüfstand

42 neue XCTest-Testmethoden: Roundtrips aller 23 Typen, frische Contexts, getrennte Quellenfassungen/Revisionen, konkrete Snapshot-IDs, ReviewRequired mit Audits, neue freigegebene Ersatzbewertung, konservatives Löschen, Rollback, beschädigte Beziehungen/Payloads, doppelte IDs, falsche ID-Typen und Statuswerte. Ausschließlich synthetische Inhalte. Standardmäßig In-Memory; ein separater Wiederöffnungstest verwendet ausschließlich einen eigenen temporären Ordner und entfernt ihn anschließend.

Die 90 bisherigen Domain-Tests wurden nicht verändert. Deren Ausgangsstand `b114ee40015e28c17e26cd1555ba555f63100e6b` ist laut bestätigtem Nutzerbericht auf macOS-15 mit Apple Swift 6.1.2 erfolgreich (90 Tests, 0 Fehler). Dies ist kein Testnachweis für die neue Persistenzschicht.

Lokal fehlen `swift` und `swiftc`; `swift --version` und `swift test` enden mit Exit 127. Die bestehende macOS-15-CI führt nun beide Targets mit `swift test` aus. Ein erfolgreicher neuer Compile-/Testlauf ist derzeit **nicht verifiziert**; GitHub-CLI-Authentifizierung und Actions-Lesezugriff sind in dieser Umgebung fehlerhaft. Statische Klammer-/Initialisiererprüfung und `git diff --check` ersetzen die macOS-Ausführung nicht.

## Grenzen

- Ein lokaler Writer; keine Mehrprozess-/Mehrbenutzer-Synchronisierung. UUID-Duplikate werden explizit geprüft statt SwiftData-Unique-Upserts verwendet; andere direkte Writer sind nicht unterstützt.
- Vollständiges Laden/Validieren des Fallgraphen und Tabellenabfragen statt Indizes für jedes fachliche Feld: ausreichend für den einzelnen MVP-Fall, später bei Bedarf optimieren.
- Identitäts- und Auditdaten belegen strukturell menschliche Freigabe, nicht die tatsächliche Person vor dem Rechner oder den Wahrheitsgehalt eines Belegs. Journalistische Prüfungen bleiben beim Menschen.
- Der Store übernimmt bereits definierte Domain-Regeln und ergänzt Speicherintegrität; er entscheidet keine Kategorien und erzeugt keine neuen politischen Inhalte.
- Keine komplexen Migrationen, Archivierungs-API, Backup- oder Datenschutzlöschstrategie. Keine UI, SwiftUI, AppKit, Netzwerk-/KI-Integration, Recherche, Dateiimport, Export, Video, Voiceover, TTS oder Cloud-Synchronisierung. CloudKit ist explizit deaktiviert.
