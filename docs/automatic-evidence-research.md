# Phase 5.2: automatische Evidenzrecherche und Bewertungsentwurf

Extern bestätigter Ausgangsstand: `58e0a0812f3b22278943fce3235caf7ce7e8247c`, GitHub Actions Run 37902591356, Apple Swift 6.1.2, 558/558 Tests, nativer macOS-arm64-Build BUILD SUCCEEDED. Die neue Änderung braucht einen eigenen CI-Nachweis.

**AI Research Draft ≠ verified evidence ≠ approved evaluation.** Die KI recherchiert und bereitet die Arbeit vor. Die bestehende Vertrauens-/Freigabeschicht entscheidet, was veröffentlicht werden darf.

## Architektur und Ablauf

Im bestehenden Research-Target: `CaseResearchProvider`, typisierter `CaseResearchRequest` aus candidate-Case/DiscoveryCandidateRecord, EvidenceSourcePolicy, Strict-DTOs, OpenAICaseResearchProvider, pure CaseResearchValidation und Draft-Mapper. Core, Domain-Validatoren, menschliche Reviewregeln, Discovery-Provider und Scripting/Export bleiben unverändert. Keine neuen Server, Persistenzentities, Dependencies, Accounts oder Secretspeicher.

1. ORIGINAL sucht die Kandidatenquelle erneut und liefert Kontext, Unsicherheiten und normalerweise 1–3 notwendige Kriterien. Die Kriterien werden vor den Outcome-Suchen festgehalten. Ein als Commitment dargestelltes Original benötigt eine tatsächliche Original-URL mit Fundstelle. Unklarer/non-Commitment-Kandidat kann ohne abschließende Empfehlung zurückkommen.
2. Je Kriterium sequenziell SUPPORT, CONTRADICTION, CONTEXT mit identischem Prompt, Domainfilter, Ergebnislimit, Tool-/Tokenbudget und Timeout. Nur Intent und das konkrete Kriterium variieren. Kriterien dürfen in diesen Lanes nicht verändert werden.
3. ASSESSMENT verwendet das eingefrorene Research-Material und Methodik 1.0 für getrennte Kriterien-/Gesamtvorschläge; kein mathematisches Aggregieren. Nur bei vollständig ausgeführten drei Richtungen ohne technische Fehler wird diese Lane ausgeführt. Maximal 11 Lanes bei drei Kriterien. Keine Neubelege aus der Assessment-Lane.
4. Der vollständige geprüfte Transportentwurf wird pro Case atomar als ungeprüfte Domain-Drafts, Dossier-Task und AI-Audits gespeichert. Candidate bleibt candidate. Andere Kandidaten dürfen unabhängig erfolgreich sein.

OpenAI: POST `/v1/responses`, `gpt-6.1-sol`, reasoning medium, store false, ausschließlich `web_search`, external_web_access true, tool_choice required, Search-Sources-Include. Default 3 Tool-Aufrufe, 4 Ergebnisse je Lane, 8192 Output-Tokens, 120 Sekunden. Kein Conversation-/Response-History-State. Jede Lane einschließlich ASSESSMENT benötigt tatsächliche Web Search. Prompt und gebündelte Ressource sind bytegleich; die eingefrorene Methodik wird ebenfalls bytegleich gebündelt, ohne neue MethodologyVersion im Store. Modell-/Accountzugriff bleibt bis zur Live-Nutzung unbewiesen. API-Key ausschließlich Prozessvariable OPENAI_API_KEY und Authorization-Header.

## Provenienz und Transportvalidierung

Actual Search-Sources und URL-Citations werden separat aus der API-Hülle gelesen. Nur tatsächlich gesuchte erlaubte URLs werden gespeichert; Citation allein ist keine Quelle. Bestehender ResearchWebSource wird in ProposedResearchSource um Kategorie und eng typisierte extrahierte Metadaten ergänzt. Der Original-Quelltyp wird nicht dupliziert. Lane-Namespace schützt Keys vor Kollisionen, ohne Texte oder politische Kategorien zu verändern. Claim-Titel/Autor/Publisher/Datumswerte sind unreviewed, Actual Search-Metadaten bleiben davon unterscheidbar.

Strict JSON-Schema: additionalProperties=false, alle Felder einschließlich nullable Felder required. Der Client prüft die tatsächliche Schlüsselstruktur sowie Codable-Typen/Enums, Limits, eindeutige Keys und Referenzen. Jedes EvidenceProposal braucht konkrete Excerpts, ein eingefrorenes Kriterium, rationale, direct/indirect und event/validity-Zeitrolle. Unbekannte Zeit braucht eine Unsicherheit. Antrag, Beschluss, Umsetzung und Wirkung bleiben verschiedene Action-Typen/Verfahrensstände; keine Actor-/Parteiverantwortung wird automatisch zugeordnet.

Search Coverage je Kriterium enthält performed-Flags, tatsächliche Search-Source-Anzahlen, blocked/failed-Lanes und unresolvedQuestions. Trefferzahl zählt Suchquellen, nicht geprüfte Belege. Null Treffer ist eine erfolgreiche Suche ohne Befund. Netzwerk-/Zugriffsfehler hinterlassen explizite Coverage-Lücken und nil/noRecommendation. Ein gültiges partielles Recherche-Dossier kann bei solchen technischen Lane-Fehlern gespeichert werden. Struktur-, Policy-, Referenz- und Assessment-Validierungsfehler verwerfen dagegen den gesamten Kandidatenentwurf. Original-Lane-Providerfehler erzeugen keine neuen Domainobjekte. Fehlermeldungen sind kontrolliert, keine rohen Serverantworten.

## Bewertungsentwürfe und Gates

ProposedCriterionAssessment / ProposedCaseAssessment sind reine Research-DTOs, keine CriterionEvaluation/CaseEvaluation und keine vorgetäuschten Domain-IDs. Kategorien entsprechen exakt Methodology 1.0; null/noRecommendation ist keine siebte politische Kategorie. Fakten sind als KI-behauptete Fakten von Interpretation und Unsicherheit getrennt. Confidence ist ungeprüfte qualitative Einschätzung.

- Keine Support-Treffer → niemals allein notFulfilled. Keine Contradiction-Treffer → niemals allein fulfilled.
- Fehlgeschlagene/blockierte Suchrichtung → kein abschließender Kategorie-Suggest. nil/noRecommendation mit Grund bleibt möglich.
- notVerifiable braucht strukturierten vorhandenen Grund und rationale; unclearPromise, openDeadline, conditionNotMet, missingEvidence, unclearAttribution, conflictingSources, researchBlocked sind möglich.
- Jede abschließende positive/negative Empfehlung benötigt konkrete passend zugeordnete EvidenceKeys und bekannte Ereignis-/Gültigkeitszeit bis zum Stichtag. Publikationsdatum wird dafür nicht verwendet.
- notFulfilled/contraryAction brauchen konkrete Contra-Evidenz und dürfen nicht low-confidence sein. notFulfilled zusätzlich abgelaufene Frist und ausdrücklich als anwendbar vorgeschlagene Bedingungen. contraryAction zusätzlich direkte Contra mit konkreter Development-Referenz. Institutionelle Quelle im relevanten Belegsatz ist Pflicht.
- Entscheidende Unsicherheit blockiert abschließende positive/negative Vorschläge. Gesamt-negativ verlangt einen entsprechend vorgeschlagenen Kernkriterienbefund; erfüllt verlangt alle Kriterien erfüllt, überwiegend erfüllt verlangt erfüllte Kernkriterien. Das sind konservative Konsistenz-Gates, keine automatische Gesamtberechnung. Menschliche Materialität, Zurechnung und inhaltliche Belegkraft werden dadurch nicht entschieden.

Research cutoff und tatsächlicher Start/Abrufzeitpunkt sind getrennte Werte. Eine 2025 publizierte Quelle kann für einen 2022er Stichtag ein 2021er Ereignis dokumentieren. Unbekannte/future Zeit verhindert abschließende Vorschläge, aber nicht ungeprüfte Quellen-/Evidence-Drafts.

## Domain-Mapping und Persistenz

CaseResearchDraftMapper ergänzt vorhandenen DomainContext, ohne alte Inhalte zu ersetzen. Neue CriterionRevisions draft, confirmation nil, metadata.ai. SourceVersions unreviewed/nil-review, SourceExcerpts unverified/aiExtracted/nil-review. Action-AssertedValues aiExtracted/unreviewed/nil-review. EvidenceLinks draft/nil-review/metadata.ai, an vorhandenen ungeprüften Excerpts zulässig; der manuelle AddEvidence-Pfad wird nicht benutzt. Keine ActionParticipation, HumanReview, Workflow-Hochstufung, CaseRevision, Evaluation oder Skript entsteht.

Unknowns bleiben null/FieldValue. Die bestehende Domain-Criterion-Zielgruppe ist Pflichttext; bei null wird ausdrücklich „Unbekannt: …“ gespeichert, während der Dossierwert null bleibt. ContentType/Language-Pflichttexte verwenden unknown, nicht erfundene Werte. Kontext-/Datums-Ergänzungen der Originalquelle bleiben im Dossier und ändern die ursprüngliche PromiseRevision nicht.

Canonical URL identifiziert eine Source innerhalb des Cases. Ein bereits ungeprüfter, nicht dateibasierter unknown SourceVersion-Anker kann wiederverwendet werden; neue KI-Metadaten ersetzen seine alten Inhalte nicht, sondern bleiben im Dossier. Innerhalb des Runs wird dieselbe URL nur einmal beobachtet. Bei einer bisher verifizierten/dateibasierten Quelle wird eine getrennte unreviewed Beobachtungsfassung angelegt, um aktuelle ungeprüfte Extracts nicht an die historische geprüfte Datei zu hängen. Das behauptet keinen nachgewiesenen Bytewechsel. Ohne eigenen Download/Hash kann die KI weder gleiche noch geänderte Dokumentfassung beweisen; diese Grenze bleibt explizit. Excerpt-Dedup: SourceVersion-ID + Locator + whitespace-normalisierter Text, keine semantische Fusion. Wiederverwendete vorhandene Objekte behalten ihre Statuswerte; neue Objekte werden nie verified.

DeepResearchRecordV1 in genau einem neuen bestehenden ResearchTask.result enthält Case/PromiseRevision, originale Discovery-Provenienz, Provider/Modell/Prompt, Evidence-Policy-Snapshot, Cutoff/Start/Ende/Budgets, alle Proposal- und Quellenwerte, Coverage, Assessments, Unsicherheiten und kontrollierte Issues. Bindings halten konkrete gespeicherte Revision-/Source-/Excerpt-/Link-IDs je Transportkey für Phase 5.3. Beim Laden werden diese gegen den Graph geprüft. Keine rohe Response, API-Schlüssel, Authorization, Reasoning, Conversation-/Response-ID. Task completed heißt Lauf abgeschlossen, nicht Fall verifiziert. AI-Audits tragen keinen HumanRequester/Reviewer.

LocalCaseStore.saveCaseResearch lädt frisch, prüft weiterhin candidate, unveränderten Promise-Head/Originalquote/DiscoveryRecord und Abwesenheit eines bestehenden gültigen Dossiers. Alle Ergänzungen/Bindings/Task/Audits werden in einem Save gespeichert oder zurückgerollt. Bestehende manuelle Daten werden vollständig erhalten. Normaler erneuter Lauf meldet „Bereits vertieft recherchiert“. Refresh, Redraft und Migration folgen später. Schema 1.0.0, Payload 1 und Lösch-/Historienregeln unverändert. Ein lokaler Writer, keine parallelen Stores.

## UI und Batch

„Alle Kandidaten automatisch vertiefen“ recherchiert seriell mit Concurrency 1, ohne Nutzerquery. Vor Start: Anzahl offener Kandidaten und bis zu 11 Lanes pro Kandidat; keine erfundene Euro-Schätzung. Fortschritt zeigt Kandidat N von M und aktuelle Lane. Abbruch verwirft den noch nicht gespeicherten Kandidaten; früher atomar gespeicherte Dossiers bleiben erhalten. Fehlgeschlagene Kandidaten blockieren andere nicht. Doppelte Starts sowie parallele Discovery/Deep-Research-Aktionen werden verhindert. Manuelle Navigation/Bearbeitung bleibt möglich.

Candidate-Detail: „Automatische Recherche“, Originalkontext, Kriterien, Coverage, Entwicklungen, Support/Contra/Context-Evidence-Karten mit anklickbaren Quellen und Fundstellen, getrennte KI-Fakten/Interpretationen/Unsicherheiten und Kriterien-/Gesamtvorschlag. Klare Labels „KI-Recherche – ungeprüft“ und „KI-Bewertungsvorschlag – noch keine freigegebene Bewertung“. Einzelfallvertiefung zusätzlich möglich. Die optionale kombinierte Discovery-und-Vertiefung-Aktion wird nicht hinzugefügt; Bulk ist der gemeinsame minimale Automationspfad.

## Tests, Grenzen und nächster Schritt

Tests vollständig offline mit URLProtocol und synthetischen Parteien/Quellen, keine realen politischen Aussagen. Bestehende 558 Tests bleiben unverändert. Neue Tests betreffen Requests/Schema/Prompt/Policy/Symmetrie, echte Source-Provenienz, technische Coverage-Ausfälle, Assessment-Gates, Draft-Status/Referenzen/Provenienz, Task/Bindings, Dedup/Rollback/Reopen, Bulk/Skip/Abbruch/Navigation. CI bleibt swift test → nativer macOS-arm64-Build, ohne Live-API.

Die Gates prüfen Struktur und methodische Mindestbedingungen, nicht politische Wahrheit, Zitattreue, Quellenunabhängigkeit, Materialität oder Verantwortung. Selbst „high“ im Dossier ist keine verified evidence. Kein Human-Approval-Automatismus, Review-Queue oder Überführung in echte Evaluation in Phase 5.2. Phase 5.3 kann über erhaltene Bindings die vorhandenen Drafts prüfen statt neu eingeben. Scriptpipeline, Export und Publication Gate bleiben auf echten approved Evaluationen. Kein Video, TTS, FFmpeg, AVFoundation, Medienasset oder Veröffentlichung.

Prüfstand dieses Schritts: **57 neue Tests**, erwartet **615 insgesamt** (558 bestehende unverändert). Neu: 40 Research, 8 Persistence, 9 AppModel. `swift --version`, `swift test` und der native arm64-`xcodebuild` enden lokal jeweils mit Exit 127 / command not found. Statische Ressourcen-/Unverändertheitsprüfungen sind erfolgreich; kein erfolgreicher Compiler-/Test-/App-Build dieser Änderung wird behauptet. Der unveränderte macOS-Workflow muss nach Push extern verifiziert werden.

## Phase 5.3: lokaler menschlicher Reviewpfad

Die [Recherche-Review Queue](research-review-queue.md) ergänzt einen lokalen Pfad vom vorhandenen Dossier zur echten menschlich freigegebenen Bewertung. ResearchReviewPlan ist abgeleitet; geprüfte neue IDs werden über Audit-Historie und stabile Criterion-/Action-Identitäten aufgelöst. KI-Drafts und Dossiers werden nicht umgeschrieben. Keine neue Web-/OpenAI-Anfrage; manuelle Workflows bleiben verfügbar.
