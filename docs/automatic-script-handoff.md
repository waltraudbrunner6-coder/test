# Automatische Skriptvorbereitung und menschliche Satzprüfung – Phase 5.4

Approved Evaluation → AI Script Draft → Human Script Review → Approved Script → deterministic Video Handoff.

Nach erfolgreicher Research-Review-Freigabe erscheint unmittelbar die primäre Aktion „KI-Skript erzeugen“. Sie löst ausschließlich die bestehende lokale OpenAITransmissionPreview aus. Erst „An OpenAI senden“ startet den bestehenden Provider. Keine implizite Anfrage, keine neuen Quellen, keine Websuche. Modell, Prompt, Strict Structured Output und Fehlervertrag bleiben unverändert.

## Aktueller Stand statt ID-Auswahl

CurrentScriptContext verwendet CaseReviews und die bestehenden Snapshot-/Input-Validatoren. Der aktuelle Manifeststand muss Arbeitsrevisionen und relevante verifizierte Evidenz abdecken. Evaluationen werden über explizite replacesEvaluationID-Ketten aufgelöst, nicht anhand ihres Zeitstempels. Es darf genau ein verbleibender Bewertungsstand existieren, der approved ist. Mehrdeutigkeit, offene Ersatzbewertung und reviewRequired blockieren; eine historische Freigabe allein genügt nicht.

Für diese Evaluation zählt die höchste vorhandene Skriptversion; doppelte höchste Versionen blockieren. draft/needsReview führen zur fortgesetzten Satzprüfung, approved zur Videoübergabe. Eine neue KI-Fassung muss ausdrücklich angefordert werden; superseded wird niemals Videoeingabe. Historische Fassungen bleiben vollständig erhalten. Bestehende explizite Einzeloperationen und manuelle Fassungen bleiben verfügbar.

## Abgeleitete Prüfung

ScriptReviewPlan ist eine reine, nicht persistierte Projektion im Scripting-Target. Er enthält Evaluation-/Skript-ID, Version, Status, Satzitems, geprüfte/gesamte Anzahl, strukturierte Blocker und readyForApproval/readyForVideo. Ohne Skript zeigt generationAvailable den nächsten Schritt an. Die Projektion schreibt keine Reviews und erzeugt keine Inhalte.

Satzitems enthalten unveränderten Text, Position, Typ, EX-/EV-IDs, Unsicherheit, abgeleiteten HumanReviewState und geprüfte Quellenzusammenfassungen. Titel/Herausgeber bleiben bei fehlenden Daten nil; die UI benennt diese Lücken. URL wird aus finalURL, requestedURL, archiveURL oder bestehender canonicalURL aufgelöst. Locator und exakter Fundstellentext stehen direkt neben dem Satz, ebenso vorhandene Evidenzbeziehungen. Tatsachen, Interpretationen, Fragen und Einschränkungen bleiben sichtbar getrennt.

Die Queue-Auswahl ist ausschließlich lokaler SwiftUI-State. „Markierte Sätze als geprüft übernehmen“ ist ein ausdrücklicher menschlicher Akt; keine Vorauswahl, kein KI-Review und keine Blindfreigabe. Alle ausgewählten Sätze erhalten über DomainChanges.reviewScriptStatement denselben Reviewer/Zeitpunkt. Bereits geprüfte Sätze bleiben unverändert, ohne zusätzlichen Satzreview-Audit.

Wenn alle Sätze geprüft sind, verlangt „Skript freigeben“ zusätzlich die explizite Bestätigung der Fakten-, Quellen-, Interpretations- und Unsicherheitsprüfung. Der Store lädt den Graphen frisch und prüft den aktuell freigegebenen Bewertungsstand erneut. Übergänge bleiben draft → needsReview → approved. Keine Änderung von Texten, Quellendaten, Evaluation oder historischem Snapshot.

## Atomizität und stale input

reviewScriptStatements und approveReviewedScript führen jeweils eine einzige ModelContext-Transaktion mit einem abschließenden Save aus. Die finale Freigabe verwendet einen unsaved Checkpoint für den vorhandenen adjacent-transition-Replacement-Vertrag. Jeder Fehler rollt auch neue Reviewer, Reviews und Audits zurück. Eine interne, nicht öffentliche Fehlereinschleusung prüft den Rollback nach diesem Checkpoint.

Der ausschließlich lokale SHA-256-Änderungstoken wird vor und nach der asynchronen Providerantwort geprüft; der Input wird nach Rückkehr erneut validiert. Auch Änderungen außerhalb des Snapshots blockieren die Übernahme. Es gibt keinen await zwischen abschließender Prüfung und atomarer Speicherung im MainActor. Ein lokaler Writer bleibt Voraussetzung; keine Mehrprozess-Synchronisierung. Providerfehler schreiben weiterhin nichts. Neue Fassungen verwenden die vorhandene Speicherung mit max + 1, neuen IDs, draft und nil-Reviews.

## Übergabe und Grenzen

Die UI zeigt nach erfolgreicher Freigabe „Bereit für Video“, Szenenzahl, Planlänge und Anzahl der Faktenszenen mit Quellenhinweisen. Eine einklappbare Vorschau enthält nur Narration, Planzeiten und Quellen. Kein Render-Button. Vertrag: [video-script-handoff-v1.md](video-script-handoff-v1.md).

Keine Schemaänderung, keine neue persistierte Wahrheit und keine Änderung von Editorial Package Format 1/storyboard.md. Kein TTS, Audio, Rendering, Visuals, Bildersuche, Musik, Untertitel, Upload oder Publishing. Technische Referenzvalidität ersetzt weder Belegtragfähigkeit noch journalistische Prüfung.

## Prüfstand

Extern bestätigte Basis: 9ff593bb0ee7df4ddf8458fc9da1436ea8ea318c, Run 38041005988, Apple Swift 6.1.2, 645 erfolgreiche Tests und nativer arm64-Build. Alle bestehenden Tests bleiben unverändert. 53 neue Offline-Tests ergeben erwartete 698 Tests: 139 Core, 86 Scripting, 112 Research, 174 Persistence, 106 AppModel, 66 Export, 15 VideoPlanning.

Neue Tests umfassen Plan/Selektion/Mehrdeutigkeit, Quellen, atomare Sammelprüfung, explizite finale Freigabe und Rollback nach Checkpoint, Historie/neue Version, Video-Gates/Determinismus/Dauern, Fake-Provider-End-to-End, Research-Review-Integration sowie verzögerte HTTP-Stubs für stale input. Keine echten politischen Daten oder API-Calls.

Lokal sind Swift und Xcode nicht verfügbar: swift --version, swift test und xcodebuild scheitern mit command not found (Exit 127). Neue Tests und App-Build benötigen den unveränderten macOS-15-CI-Lauf; kein lokaler oder neuer CI-Erfolg behauptet.

Die GitHub-CLI ist vorhanden (2.46.0); der Actions-Abruf liefert Forbidden. Git-Remote-Lesezugriff funktioniert. Deshalb bleibt der neue macOS-Test-/Buildnachweis extern zu bestätigen.
