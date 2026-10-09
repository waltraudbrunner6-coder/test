# Phase 5.3 – lokale Recherche-Review Queue

Extern bestätigte Basis: Commit 93d68ad7e4ff1d0ac2128188b77e3629160e0abb, Actions Run 37919529359, Apple Swift 6.1.2, 616/616 Tests und nativer macOS-arm64-Build erfolgreich. Die Änderungen dieser Phase benötigen einen neuen CI-Nachweis.

**AI recherchiert. Mensch prüft die vorgeschlagenen Quellen und Schlussfolgerungen. Die App übernimmt geprüfte Inhalte ohne erneute manuelle Dateneingabe.**

## Verantwortlichkeiten

ResearchReviewPlan ist eine pure, nicht persistierte Projektion aus DomainContext + unverändertem DeepResearchRecordV1. Sie enthält Originalquelle, Kriterien, Fundstellen, Entwicklungen, Evidenz, Bewertung, Blocker, Warnungen und Fortschritt. Itemzustände offen/bereit/geprüft/nicht verwendet/abgelehnt/blockiert sind abgeleitet. Kein zweiter fachlicher Workflow und keine neue SwiftData-Entity. CaseWorkflowState, ReviewRequired und sämtliche Core-Validatoren bleiben unverändert.

Der AppModel-Aufruf verlangt bei jedem aktiven Prüfklick einen nicht leeren Reviewer-Namen. Öffnen, Projektion und Navigation erzeugen keine ReviewerIdentity. HumanReview entsteht ausschließlich durch die bestehenden Core-Operationen nach expliziten menschlichen Aktionen. Der lokale Store nimmt eine explizit übergebene ReviewerIdentity entgegen, keine AI-/System-Autorenschaft.

## Workflow und Identitäten

1. **Original:** Wortlaut, URL, Locator, KI-Kontext, Datum und Unsicherheiten anzeigen. „Originalfundstelle geprüft“ erstellt eine neue verified SourceVersion und über die normale Excerpt-Transition eine neue verified Fundstelle. AI-Provenance bleibt erhalten. Ein separater Klick bestätigt das wortgleiche Originalzitat in einer neuen PromiseRevision und führt candidate → documented aus. Kein positives Review ohne wortgleichen geprüften Excerpt. Ablehnen nutzt unverified → rejected plus menschlichen Audit.
2. **Kriterien:** Pro Karte ausdrücklich „Übernehmen“ oder „Nicht verwenden“. Nicht verwenden entfernt ausschließlich aktive Referenzen eines AI-Drafts vor Snapshot/Evaluation; historischer Draft und Dossier bleiben erhalten. Der korrigierbare Kontext wird vorbefüllt. „Prüfrahmen und gewählte Kriterien bestätigen“ bestätigt Kontext und Sprecher anhand der geprüften Originalfundstelle, rebindet gewählte Kriterien über verifyPromiseForEvaluationReadiness, bestätigt ihre neuen Revisionen und durchläuft documented → verified → readyForEvaluation. Ohne ausdrückliche Kriterienauswahl wird blockiert. Die Sammelaktion benennt diese Bestätigungen im UI; manuelle Einzelprüfung bleibt verfügbar.
3. **Fundstellen:** Nur tatsächlich verwendete Fundstellen müssen geprüft sein. Unbenutzte Quellen bleiben ungeprüfte Recherche. Fachliches Ablehnen ist davon getrennt und ausdrücklich. Zu jedem Excerpt sind Quelle/URL, Locator, Kontext, Ereignisdatum, Unsicherheiten und Verwendung sichtbar.
4. **Entwicklungen:** verifyAction erstellt eine neue immutable ActionRevision anhand der neu geprüften Excerpts. Unbekannter Umfang/Ereigniszeit blockiert die Verifikation. Die Karte bietet vorbefüllte korrigierbare Felder; ausdrückliche menschliche Ergänzungen erzeugen vor verifyAction eine neue Human-Draftrevision mit Audit-Lineage. Der ursprüngliche KI-Draft bleibt unbekannt und unverändert. Nicht verwenden entfernt die aktuelle Arbeitsreferenz, bewahrt Action/Draft und schreibt einen menschlichen Audit. Keine ActionParticipation und keine kausale Zurechnung.
5. **Evidenz:** Neue menschlich übernommene EvidenceLinks statt Promotion alter AI-Links. Current confirmed CriterionRevision + verified Excerpts + current checked ActionRevision werden explizit aufgelöst. Add draft → needsReview → verified laufen über bestehende Operationen; Übernahme-Audit enthält alte AI-ID und neue Human-ID. Nicht verwenden bewahrt den AI-Link ohne Verifikation.
6. **Bewertung:** Kategorien, Begründungen, Pro/Contra-IDs, Confidence, Unsicherheiten und Gründe werden aus den DTOs vorbefüllt. Stichtag ist der angezeigte researchCutoff, kein neues Date(). ResearchAssessmentMapping mappt alle sechs Kategorien und sieben notVerifiable-Gründe explizit. nil ergibt keine Kategorie und keinen Snapshot; manueller Fallback bleibt. EvidenceLinkIDs enthalten Pro und Contra, counterEvidenceLinkIDs sind die Contra-Teilmenge, wie vom Core verlangt. Nur menschlich geprüfte Links werden verwendet.

Die bestehende startEvaluationSnapshot-Operation wird vor createEvaluationDraft aufgerufen. Der Draft hat keine Approval und ungeprüfte CriterionEvaluations. Pro Kriterium muss eine UI-Checkbox ausdrücklich gesetzt werden. Die finale Checkbox bestätigt Original, Quellen, Gegenbelege, Unsicherheiten und alle Kriteriumsbewertungen. Danach werden reviewCriterionEvaluation(each), submitEvaluationForReview und approveEvaluation ausgeführt. Keine Checkbox wird als Wahrheitszustand persistiert. Tatsächliche HumanReviews/Audits sind der dauerhafte Nachweis.

## Rebase und Historie

Research excerptKey → unveränderliche Draft-ID → Audit `reviewResearchExcerpt.before/after` → geprüfte neue ID. Mehrdeutige/fehlende Zuordnung blockiert, Reihenfolge und ähnlicher Text sind kein Matching-Verfahren. Dedup-Aliase derselben Draft-ID teilen dieselbe geprüfte ID.

criterionKey → AI CriterionRevision → stabile EvaluationCriterion.id → currentRevision. Der erlaubte Rebind muss im Audit nachvollziehbar sein; Kriterieninhalte müssen unverändert sein. Eine spätere inhaltliche manuelle Änderung blockiert die Übernahme des alten KI-Vorschlags und verlangt manuellen Fallback bzw. späteres Re-Research.

developmentKey → AI ActionRevision → stabile ActionOrDevelopment.id → neue geprüfte Revision. Geprüfte Feldinhalte und Fundstellen müssen zum ursprünglichen Vorschlag bzw. zu einer ausdrücklich menschlich ergänzten Zwischenrevision passen. evidenceKey → AI-Draft-ID → menschlicher Adoption-Audit → neuer geprüfter Link. Bei veralteten Kriterien, Quellen, Handlungen oder Bindings wird nicht geraten.

Discovery-/DeepResearchRecord, AI-Kriterienrevisionen, AI-Quellenfassungen, AI-ActionRevisionen, AI-EvidenceLinks und AI-Audits bleiben erhalten. Ausdrückliche Excerpt-Ablehnung ist die erlaubte Statusänderung am ungeprüften Draft; das unveränderliche Dossier bleibt der ursprüngliche KI-Nachweis.

Nicht übernommene recherchierte Gegenbelege werden vor Materialisierung und finaler Freigabe explizit angezeigt und benötigen bewusste Bestätigung. Von einem übernommenen Assessment referenzierte Gegenbelege können nicht einfach verschwinden; fehlende verifizierte Zuordnung blockiert. Andere historische KI-Quellen blockieren nicht.

## Atomizität

Jede Reviewaktion hat eine äußere LocalCaseStore-Transaktion. Zusammengesetzte Aktionen verwenden vorhandene Store-Operationen in einem isolierten In-Memory-Staging-Store. Zustandscheckpoints werden ausschließlich in den noch ungespeicherten realen ModelContext übertragen, damit vorhandene adjacent-transition ReplacementChecks weiterhin gelten (documented → verified → ready; draft → needsReview → approved). Ein einzelner finaler save oder vollständiger rollback. Keine verschachtelten Saves im produktiven Container, keine halben Reviews bei einem späten Fehler. Ein lokaler Writer, keine Nebenläufigkeit während einer synchronen Reviewaktion.

Schema/Exportformat bleiben unverändert. Der bestehende Core-Snapshot speichert auch historische Recherche-Fundstellen mit ihren damals ungeprüften/rejected Zuständen. Diese Manifest-Einträge sind keine freigegebene Evidenz. Confirmed Kriterien und verified Bewertungslinks verweisen ausschließlich auf geprüfte Fundstellen/Quellen. Ungeprüfte Action-Arbeitsreferenzen werden vor dem Snapshot entfernt; historische Actionrevisionen bleiben im Aggregate. Die Historienmanifest-Semantik wird nicht durch eine zweite Snapshot-Konstruktion geändert.

## UI, Tests und Grenzen

Neue Hauptsektion „Recherche prüfen · KI-Review“ im Dossier-Fall. Alle manuellen Buttons/Editoren und das ursprüngliche KI-Dossier bleiben sichtbar. Nach Approved ist der bestehende Skriptbereich der nächste Schritt; kein Script-Autostart. UI-Auswahlbestätigungen werden beim Wechsel des Cases zurückgesetzt, nach Reopen aus tatsächlichen Domainreviews neu dargestellt.

26 neue Offline-Tests: 2 Research-Projektion, 18 Persistence/Mapping/E2E/Rebase/Rollback, 6 AppModel. Erwartet 642 insgesamt; alle bisherigen 616 Tests bytegleich. Synthetische Daten, keine Web-/OpenAI-Anfragen. Lokal enden swift test und xcodebuild mit Exit 127/command not found; kein erfolgreicher Lauf dieser Änderung behauptet. CI bleibt swift test, danach nativer macOS-arm64-Build.

Grenzen: zunächst Erstbewertung, wie im bisherigen manuellen Core. Kein automatischer Refresh oder Wiederbewertungsprozess nach ReviewRequired. Korrekturen, die die Aussage, Kriterien oder Beleginhalte ändern, nutzen den vorhandenen manuellen Pfad und benötigen eine neue fachliche Prüfung; alte KI-Schlussfolgerungen werden dabei nicht automatisch umgebogen. Keine neue Quellenrecherche oder KI-Wahrheitsentscheidung. Menschliche Zitattreue, Quellenunabhängigkeit, Materialität, Verantwortungszuordnung und Interpretation bleiben menschliche Aufgaben. Keine TTS-, Video-, Visual-, Untertitel-, Cloud- oder Publishing-Funktionen.
