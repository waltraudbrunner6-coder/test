# Skriptvertrag 1 – Phase 4.1

## Zweck und Grenze

Der anbieterneutrale Vertrag formuliert eine bereits menschlich freigegebene Bewertung als kurzen Skriptentwurf. Er trifft keine politische Bewertung. `PoliticalFactCheckScripting` hängt nur vom plattformneutralen Core ab; der Core kennt keinen Provider. Noch kein OpenAI-Prompt, Netzwerkadapter oder API-Schlüssel. Der echte Adapter folgt in Phase 4.2.

## Input

`ScriptInputBuilder.build` verlangt genau eine vorhandene `CaseEvaluation` mit operativem Status `approved`, validiert sie und ihre konkrete `CaseRevision` und löst ausschließlich deren IDs auf. `ScriptGenerationInput` ist ein unveränderlicher Transferwert, keine neue Entity, Evidenz oder Nebenpersistenz. Er enthält:

- die Evaluation einschließlich Kategorie, Begründung, Confidence, Facts, Interpretations, Unsicherheiten und Bewertungsstichtag;
- Snapshot-ID und konkrete MethodologyVersion;
- die Original-PromiseRevision und bestätigten Kriterienrevisionen;
- die zugehörigen CriterionEvaluations;
- im Snapshot geprüfte Quellenfassungen und Fundstellen;
- im Snapshot geprüfte EvidenceLinks, die in diesen CriterionEvaluations tatsächlich verwendet werden (Gegenbelege sind Teil dieser Auswahl);
- konkrete ActionRevisions aus dem Manifest, einschließlich ihrer bereits gespeicherten Herkunft/Verifikation;
- die Zielzeit (30–60 Sekunden, Vorgabe 45).

Ungeprüfte Handlungsfelder sind Kontext, keine neuen Tatsachen. Der Input verwendet keine aktuellen Working Heads, keine aktuelle Actor-/Parteibewertung und keine nachträglich hinzugefügten Quellen oder Links. Publikationsdatum nach Stichtag schließt einen dokumentierten früheren Ereignisbezug nicht automatisch aus. Vorhandene Unsicherheiten und Herkunft bleiben sichtbar.

Lesbare Schlüssel entstehen in der gespeicherten Manifestreihenfolge: `SRC-1…` referenziert eine konkrete SourceVersion (mit Source-ID); `EX-1…` einen konkreten SourceExcerpt und dessen Quellenkey; `EV-1…` einen verwendeten EvidenceLink samt erforderlichen Excerpt-Keys. Wiederholtes Bauen desselben Inputs liefert dieselben Keys. Keys gelten **nur innerhalb dieses Inputs**, nicht als globale Quellenidentität. Historische Verifikation wird nach eingefrorenem Snapshotstatus geprüft; ein später `superseded` markierter Datensatz wird dadurch nicht rückwirkend ungeprüft. Sein tatsächlicher operativer Zustand und ursprünglicher Review bleiben erhalten.

## Provider und Ausgabe

`ScriptGenerationProvider` bietet eine feste `identifier: NonEmptyText` zur Herkunftskennzeichnung sowie `generateScript(input:) async throws → ScriptGenerationOutput`. Der konkrete Adapter ist austauschbar. Die Ausgabe enthält ausschließlich eine nicht leere Liste `GeneratedScriptStatement` mit:

| Feld | Typ / Bedeutung |
| --- | --- |
| position | eindeutiger, nicht negativer Int; bestimmt Reihenfolge |
| text | nicht leerer String |
| kind | exakt vorhandenes ScriptStatementKind: fact, interpretation, question, qualification |
| referencedExcerptKeys | nur vorhandene EX-Keys, keine Duplikate |
| referencedEvidenceKeys | nur vorhandene EV-Keys, keine Duplikate |
| uncertainty | optionaler, bei Vorhandensein nicht leerer String |

Ein späterer externer Adapter muss freie Typstrings strikt auf diese vier Enums abbilden und unbekannte Typen ablehnen. Keine Fallback-Kategorie. Die jetzige Swift-Grenze erlaubt unbekannte Typen bereits konstruktiv nicht. Die Ausgabe kann keine IDs, Quellenobjekte, Handlungen, Bewertungen, Reviewer oder Prüfvermerke erzeugen.

`ScriptOutputValidator` lehnt den gesamten Batch bei unbekannten Keys, leeren Texten, doppelten Positionen oder inkonsistenten Verknüpfungen ab. Keine stille Filterung. Jeder fact braucht mindestens einen im Input geprüften EX-Key. Referenzierte Evidenz verlangt sämtliche eigenen Fundstellen am Satz. Interpretation, Frage und Einschränkung dürfen ohne Referenzen vorliegen; angegebene Referenzen müssen trotzdem gültig sein. Die verbindliche Domainprüfung kontrolliert nach Mapping nochmals Snapshotzugehörigkeit und Beziehungen.

## Redaktionelle Anweisungen für jeden späteren Provider

Nur bereitgestellte Fakten verwenden. Keine Quellen, Zitate, URLs, Abstimmungen, Handlungen oder Quellen-IDs erfinden. Tatsachen von Interpretation und Einschränkung unterscheiden. Unsicherheiten beibehalten und sichtbar formulieren. Kategorie, Confidence, Methodik und Bewertungsbegründung nicht verändern oder verschärfen. Kurze, sachliche Sprache für einen Planwert von 30–60 Sekunden verwenden; keine gemessene TTS-Dauer behaupten. Keine automatisch generierten Motivurteile: weder Lüge, Täuschungsabsicht, bewusste Irreführung, Unehrlichkeit noch Motivation behaupten oder implizieren. Parteiidentität ist kein Bewertungsparameter.

Diese sprachlichen Anforderungen sind nicht vollständig maschinell erzwingbar. Eine vorhandene Quellenreferenz beweist noch nicht, dass sie den neuen Satz tatsächlich trägt. Menschliche satzweise Prüfung von Wortlaut, Kontext, Interpretation, Unsicherheit und Belegbeziehung bleibt zwingend. Provider-Text ist niemals Evidenz.

## Speicherung, Review und Historie

Der Store baut den Input nach Rückkehr des Providers aus einem frischen Context erneut auf. Statuswechsel während der asynchronen Generation blockieren die Speicherung. Nach vollständiger Validierung entstehen neue Script-/Statement-IDs, Status draft, keine HumanReviews und höchste bestehende Version derselben Evaluation plus eins. Ein einzelner Save enthält Skript, alle Sätze und Audits; jeder Fehler rollt alles zurück. Manuelle Entwürfe verwenden dieselbe Grenze und Domain.

Provider-Autorenschaft (`Authorship.ai`, beim Fake eindeutig `local-test-provider-no-ai`) ist vom menschlichen Requester getrennt. Sie bezeichnet beim Fake nur den Provider-Pfad, keine tatsächlich verwendete KI. Jeder Satz wird separat durch `HumanReview` geprüft. Danach eigene Schritte draft → needsReview → approved; der letzte verlangt sämtliche Satzprüfungen und weiterhin approved Evaluation. Inhalte bleiben unveränderlich. Bearbeiten, Hinzufügen, Entfernen, Neuzuordnen und Umsortieren erstellt eine neue Version und setzt sämtliche Reviews zurück. Neue Entwürfe lösen alte Freigaben nicht automatisch ab.

Wird die Evaluation reviewRequired, bleibt der historische Inhalt erhalten; vorhandene approved Skripte werden durch die bestehende atomare Evidenz-/Kriterienoperation operativ superseded. Keine neue Generation oder Freigabe aus reviewRequired. Keine automatische Neubewertung.

## Fake und Prüfstand

`FakeScriptGenerationProvider` ist ausschließlich ein deterministisches Entwicklungswerkzeug ohne Netzwerk. Er kopiert den ersten geprüften Auszug als fact, die Bewertungsbegründung als interpretation und die vorhandenen Unsicherheiten als qualifications. Er simuliert keine journalistische Intelligenz und optimiert keine Sprechdauer. Die Oberfläche kennzeichnet ausdrücklich „Lokaler Test-Provider – keine echte KI“.

Die extern bestätigte Basis umfasst 244 erfolgreiche Tests und den nativen arm64-Build mit Apple Swift 6.1.2. Neue Tests und App-Build müssen gesondert durch den bestehenden macOS-15-Workflow bestätigt werden. Lokal sind Swift/Xcode nicht vorhanden; ein statischer Check ersetzt keinen CI-Nachweis.

Prüfstand Phase 4.1: 59 neue Tests (6 Core, 24 Scripting, 21 Persistence, 8 AppModel), erwartet **303 insgesamt**. Alle 244 bisherigen Tests bleiben unverändert. Lokale Aufrufe von swift --version, swift test und xcodebuild enden mit Exit 127 (command not found); GitHub-Actions-Abruf liefert Forbidden. git diff --check ist erfolgreich, aber kein Compiler-/Testnachweis. Der unveränderte Workflow führt nach Push auf main zuerst swift test und anschließend den nativen arm64-App-Build aus; Ergebnis extern zu prüfen.
