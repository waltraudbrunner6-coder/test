# Lokale Persistenz – Phase 2.2

## Aufbau

Die bisherigen Domain-Typen, Validatoren und Zustandsfolgen sowie alle vorhandenen Domain-Tests bleiben erhalten. Für Phase 3.2a ergänzt der Core eine kleine pure Prüfrahmen-/Kriterien-Neubindungsoperation. Das separate Swift-Package-Target `PoliticalFactCheckPersistence` hängt nur vom Core, Foundation und SwiftData ab. Es ist ausschließlich auf macOS verfügbar; das Package verlangt dort macOS 14 oder neuer. Swift-Tools-Version bleibt 5.9. Der Core kann weiterhin ohne SwiftData auf anderen Plattformen verwendet werden. Keine externen Dependencies.

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
- `addAction`: erste ungeprüfte ActionRevision und stabile Handlungsidentität, aktuelle Case-Referenz, menschlichen AuditEntry und gegebenenfalls lokale ReviewerIdentity gemeinsam speichern.
- `verifyAction`: ausgewählte vorhandene geprüfte Fundstellen kontrollieren, die drei asserted fields (Beschreibung, Ereignisdatum, Bereich) mit HumanReview bestätigen und eine neue immutable ActionRevision mit aktualisierten Arbeitskopf-IDs sowie AuditEntry speichern. Die alte Revision bleibt unverändert; Beteiligungen werden nicht abgeleitet oder kopiert.
- `addEvidenceDraft`: aktives bestätigtes Kriterium desselben Cases, mindestens eine vorhandene geprüfte Fundstelle sowie optional eine konkrete Handlungsrevision desselben Cases prüfen; Draft ohne HumanReview mit AuditEntry atomar speichern.
- `requestEvidenceReview`: den vom Core erlaubten Übergang `draft → needsReview` mit AuditEntry speichern; keine Verifikation.
- `verifyEvidence`: bestehenden Link über `DomainChanges.transition` und HumanReview von `needsReview` zu `verified` überführen. Derselbe interne Transaktionspfad wie `addVerifiedEvidence` verarbeitet DomainChanges-ReviewRequests, Evaluation-Status, abhängige Skripte und Audits in genau einem Save. Es entsteht keine zweite Review-/Evidence-Speicherlogik und kein neuer Bewertungsinhalt.
- `reviseCriterion`: neue Kriterienrevision mit neuer ID anlegen, optional menschlich bestätigen, aktuelle IDs aktualisieren und Review-Markierungen sowie Audits gemeinsam speichern.
- Bereits freigegebene abhängige Skripte erhalten dabei gemäß bestehendem Core den erlaubten operativen Status `superseded`: Text, Version, ursprüngliche Freigabe und Statements bleiben unverändert; der Statuswechsel wird ebenfalls auditiert. Der Core erlaubt kein aktuell freigegebenes Skript zu einer reviewbedürftigen Bewertung.

Historische Kategorien, Begründungen, Reviewer, Freigabezeitpunkte, Methodik und Snapshots bleiben erhalten. CaseWorkflowState bleibt monoton; aktueller Reviewbedarf wird weiterhin ausschließlich durch `CaseReviews.state` abgeleitet. Ein vollständiger `saveCase` darf die durch neue geprüfte Evidenz oder veränderte aktuelle Kriterien ausgelösten Review-Markierungen nicht umgehen. Eine neue Freigabe wird explizit als neue Evaluation mit neuem Snapshot und Ersatzbeziehung gespeichert, niemals automatisch erzeugt.

## Unveränderlichkeit und Löschen

Vor einem Update einer vorhandenen ID greifen `RevisionRules.validateReplacement` und zusätzliche Identitätsprüfungen. PromiseRevision, SourceVersion, ActionRevision und CaseRevision können nicht überschrieben werden; bestätigte/geprüfte Werte erlauben ausschließlich die vom Core vorgesehenen Statuswechsel. MethodologyVersion, AuditEntry und ScriptStatement werden ebenfalls konservativ unveränderlich gespeichert.

Es gibt keine Cascade-Delete-Regeln und keine automatische Datenbereinigung. Ein bestehender Fall darf über `saveCase` keine zuvor gespeicherten IDs aus seinem Manifest entfernen, auch keine momentan unreferenzierten Fundstellen. Historische Löschung wird verweigert. `deleteDraftCase` ist ausschließlich für candidate/documented ohne Snapshots, Evaluationen oder Skripte erlaubt. Es entfernt nur Datensätze, die kein anderes Fallmanifest verwendet. Vollständige Datenschutzlöschung und Archivierungsoberfläche bleiben spätere Aufgaben.

## Schema und Migration

SwiftData-Schema-Version: **1.0.0**, Payload-Format: **1**. `PersistenceMigrationPlan` registriert die erste Version ohne Migrationsstufen. Spätere Versionen erhalten eigene VersionedSchema-Typen und explizite MigrationStages sowie DTO-/Payload-Migrationen. Migrationen müssen UUIDs, Revisionsinhalte und historische Manifeste erhalten. Unbekannte Payload-Formate werden derzeit abgewiesen.

## Tests und Prüfstand

Die 42 bisherigen Persistence-Tests bleiben unverändert. Hinzu kommen 15 Tests für manuelle Handlungen/Evidenz: erste Revision und ungeprüfte Felder, neue Prüfungsrevision bei erhaltener Historie, Rollback einschließlich Reviewer/Audit, exakte Draft-Referenzen, fehlende oder ungeprüfte Fundstellen, fehlendes/fremdes Kriterium, Draftkriterium, ungültige Datumsrolle, fehlende Handlungsrevision, doppelte IDs, verbotener Statussprung, menschlich geprüfte Evidenz nach echter Wiederöffnung eines temporären Stores und unveränderte historische Bewertungen bei ReviewRequired. Ausschließlich synthetische Inhalte; keine Benutzerstores. Zusammen mit 90 Core- und 13 AppModel-Tests werden 160 Tests erwartet.

Der Phase-3.1-Stand `3a484a6261621dd21c94a023d6c0a0f403799147` ist inzwischen laut externer Nutzerprüfung mit Apple Swift 6.1.2 erfolgreich: 160 Tests, 0 Fehler, nativer arm64-App-Build erfolgreich. Lokal fehlen Swift und Xcode weiterhin. Der unveränderte macOS-15-Workflow führt zuerst `swift test`, danach den nativen App-Build aus; neue Änderungen benötigen einen eigenen CI-Nachweis.

Handlungen sind noch keine Bewertung; EvidenceRelationship ist keine Kategorie. Der Store verifiziert ausschließlich nach expliziter menschlicher Aktion und Core-Prüfung. Attribution wird nicht aus Parteizugehörigkeit abgeleitet. Keine automatische Evaluation, Snapshot-Erstellung oder Methodikversion; Bewertung folgt in Phase 3.2. Schema-Version und Payload-Format bleiben unverändert, da nur bestehende Domain-/DTO-Typen verwendet werden.

## Grenzen

- Ein lokaler Writer; keine Mehrprozess-/Mehrbenutzer-Synchronisierung. UUID-Duplikate werden explizit geprüft statt SwiftData-Unique-Upserts verwendet; andere direkte Writer sind nicht unterstützt.
- Vollständiges Laden/Validieren des Fallgraphen und Tabellenabfragen statt Indizes für jedes fachliche Feld: ausreichend für den einzelnen MVP-Fall, später bei Bedarf optimieren.
- Identitäts- und Auditdaten belegen strukturell menschliche Freigabe, nicht die tatsächliche Person vor dem Rechner oder den Wahrheitsgehalt eines Belegs. Journalistische Prüfungen bleiben beim Menschen.
- Der Store übernimmt bereits definierte Domain-Regeln und ergänzt Speicherintegrität; er entscheidet keine Kategorien und erzeugt keine neuen politischen Inhalte.
- Keine komplexen Migrationen, Archivierungs-API, Backup- oder Datenschutzlöschstrategie. Im Persistence-Modul keine UI, SwiftUI, AppKit, Netzwerk-/KI-Integration, Recherche, Dateiimport, Export, Video, Voiceover, TTS oder Cloud-Synchronisierung. CloudKit ist explizit deaktiviert.

## Phase 3.2a: transaktionale Bewertungsreife

`verifyPromiseForEvaluationReadiness` lädt den Case in einem frischen Context, prüft die lokale ReviewerIdentity über den Core und ruft `DomainChanges.verifyPromiseForReadiness` auf. Der Core verantwortet die neue immutable PromiseRevision (Kontext / gleiche Sprecher-ID), den unveränderten Erhalt des geprüften Zitats und die neue Draft-Revision jedes aktiven Kriteriums. Der Store persistiert ausschließlich die zurückgegebenen Werte, aktualisierte Arbeitskopf-IDs sowie getrennte AuditEntries für PromiseRevision, Kontext, Sprecher und jede Kriterienneubindung. Ein Fehler verwirft sämtliche Änderungen einschließlich neu hinzugefügter Reviewer-Datensätze und Audits.

Die Fundstellen müssen im geladenen Case vorhanden und live geprüft sein; ihre SourceVersions müssen ebenfalls verified sein. Historische/superseded Belege sind in diesem neuen Prüfschritt ausgeschlossen. Alte PromiseRevisions, CriterionRevisions und EvidenceLinks werden nicht überschrieben, entfernt, superseded oder automatisch neu zugeordnet. Bestätigte Kriterien beginnen nach Neubindung erneut als Draft ohne confirmation. Eigene spätere Neubewertung bleibt erforderlich, wenn bereits CaseRevision oder CaseEvaluation existiert; dann blockiert die Operation vollständig.

`advanceEvaluationReadiness` kapselt ausschließlich die Ziele verified und readyForEvaluation. Die erlaubte Folge und Voraussetzungen bestimmt unverändert `DomainChanges.transition`. Statuswechsel und menschlicher AuditEntry werden gemeinsam gespeichert; fehlende Voraussetzungen hinterlassen keinen Teilzustand. Keine neue CaseRevision, CriterionEvaluation, CaseEvaluation, MethodologyVersion, Skriptfassung oder Kategorie entsteht. `readyForEvaluation` ist noch keine Bewertung. Schema 1.0.0 und Payload-Format 1 bleiben unverändert; das Core-Änderungsergebnis ist kein Persistenzmodell.

Extern bestätigter Ausgangsstand: Commit `3a484a6261621dd21c94a023d6c0a0f403799147`, 160 erfolgreiche Tests und nativer arm64-App-Build mit Apple Swift 6.1.2. Für diesen Schritt sind 30 neue Tests vorgesehen (16 Core, 8 Persistence, 6 AppModel), insgesamt 190. Der Workflow bleibt unverändert: zuerst swift test, anschließend nativer macOS-arm64-App-Build. Das Ergebnis dieses neuen CI-Laufs ist separat zu verifizieren.

Lokale Prüfergebnisse für Phase 3.2a: swift --version, swift test und xcodebuild enden jeweils mit Exit 127, weil die Tools fehlen. git diff --check ist erfolgreich. Erfolgreiche macOS-Kompilierung, Testausführung und App-Build dieser Änderungen sind noch nicht nachgewiesen.
