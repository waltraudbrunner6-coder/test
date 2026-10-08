# OpenAI-Skriptadapter – Phase 4.2

## Laufzeit und Grenzen

`OpenAIScriptGenerationProvider` implementiert den vorhandenen `ScriptGenerationProvider` im Scripting-Target. Foundation/URLSession genügen; keine SDK-Abhängigkeit, keine OpenAI-Typen im Core. Eine injizierbare URLSession und eine injizierbare Environment-Abfrage ermöglichen vollständig offline ausgeführte HTTP-Tests.

Diese direkte Client-API-Anbindung ist ausschließlich für lokale Entwicklung. Eine verteilte Produktionsversion benötigt später einen sicheren Backend-/Token-Broker. Der Adapter liest zur Laufzeit ausschließlich `OPENAI_API_KEY` aus `ProcessInfo.processInfo.environment`. Keine Speicherung in App, UserDefaults, SwiftData, Keychain, plist oder Repository; kein Eingabefeld. Für Entwicklung die Variable im startenden Terminalprozess konfigurieren und die App als dessen Kindprozess starten, etwa `/path/to/PoliticalFactCheckApp.app/Contents/MacOS/PoliticalFactCheckApp`. Eine bereits aus Finder gestartete App erbt diese Terminalumgebung nicht. Fehlt der Schlüssel, erscheint kontrolliert „OpenAI API key is not configured“; manuelle Skripte funktionieren weiter.

Der Schlüssel wird ausschließlich zum temporären Authorization-Header hinzugefügt. Keine Request-Dumps, Header-/Payload-Logs oder rohen Response-Bodies in Fehlern/Audits. Alle Testschlüssel sind `test-key-not-real`; CI benötigt keine Secrets und sendet keine echten API-Anfragen.

## Request und Konfiguration

Ein einzelner `POST https://api.openai.com/v1/responses`, Content-Type application/json. Default ausschließlich in `OpenAIScriptProviderConfiguration`: `gpt-6.1-sol`, `reasoning.effort = medium`. Der vom Auftrag gewählte Default soll sprachlich und fachlich genaue kurze journalistische Texte unterstützen; tatsächliche Qualität und Modellverfügbarkeit für das verwendete Konto sind hier nicht live nachgewiesen. `gpt-6-luna` kann über Entwicklungskonfiguration später als günstigere Alternative evaluiert werden. Keine automatische Modellwahl, kein UI-Modellpicker, keine politische Regel abhängig vom Modell.

`store: false`, `stream: false`, keine Tools, kein previous_response_id, keine Conversation-History. `store: false` ist keine Zusicherung vollständiger Null-Aufbewahrung durch den Anbieter. Stabiler safety_identifier: unabhängig vom Reviewer erzeugte zufällige lokale UUID in UserDefaults, ohne Namen/E-Mail. Er ist kein Geheimnis und keine fachliche Identität.

Default: 4096 max_output_tokens, 60 Sekunden Timeout, maximal zwölf Sätze. Das Limit deckt strukturierte Ausgabe und gegebenenfalls Reasoning-Tokens ab; es garantiert keine Sprechdauer oder erfolgreiche Fertigstellung. Keine automatischen Retries; erneutes Senden ist eine bewusste Benutzeraktion. Keine Usage-, Request-ID- oder Response-ID-Persistenz.

## Übertragungsgrenze und Vorschau

Der bestehende `ScriptGenerationInput` bleibt einzige fachliche Inputstruktur. `OpenAITransmissionPreview` enthält diesen Input und eine JSON-Darstellung für Anzeige/Übertragung, kein zweites Domainmodell. Der exakt angezeigte JSON-Text wird als user/input_text gesendet. Technische Instructions, Schema, Modellkonfiguration und safety_identifier stehen separat.

Übertragen werden ausschließlich freigegebene Snapshotinhalte: Originalzitat/Kontext/Prüfthese/Datum, Bewertung und getrennte Fakten/Interpretationen/Unsicherheiten, Kriterien und ihre Bewertungen, verifizierte Evidenz und Fundstellen mit Locator/Text, Quellenfassungstitel/Herausgeber/Publikationsdatum sowie verknüpfte Handlungsrevisionen. Unbekannt/nicht anwendbar bleibt mit Grund kenntlich. EX-/EV-/SRC-Keys stammen aus dem bestehenden Builder; CR-/ACT-Keys sind lokale Übertragungsschlüssel. Interne UUIDs, Reviewer, Audits, lokale Dateien, andere Cases und Arbeitsköpfe außerhalb des Snapshots werden nicht zusätzlich angefügt. Politische Texte können selbst Namen enthalten; die Reduktion ist keine Textanonymisierung.

„KI-Skriptentwurf erzeugen“ öffnet nur die lokale Vorschau. Erst „An OpenAI senden“ ruft den Provider auf. Abbrechen sendet nichts. Vor dem Senden wird der Fall frisch geladen; Status und Input werden erneut geprüft. Ein ausschließlich lokaler SHA-256-Änderungstoken des vollständigen CaseGraphDTO erfasst auch Änderungen außerhalb des Snapshots und wird niemals übertragen. Das lokale Ein-Writer-Modell bleibt Voraussetzung; keine Mehrprozess-Synchronisierung.

Während der Anfrage verhindern Busy-Status und deaktivierte Buttons Doppelsendungen; ProgressView zeigt den laufenden Vorgang. Wiederholbare Providerfehler behalten die Vorschau, relevante Falländerungen verlangen eine neue Vorschau. Die Store-Operation prüft nach der asynchronen Antwort nochmals den aktuellen Bewertungsstatus, bevor sie atomar speichert.

## Prompt, Schema und Validierung

Promptversion `openai-script-prompt-v1`: Dokument `docs/openai-script-prompt-v1.md`, bytegleiche gebündelte Ressource `Sources/PoliticalFactCheckScripting/Resources/openai-script-prompt-v1.txt`. Ein Test erzwingt Gleichheit. Instructions behandeln Auszüge ausdrücklich als nicht vertrauenswürdige Daten; keine darin enthaltenen Anweisungen befolgen. Keine erfundenen Tatsachen/Quellen/Keys, neue Kategorie/Confidence oder Motivunterstellungen. Prompt-Instructions sind keine beweisbare Garantie gegen semantische Fehler oder Prompt Injection.

Responses `text.format`: json_schema, strict true, additionalProperties false auf allen Objekt-Ebenen. Statements besitzen Integerposition, Text, genau die vier bisherigen Satztypen, EX-/EV-Key-Arrays und erforderliches nullable uncertainty. Decode prüft Form und unbekannte Properties nochmals; anschließend läuft der unveränderte lokale ScriptOutputValidator. Ungültiger Batch wird vollständig verworfen, keine automatische Reparatur und kein Teildraft.

HTTP 401/403/408/429/5xx sowie Transport/Timeout, malformed/missing structured output, Refusal, incomplete und ungültige Referenzen werden auf strukturierte kontrollierte Fehler gemappt. Kein roher Body in der UI. Unvollständige oder verweigerte Antworten erzeugen keinen Draft.

Ein erfolgreicher Output nutzt ausschließlich die bestehende atomare Speicherung: neue ScriptDraft-/ScriptStatement-IDs, neue Version, Status draft, keine Satzreviews/Approval. Provider-/Modell-/Promptkennung bleibt als Herkunft; Human-Requester ist getrennt. Evaluation, CriterionEvaluations, CaseRevision, MethodologyVersion, PromiseRevision, EvidenceLinks und SourceExcerpts bleiben wertgleich. Menschliche Satzprüfung und Freigabe bleiben zwingend; Referenzvalidität beweist nicht politische Wahrheit oder Belegtragfähigkeit. Fake-Provider bleibt unverändert für Tests und einen ausdrücklich beschrifteten Debug-UI-Button.

## Tests und Prüfstand

Extern bestätigte Basis: b4b282621bc2075a5999d3f2c53342256ca75749, Run 37811572377 Attempt 3, Apple Swift 6.1.2, 303 erfolgreiche Tests und nativer arm64-Build. Alle bisherigen Testdateien bleiben unverändert. Phase 4.2 ergänzt 67 Tests: 47 Scripting, 17 AppModel, 3 Persistence; erwartet **370 insgesamt** (139 Core, 71 Scripting, 50 AppModel, 110 Persistence). HTTP ausschließlich URLProtocol-Stubs, synthetische Daten, keine echten Schlüssel.

Lokale Aufrufe von swift --version, swift test und xcodebuild enden jeweils mit Exit 127 (command not found); Tests und App-Build dieser Änderungen sind noch nicht erfolgreich ausgeführt. git diff --check ist erfolgreich. Der Actions-Abruf mittels gh run list scheitert mit Forbidden. Der unveränderte macOS-15-Workflow führt erst swift test, danach xcodebuild für macOS/arm64 aus. Neue CI-Ausführung ist separat zu bestätigen. Keine Live-API-/Qualitäts-/Kosten-/Account-Modellverfügbarkeitsprüfung und kein automatisierter macOS-UI-Interaktionstest; AppModel-Tests decken Vorschau, Sendegate, Busy-Zustand, Fehler und Persistenz ab.

## API-Referenzen

Request-/Schemaform anhand der offiziellen OpenAI-OpenAPI-Spezifikation geprüft: https://github.com/openai/openai-openapi/blob/master/openapi.yaml. Weitere Referenzen: https://platform.openai.com/docs/api-reference/responses/create und https://platform.openai.com/docs/guides/structured-outputs. Die Prüfung der API-Struktur ersetzt keinen Live-Kompatibilitätsnachweis für das konfigurierte Modell.
