# Technische MVP-Abnahme – Phase 4.4

## Prüfstand und Freigabegrenze

Extern bestätigte Basis: `df027bafca4da0d84cebe90f113f349344f93966`, Apple Swift 6.1.2, 455/455 Tests, 0 Fehler und nativer macOS-arm64-Build mit `BUILD SUCCEEDED`. Phase 4.4 ergänzt acht Cross-Layer-Tests; erwartet **463 Tests**. Die 455 bestehenden Tests bleiben unverändert.

Die neuen Tests sind bis zu ihrem eigenen erfolgreichen macOS-CI-Lauf **nicht verifiziert**. Lokal fehlen Swift und Xcode. Ein statischer Review ersetzt keine Ausführung. Der bestehende Workflow bleibt: `swift test`, anschließend nativer arm64-App-Build. Die tatsächlichen lokalen Versuche enden mit Exit 127 (`command not found`).

Technisch READY verlangt einen erfolgreichen Lauf aller Tests einschließlich `MVPAcceptanceTests` und `BUILD SUCCEEDED`. Dann gilt ausschließlich `MVP TECHNICALLY READY FOR REAL-CASE ACCEPTANCE`. Die reale journalistische Abnahme bleibt ein eigener menschlicher Schritt gemäß [mvp-real-case-acceptance.md](mvp-real-case-acceptance.md). Keine automatische politische Abnahme und kein `MVP FULLY ACCEPTED` durch CI.

## Inventar des vorhandenen produktiven Pfads

| Arbeitsschritt | Oberfläche / öffentliche Operation |
| --- | --- |
| Leerer Store, Prüfername, erster Draft | Empty State / Neuer Fall; `reviewerName`, `createDraftCase` |
| Quelle und Originalfundstelle | Quelle hinzufügen; `addSource`, `verifyExcerpt`, `verifyOriginalQuote`, `markDocumented` |
| Prüfrahmen und Reife | Kriterium hinzufügen; `addCriterionDraft`, `verifyPromiseForEvaluationReadiness`, `confirmCriterion`, `markVerified`, `prepareForEvaluation` |
| Handlung und Evidenz | Handlung hinzufügen/prüfen; `addAction`, `verifyAction`, `addEvidenceDraft`, `requestEvidenceReview`, `verifyEvidence` |
| Manuelle Bewertung | Neue Bewertung / Snapshot weiterbewerten; `startEvaluationSnapshot`, `createEvaluationDraft`, `reviewCriterionEvaluation`, `submitEvaluationForReview`, `approveEvaluation` |
| Skript und Satzprüfung | Manuellen Entwurf anlegen oder Provider; `createManualScript` / `generateScript`, `reviewScriptStatement`, `submitScriptForReview`, `approveScript` |
| Paket und Wiederimport | Exportbereich / Import-Toolbar; `exportEditorialPackage`, `prepareEditorialImport`, `confirmEditorialImport` |

AppModel delegiert an konkrete LocalCaseStore-Transaktionen und bestehende Core-Operationen. Kriterien werden nach der Kontext-/Sprecherprüfung an eine neue PromiseRevision gebunden und erneut bestätigt. Keine Statusabkürzung oder approved-Seed im neuen Test. Kategorien und Confidence sind explizite synthetische menschliche Eingaben, keine aus Parteiidentität oder EvidenceRelationship abgeleiteten Ergebnisse.

## Automatisierte Abnahmematrix

Alle acht Tests liegen in `Tests/PoliticalFactCheckAppModelTests/MVPAcceptanceTests.swift`, verwenden ausschließlich synthetische Texte, isolierte UserDefaults und temporäre lokale SwiftData-Stores. Kein produktiver Store, echter API-Key oder Live-Netzwerk.

| Test | Nachweis bei erfolgreicher Ausführung |
| --- | --- |
| `testEmptyStoreToFakeScriptExportImportAndDiskReopen` | Vollständiger Pfad aus leerem Store, Fake-Provider, explizite Reviews/Freigaben, Export und Import in frischen Store; Wiederöffnung nach Bewertungsfreigabe, Skriptfreigabe und Import. |
| `testEntireWorkflowWorksWithManualScriptAndNoProvider` | Fehlender Prüfername erzeugt keinen Case; danach gesamter manueller Pfad bis Export ohne KI. |
| `testNewVerifiedEvidenceRequiresReviewAndBlocksScriptAndExport` | Neue Evidenz durch draft → needsReview → verified; historisch approved Case bleibt approved, Evaluation reviewRequired, Skript superseded; historisches Urteil/Approval/Snapshot/Statements unverändert, Ausgabe und neue Skripte blockiert, Zustand nach Reopen erhalten. |
| `testMissingEvidenceCanBeHumanApprovedAsNotVerifiableAndRoundtripped` | Ohne spätere Evidenz: explizite missingEvidence, low Confidence, menschliche Kriterien-/Gesamtprüfung, freigegebene Einschränkung im Skript, Export/Import/Reopen verlustfrei. |
| `testOfflineOpenAIFailuresPreserveCompleteCaseAndManualFallback` | Fehlender Key, HTTP-503, Timeout und Transportfehler über ausschließlich lokale URLProtocol-Stubs; vollständiger Graph unverändert, danach manueller Skriptworkflow möglich. |
| `testExportFailuresNeverChangeApprovedDomainData` | Schreibfehler, bestehendes Ziel und falsche Zielendung ändern keine Falldaten/Reviews; vorhandene Dateien bleiben erhalten. |
| `testTamperedImportAndCaseCollisionLeaveNoPartialState` | Hashfehler und Manipulation nach Vorschau erzeugen keinen Teilimport; danach erfolgreicher Import, erneute Case-ID abgewiesen, gleicher Stand nach Reopen. |
| `testWorkflowAndValidationAreIndependentOfSyntheticPartyIdentity` | Identischer eingegebener Sachverhalt mit anderen synthetischen Akteur-/Partei-IDs und Namen durchläuft dieselben Meilensteine und Validierungen. |

Nach documented, verified, readyForEvaluation, jedem Evidenzschritt, Bewertungsentwurf/-freigabe, Skriptentwurf/-freigabe und Wiederöffnung wird der frisch geladene DomainContext validiert. Fehler stoppen den Pfad. Die erlaubte Warnung über eine Veröffentlichung 2025 für ein Ereignis 2021 bei Stichtag 2022 wird ausdrücklich geprüft. Der Roundtrip vergleicht das vollständige portable Archiv aller 24 Graphkollektionen einschließlich IDs, ursprünglichen Zeiten, Revisionen, Snapshots, Methodik, Satzreviews und AuditEntries; keine Count-/Text-Ersatzvergleiche. CaseReviewState muss in beiden Stores upToDate bleiben; im Negativpfad bleibt reviewRequired nach Wiederöffnung bestehen.

## Technische Freigabecheckliste

Nach dem erfolgreichen neuen CI-Lauf anhand obiger Tests abhaken:

- [ ] Frischer Store ohne Seed-Daten, Prüfername und erster Case funktionieren.
- [ ] Ein Fall lässt sich vollständig ohne KI bearbeiten.
- [ ] Quellenfassungen und genaue Fundstellen sind separat menschlich prüfbar.
- [ ] Kriterien sind versioniert, neu angebunden und vor Bewertung bestätigt.
- [ ] Handlungen und Evidenz werden explizit geprüft.
- [ ] Kriterienbewertungen und Gesamtbewertung sind menschlich freigegeben.
- [ ] Jeder Skriptsatz ist geprüft; jeder fact besitzt eine geprüfte Snapshot-Fundstelle.
- [ ] Export und frischer Import erhalten den vollständigen fachlichen Stand.
- [ ] Echte lokale Store-Wiederöffnung nach Freigaben und Import funktioniert.
- [ ] ReviewRequired erhält historische Freigaben und sperrt finale Ausgabe.
- [ ] Unzureichende Evidenz kann verantwortbar notVerifiable bleiben.
- [ ] OpenAI- und Exportfehler verlieren keine Daten; manueller Pfad bleibt möglich.
- [ ] Manipulation/Kollision erzeugt keinen Teilimport.
- [ ] Parteiidentität verändert weder Voraussetzungen noch Workflow.
- [ ] Alle 463 Tests erfolgreich; nativer arm64-Build erfolgreich.
- [ ] Separat: reale Fallabnahme durch menschlichen Tester protokolliert.

## Kleine UX-Korrekturen und verbleibende Grenzen

Der Prüfername ist im ersten Fallformular direkt erreichbar. Die bestehenden kontrollierten Workspace-Meldungen erscheinen jetzt auch in den offenen Fall-/Kriterium-/Quellendialogen. Der manuelle Skripteditor verwendet bei Ladefehlern ebenfalls WorkspaceErrorMessage statt roher Fehlerinterpolation. Keine neue Domain- oder Persistence-Regel, kein neues Schema. Überblick, Reviewstatus, Bewertungsreife und vorhandene Abschnittsüberschriften reichen zunächst als Orientierung; keine zweite Fortschritts-State-Machine.

Automatisierte Tests bedienen AppModel/Store, keine nativen Panels oder SwiftUI-Klicks. Bedienbarkeit und journalistische Belegtragfähigkeit benötigen die manuelle Checkliste. Ein neuer CI-Nachweis ist noch offen. Reale OpenAI-Modellverfügbarkeit, Qualität und Kosten werden hier nicht live geprüft. Der erste Bewertungsworkflow hat noch keinen UI-Ersatzreview; relevante Änderungen sperren deshalb finale Ausgabe, bis ein späterer expliziter Ersatzworkflow existiert. Dies ist sichtbar zu dokumentieren, kein Anlass für automatische Neubewertung. Portables Paket v1 transportiert keine lokalen Anhänge und ist kein Backup beliebiger Drafts. Vor Import in die Produktiv-App wird ein wirklich frischer Store separat vorbereitet; es gibt keinen Store-Wechsel-Dialog.

Bewusst Post-MVP: Video, TTS, automatische Untertitel, Visualgenerierung, automatische Recherche, Teamfunktionen, Cloud, öffentliche Distribution, Backend-Broker für OpenAI, App Store und Notarisierung. Keine neue AI-Funktion, kein Web Search, keine Agents oder automatische Veröffentlichung in Phase 4.4.
