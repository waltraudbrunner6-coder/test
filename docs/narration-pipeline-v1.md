# Narration-Pipeline V1 – Phase 6.1

## Grenze und Aufbau

`PoliticalFactCheckAudio` ist ein separates macOS-14-Package-Target. Es verwendet Foundation, CryptoKit, AVFoundation, Core und den unveränderten VideoPlanning-Vertrag; keine direkte Scripting-, SwiftData- oder SwiftUI-Abhängigkeit. AppModel koordiniert Auswahl, Fachgates und explizite Benutzeraktionen; die UI zeigt nur lokale Ergebnisse. Keine neue Domain-Entität und kein neuer journalistischer Freigabestatus.

Der Ablauf ist: frisch validiertes approved Script → `VideoScriptHandoffV1` → eine serielle TTS-Anfrage je Szene → technisch gültiges WAV → gemessene Szenendauer → lückenlose Narration-Timeline → deterministische Untertitel → lokales, validiertes NarrationPackage. Keine Änderung von Narrationtext, Satztyp, Belegen, Unsicherheit, fachlichen IDs oder historischer Freigabe.

## Provider und Datenminimum

`NarrationProvider` liefert Kennung, konfigurierten Modellstring und `synthesize(request:)`. Der neutrale Request enthält lokal scenePosition/statementID/text/voice/speed/format/instructions. Der HTTP-Adapter serialisiert ausschließlich `model`, `voice`, `input`, `response_format`, `speed`, `instructions`. `input` ist bytegetreu der String der jeweiligen Szene, einschließlich Whitespace. Keine UUIDs, strukturierten Bewertungen, Quellen, URLs, Reviewer, Audits, ResearchTasks, CaseGraphs oder lokalen Pfade. Namen, Zahlen und politische Inhalte können bereits im freigegebenen Narrationtext stehen; dies ist keine Anonymisierung.

`FakeNarrationProvider` erzeugt deterministische synthetische PCM-WAV-Stille (Mono, 16 Bit, 16 kHz), ohne Netzwerk. Für Tests lässt sich die Dauer festlegen; andernfalls dient nur eine synthetische Wortzahlregel. Fake-Audio belegt keine Aussprache oder TTS-Qualität.

`OpenAINarrationProvider` verwendet POST `https://api.openai.com/v1/audio/speech`, default `gpt-realtime-2.1-mini`, `marin`, `wav`, speed `1.0`, statisches `narration-style-v1`. Weitere eingebaute Voices: cedar/coral/alloy; technisch akzeptierte speed 0.85…1.15. Die UI verwendet vorerst nur Marin/1.0. Modell bleibt ein konfigurierbarer String; kein veraltetes Schema-Enum-Gate, Retry oder automatischer Fallback. Die vom Auftrag angegebene aktuelle Modellseite und möglicherweise nachlaufende Endpoint-Schemas sind der Grund für diese Entscheidung; Live-Endpoint-/Account-Kompatibilität bleibt separat zu bestätigen. Dokumentationsabrufe waren hier mit HTTP 403 gesperrt, kein unabhängiger Nachweis aktueller Modellverfügbarkeit.

Der Schlüssel kommt ausschließlich aus `OPENAI_API_KEY` im Prozess; nur temporärer Authorization-Header. Keine Speicherung in Manifest, Audiodateien, UserDefaults, SwiftData, Audit oder Logs. HTTP 400/401/403/408/429/5xx, Transport, Timeout, Abbruch, leere/überlange/nicht-auditive/beschädigte Antwort erzeugen strukturierte Fehler ohne rohen Serverbody. 60 s Request-Timeout. Ein eigener URLSessionDataDelegate begrenzt eingehende Chunks vor dem Anhängen auf 16 MiB je Szene; angekündigte Übergröße wird vor Bodyannahme abgelehnt. Kein unbegrenztes `data(for:)`. Die injizierte Session-Konfiguration erlaubt Offline-URLProtocol-Tests; pro Download existiert eine eigene begrenzte Session. Abbruch cancelt ihren aktiven DataTask.

## WAV und Zeiten

RIFF/WAVE-Marker und Containerlänge werden geprüft. Anschließend öffnet AVAudioFile das lokale WAV und decodiert sämtliche Frames in kleinen Buffern. Sample Rate, Channels, Frames und daraus `frames / sampleRate` müssen gültig, endlich und positiv sein. Ein Provider-HTTP-Erfolg allein genügt nicht. SHA-256 stammt aus tatsächlichen WAV-Bytes.

`estimatedDurationSeconds` bleibt der unveränderte Handoff-Planwert. Zusätzlich wird `measuredDurationSeconds` gespeichert. Szene 1 startet bei 0; jede weitere beim tatsächlichen Ende der vorherigen. Ende = Start + gemessene Dauer, Gesamtzeit = letztes Ende. Keine künstlichen Pausen. Zielzeit bleibt gesondert; außerhalb 30…60 s wird ein gültiges Paket erhalten und eine Warnung angezeigt, `readyForRendering` bleibt false. Keine verdeckte Tempoanpassung oder erneute Synthese.

Untertitel: [subtitle-timeline-v1.md](subtitle-timeline-v1.md). Audio-/Texttreue wird durch Request und Referenzchecks abgesichert; statische Instructions garantieren nicht, dass ein echter Provider jedes Wort tatsächlich korrekt spricht. Menschliches Anhören bleibt erforderlich. Keine Transcription-/Alignment-API.

## Lokaler Vertrag

`NarrationPackageManifestV1` (Codable, schemaVersion 1) enthält caseID/evaluationID/scriptID als unveränderte UUID-Rohwerte, scriptVersion, providerIdentifier/model/voice/speed/styleVersion/audioFormat/createdAt, targetDurationSeconds/actualDurationSeconds, requiresAIDisclosure/disclosureText, scenes und captionCues. Datums-Codierung: Foundation JSONEncoder/Decoder-Standard, Sekunden relativ zu 2001-01-01 UTC; das ist kein politisches Datumsfeld. Unbekannte Versionen, Felder oder Enumwerte werden abgelehnt, keine stille Reparatur.

`NarrationSceneAudioV1`: position, statementID, relativeFilename, sha256, **narrationTextSHA256**, byteCount, startSeconds/endSeconds, measuredDurationSeconds/estimatedDurationSeconds. Der zusätzliche Text-Hash bindet dieselbe fachliche Szene an ihren exakten Narrationstring. Cuefelder: index, statementID, scenePosition, startSeconds, endSeconds, text. `NarrationPackageV1.directory` ist ein flüchtiger lokaler URL-Wert, kein Manifestfeld. Kein Geheimnis, absoluter Benutzerpfad oder ungeprüfter Providerbody im Manifest.

`requiresAIDisclosure = true`, `disclosureText = "KI-generierte Stimme"` sind obligatorisch und werden beim Laden geprüft. Phase 6.2 muss den Hinweis sichtbar in das Video übernehmen. Keine Voice-Clones oder Personenimitation.

## Store, Rückkehr und stale input

Ziel: Application Support/PoliticalFactCheck/GeneratedMedia/<caseUUID>/<scriptUUID>/narration-v1/. Dateien ausschließlich manifest.json und scene-<position mit mindestens drei Stellen>.wav. Keine Binärdaten in SwiftData oder Editorial Package Format 1.

Alle Arbeit geschieht in GeneratedMedia/.tmp-<UUID>/. Pro Szene maximal 16 MiB, Gesamt-WAVs maximal 128 MiB, Manifest maximal 1 MiB. Fehler oder Cancellation löschen das eigene Stagingverzeichnis. Nach allen Szenen werden Manifest, tatsächliche Dateien, Hashes, Decoder und Cueableitung erneut geprüft. Erst dann folgen frische Fachgate-/Change-Token-Prüfung und finale Veröffentlichung ohne weiteren await.

AppModel baut vor Start aus einem frisch geladenen Graphen den bestehenden Handoff. Es verwendet **denselben** bestehenden `LocalCaseStore.scriptGenerationChangeToken` des vollständigen CaseGraph, einschließlich Informationen außerhalb des Snapshots. Nach allen Provideranfragen: frisch laden, denselben Script-Handoff erneut bauen, IDs/Version/Texte und Token vergleichen. Neue aktuelle Skriptfassung, superseded Script, Evaluation.reviewRequired, geänderte Statements/Graph oder gewechselte Auswahl verwerfen das neue Paket vollständig. Keine zweite Hashmethode und keine Persistence-Änderung.

Neues Paket: Rename/Move desselben lokalen Dateisystems. Explizites Ersetzen: FileManager.replaceItemAt mit erhaltenem Backup; bei gemeldetem Fehler wird das vorige vollständige Verzeichnis wiederhergestellt. Backup erst nach Erfolg entfernen. Kein await im Veröffentlichungsschritt. Dies ist eine lokale Dateitransaktion, keine kombinierte SwiftData-/Filesystem-Transaktion und keine Mehrprozess-Sperre. Ein Prozess-/Systemabsturz kann verwaiste .tmp-/Backupverzeichnisse hinterlassen; automatische fremde Tempbereinigung wird nicht implementiert. Vollständige Crash-Durability ist nicht zugesichert. CI testet echte macOS-Verzeichnisersetzung.

Reopen lädt ausschließlich das Paket des aktuellen approved Handoffs. Strikte Manifestvalidierung, beschränkte Reads, Referenz-/Text-Hash-/Audio-Hash-/Decoder-/Zeitchecks und ausschließlich sichere relative Dateinamen. Symlinkkomponenten und zusätzliche Dateien werden abgelehnt. Fehlende oder manipulierte Szenen erzeugen kontrollierte Fehler; kein Nachdownload, Neuhashing oder Überspringen. Explizites „Neu erzeugen“ ist erforderlich. Alte Skriptpakete bleiben historisch auf Platte, sind bei neuem Script oder reviewRequired keine aktuelle Videoeingabe. AppModel prüft `readyForRendering` erneut mit frischem Handoff und geladenen Dateien; die reine Paketfunktion prüft nur Manifest/Handoff/Dauer und ersetzt diese Fileprüfung nicht.

## UI und Prüflimits

Explicit „Sprachspur erzeugen“, sichtbares Modell/Voice/Format/Szenenzahl/Ziel, Disclosure, Progress Szene X von Y, Busy-Gate und Abbruch. Ergebnis zeigt Ziel/gemessen/Cuezahl, Bereichswarnung, einzelne lokale Szenen abspielen/stoppen. Kein Autoplay. AVAudioPlayer bleibt ausschließlich im Audio-Modul. Playback wird vor neuem Package-Laden/Selektionswechsel gestoppt; verspätete Callbacks einer alten Szene stoppen keine neue Wiedergabe.

Keine Videos, Bilder, B-Roll, Musik, Cloud, Transcription, Renderplanung oder Medienexport. Dateiprüfung/AV-Dekodierung ist lokal begrenzt, aktuell synchron im MainActor-Store; Hintergrund-I/O und Mehrprozesskoordination sind spätere Arbeiten. JSON/WAV-Verträge sind interne Artefakte, kein neues journalistisches Exportformat. Ein einzelner Writer/Benutzer bleibt Voraussetzung.

Basis laut externer Nutzerprüfung: fc2233a03bbe47916fed54798f18c2514804f8cd, Run 38048408211, Apple Swift 6.1.2, 698 Tests und nativer arm64-Build erfolgreich. Neue Phase-6.1-Tests verwenden ausschließlich synthetische Fixtures, Fake-WAVs, temporäre Verzeichnisse, In-Memory-SwiftData und URLProtocol; keine Live-Requests/Secrets. 65 Audio- und 15 AppModel-Tests ergänzen unverändert erhaltene 698 Tests: **778 erwartet**, nicht als ausgeführt behauptet. Bestehende Testdateien bleiben unverändert.

Tatsächlich versucht: `swift --version`, `swift test`, nativer arm64-xcodebuild; jeweils Exit 127, command not found. Die GitHub-CLI ist vorhanden (2.46.0), ihre Authentifizierung meldet einen ungültigen Token. Ausführung der neuen Tests und App-Build ist separat über den unveränderten macOS-15-Workflow zu bestätigen; keine neue grüne CI behauptet. `git diff --check`, bytegleiche Style-Dateien, erhaltene Testdateien und geschützte Core-/Persistence-/Research-/Scripting-/VideoPlanning-/Export-Bereiche werden statisch geprüft; dies ersetzt keinen Compiler.
