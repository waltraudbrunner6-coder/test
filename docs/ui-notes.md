# Native macOS UI — Phase 3.2b

## Aufbau

`PoliticalFactCheckApp.xcodeproj` enthält das native SwiftUI-App-Target mit macOS 14 als Mindestversion und bindet das lokale Package über die Root-`Package.swift` ein. Der Domain-Core und SwiftData bleiben eigene Module; die App erhält fachliche Typen über `PoliticalFactCheckCore` und `PoliticalFactCheckPersistence`.

`App/PoliticalFactCheckApp/App/PoliticalFactCheckApp.swift` öffnet beim Start `LocalCaseStore` im Application-Support-Verzeichnis `PoliticalFactCheck/Cases.store`. Startfehler werden in die Oberfläche weitergegeben. `Views/MainWindowView.swift` stellt die Split-Navigation, Sidebar, Toolbar und Empty State bereit. `Views/CaseDetailView.swift` zeigt Überblick, Versprechen, Kriterien, Quellen/Fundstellen, Handlungen/Entwicklungen, Evidenz und vorhandene historische Bewertungen. `Views/EditorSheets.swift` enthält kleine manuelle Erfassungsdialoge.

`PoliticalFactCheckAppModel` ist die einzige ViewModel-Schicht. `CaseWorkspaceModel` koordiniert den lokalen Store, lädt ausgewählte Fallgraphen, ruft Domain-Übergänge auf, erstellt Audit-Einträge und hält UI-Fehlermeldungen. Views rufen diese konkreten Aktionen auf und enthalten keine Kategorie- oder Wahrheitslogik. App-Modelltests verwenden In-Memory-SwiftData und synthetische Fixtures.

## Mögliche Aktionen

- leeren lokalen Workspace anzeigen und manuell einen ungeprüften Fall anlegen
- Prüfername lokal festlegen
- Kriterien als Draft anlegen und ausdrücklich menschlich bestätigen
- Quellen-Metadaten und Fundstellen ohne Download oder URL-Abruf erfassen
- Quellenfassung und Fundstelle durch eine menschliche Aktion als geprüft markieren; dabei entstehen neue unveränderliche IDs
- Originalzitat anhand des geprüften wortgleichen Auszugs separat bestätigen
- erlaubten Workflowübergang von `candidate` zu `documented` ausführen
- Kontext und bestehenden Sprecher mit separat ausgewählten geprüften Fundstellen menschlich bestätigen
- neu angebundene Kriterien erneut bestätigen und getrennt `documented → verified → readyForEvaluation` fortschreiben
- nur löschbare Draft-Cases löschen
- Handlungen/Entwicklungen mit allen sechs vorhandenen ActionTypes und optionalen Quellenbezügen ungeprüft erfassen
- Beschreibung, Ereignisdatum und Geltungsbereich einer Handlung ausdrücklich anhand ausgewählter geprüfter Fundstellen menschlich prüfen; eine neue ActionRevision entsteht, die vorherige bleibt lesbar
- Evidenz-Draft gegen ein aktives bestätigtes Kriterium mit ausgewählten geprüften Fundstellen und optional einer konkreten Handlungsrevision erfassen
- Evidenz ausdrücklich zur Prüfung vorlegen und anschließend menschlich prüfen (`draft → needsReview → verified`); kein direkter Sprung von Draft zu verified
- ReviewRequired neben historisch erhaltenen Bewertungen anzeigen

Die gespeicherten Informationen und Validierungsfehler bleiben sichtbar. Es gibt keine automatische Freigabe, Bewertung, Quellenbeschaffung oder Korrektur.

## Build und Tests

Auf macOS: `swift test` für Core, Persistence und App-Modell; `xcodebuild -project PoliticalFactCheckApp.xcodeproj -scheme PoliticalFactCheckApp -destination 'platform=macOS,arch=arm64' ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build` für das App-Target. Der GitHub-Actions-Workflow führt beide Befehle auf `macos-15` aus. Xcode- und SwiftUI-Builds sind lokal in einer Linux-Cloud-Umgebung nicht ausführbar; ein grüner Run ist für diesen UI-Schritt separat zu prüfen.

## Bewusste Grenzen

Noch keine freie Bearbeitung vorhandener Versprechen oder bestätigter Kriterien; Änderungen benötigen zunächst explizite neue Revisionen. Es gibt keine UI zum Erfassen von ActionParticipations, keinen Ersatzreview oder freie Bearbeitung gespeicherter Bewertungsinhalte, keine Archivierung, Suche, Filter, Dateiablage, Import/Export, Netzwerk, KI, Cloud, Medien oder Veröffentlichung. Die Tabellen der Quellen und Kriterien sind für einen einzelnen lokalen MVP-Fall gedacht. SwiftUI-Previews erzeugen ausschließlich synthetische Daten in einem In-Memory-Store.

## Phase 3.1: manuelle Eingabe, noch keine Bewertung

`CaseWorkspaceModel` ruft eng zugeschnittene atomare Store-Vorgänge auf; Views verwenden die bestehenden Core-Typen. Die Picker verwenden lokale Auswahlindizes nur zur Darstellung der vorhandenen Domain-Enums, keine Ersatz-Domainmodelle. Fundstellenlisten zeigen gespeicherte Quelle, Locator, Text und Prüfstatus. Die Evidenzerfassung und Handlungsprüfung bieten nur geprüfte, vom Core akzeptierte Fundstellen an. Ungeprüfte Handlungen dürfen ohne Beleg gespeichert werden, ersetzen jedoch keine Fundstelle einer Evidenzverknüpfung.

Eine Handlung ist noch keine Bewertung. `EvidenceRelationship` ist keine Bewertungskategorie. Beziehung, Direktheit, Begründung und zeitlicher Bezug werden vom Menschen festgelegt und separat geprüft; es gibt keine automatische Schlussfolgerung aus `contradicts`. Nur der explizite menschliche Prüfschritt mit `HumanReview` kann eine Evidenz verifizieren. Die bestehende Core-State-Machine verlangt zwei separate Übergänge; die UI bietet dafür „Evidenz zur Prüfung vorlegen“ und „Evidenz prüfen“ an. Schaltflächen prüfen die erlaubte Transition über `DomainChanges`; der Store prüft erneut mit dem frischen Fallgraphen. Fehler bleiben im Workspace und in den neuen Dialogen sichtbar.

Attribution wird nicht aus Parteizugehörigkeit abgeleitet. ActionParticipation-Erfassung bleibt nächster Ausbau. Die Handlungsprüfung bestätigt gemeinsam die drei asserted fields; getrennte Feldprüfungen, freie Inhaltsbearbeitung und Korrektur vorhandener Evidenzlinks sind noch nicht Teil dieser Oberfläche. Historische Handlungsrevisionen sind nur lesend. Die anschließende Bewertungsreife wird in Phase 3.2a separat hergestellt (siehe unten). Keine neue Evaluation, kein Bewertungssnapshot und keine produktive MethodologyVersion werden erzeugt. Bewertung folgt erst in Phase 3.2.

Phase 3.1 ist inzwischen extern bestätigt: Commit `3a484a6261621dd21c94a023d6c0a0f403799147` hat laut Nutzerprüfung 160 erfolgreiche Tests (90 Core, 57 Persistence, 13 AppModel) und einen erfolgreichen nativen arm64-Build mit Apple Swift 6.1.2. Lokal fehlen Swift und Xcode weiterhin; die macOS-15-CI führt zuerst Tests, danach den App-Build aus.

## Phase 3.2a: Bewertungsreife ohne Bewertung

Der Versprechenbereich zeigt Kontext, Sprecher, jeweilige Prüfstatus und Fundstellen. Das Sheet „Prüfrahmen bestätigen“ verlangt konkreten Kontexttext und zwei ausdrückliche Fundstellenauswahlen (Kontext / Sprecher). Es zeigt ausschließlich verifizierte Excerpts mit verifizierter Quellenfassung des geladenen Cases. Der bestehende Sprecher bleibt derselbe Actor; Partei, Quellenherausgeber oder Affiliation erzeugen keine automatische Zuordnung.

`CaseWorkspaceModel.verifyPromiseForEvaluationReadiness` ruft die neue atomare Store-Operation auf. Die pure Core-Operation `DomainChanges.verifyPromiseForReadiness` erzeugt eine neue PromiseRevision und bindet alle aktiven Kriterien als neue Draft-Revisionen an sie. Das geprüfte Originalzitat und alle unveränderten Felder bleiben exakt erhalten. Alte Promise-/Kriterienrevisionen bleiben lesbar, zuvor bestätigte Kriterien müssen mit „Kriterium bestätigen“ erneut geprüft werden. Vorhandene Evidenz verweist weiterhin auf die vorherigen Kriterienrevisionen; neue Zuordnungen müssen ausdrücklich erfasst und geprüft werden. Bei historischen CaseRevisions oder CaseEvaluations wird die direkte Neubindung vollständig blockiert.

„Fall als geprüft markieren“ und „Zur Bewertung vorbereiten“ sind getrennte menschliche Aktionen. Fähigkeiten werden direkt über `DomainChanges.transition` ermittelt; der Store prüft denselben Übergang mit einem frischen Graphen. Draft-Kriterien oder unpassender Promise-Bezug verhindern Bewertungsreife. Der Abschnitt „Bewertungsreife“ zeigt Feldstatus, Anzahl aktiver/bestätigter/Draft-Kriterien und Workflow zur Orientierung; er ersetzt keine Core-Validierung. Es entsteht keine Evaluation und keine Bewertungskategorie. Der direkte Prüfrahmen-Vorgang wird nur im Zustand `documented` angeboten; Bearbeitung nach weiteren Meilensteinen und Neubewertung sind bewusst spätere Aufgaben.

Extern bestätigter Ausgangsstand für diesen Schritt: `3a484a6261621dd21c94a023d6c0a0f403799147`, Apple Swift 6.1.2, 160 Tests erfolgreich und nativer arm64-Build erfolgreich. Neu: 16 Core-, 8 Persistence- und 6 AppModel-Tests, erwartet 190 insgesamt. Die bisherigen 160 Tests bleiben unverändert. Neue Tests prüfen Live-Fundstellen/Quellenfassungen, Kontext/Sprecher und Zitat-Erhaltung, Kriterienneubindung mit erneuter menschlicher Bestätigung, beide Workflowübergänge, historische Sperre, Rollback, Audit, echte temporäre Store-Wiederöffnung und die Abwesenheit erzeugter Bewertungen. Die reale Ausführung dieser Änderungen benötigt weiterhin die macOS-CI.

Für Phase 3.2a endeten die tatsächlichen lokalen Versuche `swift --version`, `swift test` und `xcodebuild` mit Exit 127 (`command not found`). `git diff --check` ist erfolgreich; dies ersetzt keinen Compiler-/Testnachweis. Es wird kein neuer Build-Erfolg behauptet.

## Phase 3.2b: manuelle Bewertung

Aus einem bewertungsbereiten Case führt „Neue Bewertung starten“ in ein Sheet. Der Bewertungsstichtag muss ausdrücklich als Kalendertag (UTC) eingegeben werden; es gibt keinen stillen aktuellen Datumswert. Nach Bestätigung wird genau ein unveränderlicher Snapshot und die kanonische MethodologyVersion 1.0 gespeichert. Die Zusammenfassung zeigt Promise-/Kriterienrevisionen, Handlungen, geprüfte Evidenz, Quellenfassungen/Fundstellen und Erstellungszeit. Ein begonnener Snapshot lässt sich über „Snapshot weiterbewerten“ wieder öffnen; sein Inhalt wird nicht geändert. Vor der ersten Entwurfsspeicherung wird beim Fortsetzen der Stichtag erneut eingegeben, da CaseRevision im bestehenden Modell keinen Stichtag hält.

Alle sechs Kategorien und alle drei Evidenzsicherheiten beginnen ausdrücklich **ohne Auswahl**. Jeder Kriteriumseditor zeigt Messlatte, Kernstatus, Materialität, Frist, nur seine verified Snapshot-Links, Beziehung/Direktheit, Fundstellen und optionale Handlung. Gegenbelege können ausschließlich innerhalb ausgewählter verwendeter Links markiert werden. Begründung, Unsicherheiten und strukturierte Nicht-überprüfbar-Gründe werden menschlich eingegeben. Die Gesamtbewertung besitzt separate Eingaben; Fakten und Interpretationen sind klar getrennt. Keine KI, keine Aggregation, keine automatisch vorgeschlagene Kategorie.

Ein vollständiger gültiger Entwurf persistiert die unreviewed CriterionEvaluations, die draft CaseEvaluation und den evaluated-Meilenstein atomar. Die Fallansicht zeigt jedes Kindergebnis mit verwendetem Material und bietet „Kriteriumsbewertung prüfen“ an. Erst danach erfolgen getrennt „Bewertung zur Prüfung vorlegen“ und „Bewertung freigeben“. Freigabe prüft den Core erneut und setzt zugleich den historischen approved-Meilenstein. Alle historischen Inhalte, Original-Approval und konkrete Manifest-IDs bleiben erhalten. Retrospektive Publikation und uneindeutige Zeitbezüge werden als sichtbare Domainwarnungen dargestellt, nicht still ausgeschlossen. ReviewRequired bleibt neben der historischen Freigabe sichtbar; Ersatzbewertung folgt später.

Bekannte Grenzen: Ungespeicherte Formtexte sind nur Sheet-State; Schließen verliert diese Texte, nicht den gespeicherten Snapshot. Gespeicherte Entscheidungsinhalte werden nicht in-place editiert. Korrektur über neue Draft-Datensätze, Ersatzreview, mehrere parallele Bewertungen und satzweise Quellenprüfung folgen separat. Ein formal gültiger Draft kann nach bestehenden Regeln erst bei der finalen Freigabe blockiert werden (etwa positive Kategorie ohne supports oder niedrige Sicherheit bei negativem Urteil); die Fehlermeldung bleibt sichtbar. Authentizität, Materialität und Wahrheitsgehalt sind weiterhin menschlich zu prüfen.

Extern bestätigte Basis: a551f82c5cdd5a48881005543e4c6b08c8754815, Apple Swift 6.1.2, 190/190 Tests und nativer arm64-Build erfolgreich. Neu: 27 Core-, 21 Persistence- und 6 AppModel-Tests; erwartet **244 Tests**. Die bisherigen 190 Tests und der Workflow bleiben unverändert. Lokal ist noch keine neue erfolgreiche Swift-/Xcode-Ausführung nachgewiesen; diese Änderungen benötigen ihren eigenen macOS-CI-Lauf.

## Phase 4.1: lokaler Skriptworkflow

Der separate, netzwerkfreie `PoliticalFactCheckScripting`-Vertrag liefert Transferwerte über das bestehende AppModel-Produkt; Domainobjekte bleiben im Core. Der Skriptbereich bietet pro approved Evaluation „Skriptentwurf erzeugen“ mit ausdrücklich gekennzeichnetem lokalem Fake und einen unabhängigen manuellen Entwurf. Zielzeit 30–60 Sekunden (45 als Default) ist nur ein Planwert. Providerfehler, ungültige Referenzen und fehlende Satzreviews bleiben sichtbar. Während der asynchronen Generation verhindert ein Busy-Flag parallele Generierungen; nach der Rückkehr prüft der Store den Bewertungsstatus nochmals.

Skriptkarten zeigen Version, operativen Status, Zielzeit, Autor/Herkunft, Erstellzeit, konkrete Evaluation-ID, ursprüngliche Freigabe und geordnete Sätze mit Typ, Unsicherheit, Prüfvermerk und Evidenz. Fundstellen sind direkt aufklappbar, mit Titel/Herausgeber der konkreten Quellenfassung, Locator, Text, Kontext und Prüfstatus; Satz und Beleg stehen nebeneinander. „Statement prüfen“, „Skript zur Prüfung vorlegen“ und „Skript freigeben“ sind getrennte menschliche Aktionen. Ein verknüpfter Beleg ist noch kein Nachweis seiner tatsächlichen Tragfähigkeit für den Satz.

„Als neue Version bearbeiten“ öffnet denselben manuellen Editor mit kopierten Inhalten. Satztext, Typ, Unsicherheit, Quellen-/Evidenzkeys, Reihenfolge und Hinzufügen/Entfernen sind editierbar. Speichern erzeugt eine vollständige neue Version mit neuen Satz-IDs und ohne alte Reviews; die alte Fassung bleibt unverändert. Lesbare Keys werden zusammen mit den verfügbaren Snapshot-Auszügen angezeigt und durch den Store strikt geprüft. Das Formular ist lokaler Sheet-State, Schließen verliert ungespeicherte Änderungen. Keine automatische Ablösung einer bestehenden Freigabe.

ReviewRequired blockiert neue Entwürfe, Satzprüfung und Freigabe. Historische Texte und ursprüngliche Prüfvermerke bleiben sichtbar; die bestehenden Persistenzregeln markieren abhängige approved Skripte superseded. Die Oberfläche meldet „Bewertung muss erneut geprüft werden“. Ersatzbewertung bleibt eine Folgephase.

Keine echte KI, Recherche, API-/Netzwerk-, Keychain-, Export- oder Medienfunktion. Der Fake kopiert bereitgestellte Texte ohne journalistische Schlussfolgerung oder gemessene Sprechdauer. Echter Provideradapter folgt in Phase 4.2. Die bestehenden 244 Tests und der CI-Ablauf bleiben unverändert; für Phase 4.1 werden neue Tests ergänzt. Ohne erfolgreiches eigenes CI-Ergebnis gilt SCRIPT WORKFLOW AWAITING CI VERIFICATION.

Prüfstand Phase 4.1: 59 neue Tests (6 Core, 24 Scripting, 21 Persistence, 8 AppModel), erwartet **303 insgesamt**. Alle 244 bisherigen Tests bleiben unverändert. Lokale Aufrufe von swift --version, swift test und xcodebuild enden mit Exit 127 (command not found); GitHub-Actions-Abruf liefert Forbidden. git diff --check ist erfolgreich, aber kein Compiler-/Testnachweis. Der unveränderte Workflow führt nach Push auf main zuerst swift test und anschließend den nativen arm64-App-Build aus; Ergebnis extern zu prüfen.


## Phase 4.2: explizite OpenAI-Übertragung

Die normale Skriptaktion öffnet „An OpenAI übertragene Daten“ mit Modell, Zielzeit, Kategorie, Mengen und vollständigem, auswählbarem JSON-Nutzdatentext einschließlich Originalversprechen, Kriterien, Fundstellen/Locators und Unsicherheiten. Erst „An OpenAI senden“ sendet; Abbrechen bleibt lokal. Die Hinweise benennen die externe Übertragung und den ungeprüften Entwurf ausdrücklich. Kein Schlüsselfeld, Modellpicker oder automatische Recherche. Fehlender OPENAI_API_KEY blockiert nur die Provideraktion, nicht manuelle Skripte. Der Fake bleibt ausschließlich als klar beschriftete Debug-Aktion und in Tests.

Frisch geladener Fall, approved-Status, Snapshotinput und lokaler Änderungstoken werden vor dem Senden geprüft. Relevante Änderung verlangt neue Vorschau; wiederholbare Providerfehler erhalten sie. Busy-Flag, deaktivierte Send-/Abbrechen-Buttons und ProgressView verhindern parallele Requests. Erfolg zeigt neue Version als „KI-Entwurf – ungeprüft“; bestehende Satzprüfung/Freigabe bleiben unverändert. Keine automatische HumanReview oder politische Neubewertung.

Technische Einzelheiten, Key-Umgebung, Datenschutzgrenzen und Promptversion stehen in openai-integration.md. Phase-4.1-Basis ist extern mit 303 Tests/BUILD SUCCEEDED bestätigt. Neu: 67 Offline-Tests, erwartet 370 insgesamt; neuer macOS-Test-/Buildnachweis ausstehend. UI-Interaktionen sind nicht durch einen automatisierten UI-Test nachgewiesen.


## Phase 4.3: Redaktionspaket

Der neue Exportbereich zeigt vor dem Zielpanel Bewertung, Stichtag, Methodik, Scriptversion/approved, Satz-/Quellenfassungs-/Fundstellenzahl und Format 1. „Redaktionspaket exportieren“ wird nur für ein über die gemeinsame Export-/Domainvalidierung zugelassenes Skript angeboten. NSSavePanel wählt den expliziten neuen Zielort; vor Schreiben wird der Fall frisch geprüft. Keine zweite UI-Freigabelogik und kein Überschreiben bestehender Pakete.

„Redaktionspaket importieren“ in der Haupttoolbar öffnet NSOpenPanel für ein .politicalfactcheck-Verzeichnis. Vollständige Prüfung erfolgt vor dem Sheet mit Titel, Bewertung, Stichtag, Methodikversion, Scriptversion und Exportzeit. Erst „Importieren“ persistiert nach erneuter Datei-/Manifestprüfung atomar. Abbrechen speichert nichts. Vorhandene Case-ID, Hash-/Methodikkonflikte und Referenz-/Domainfehler erscheinen kontrolliert im Workspace. Kein Netzwerk oder OpenAI-Aufruf in diesen Aktionen. Native Panels sind ausschließlich in der App; keine UI-Abhängigkeit im Exportmodul.

Das Paket repräsentiert einen historischen geprüften Stand, erzeugt keine politischen Aussagen und enthält keine erfundenen Visuals. Details und Datenschutz-/Archivgrenzen: export-format-v1.md. Die Basis 68a45367a3b5af0ba0817617fc114415e520d5db ist extern mit 370 Tests und erfolgreichem nativen Build bestätigt; neue Tests/Build benötigen gesonderten CI-Nachweis.

Prüfstand Phase 4.3: 85 neue Tests, erwartet 455 insgesamt (139 Core, 71 Scripting, 119 Persistence, 60 AppModel, 66 Export). Alle bisherigen 370 Testdateien unverändert. Lokal Swift/Xcode Exit 127; GitHub-Actions-Abfrage Forbidden. git diff --check erfolgreich. Neuer CI-Test-/Buildnachweis ausstehend; Workflow unverändert.

Die gestagte Diff-Prüfung meldet ausschließlich die absichtlich bytegleich kopierte abschließende Leerzeile der kanonischen Methodikressource. Alle übrigen Dateien bestehen git diff --cached --check. Die Ressource wird wegen ihres eingefrorenen SHA-256 nicht getrimmt.

## Phase 4.4: Stabilisierung und Abnahme

Die Basis df027bafca4da0d84cebe90f113f349344f93966 ist extern mit 455 erfolgreichen Tests und erfolgreichem nativen arm64-Build bestätigt. Acht neue AppModel-Cross-Layer-Tests starten ohne Seed im temporären lokalen Store und bedienen die vorhandenen produktiven Aktionen bis Export/Import. Erwartet 463 Tests; neuer CI-Nachweis ausstehend. Technische Kriterien und manuelle reale Fallabnahme stehen in mvp-acceptance.md und mvp-real-case-acceptance.md. Native Panels und SwiftUI-Interaktionen bleiben manuell am Mac zu prüfen.

Konkrete UX-Korrekturen: Prüfername direkt im ersten Fallformular; bestehende WorkspaceFormError-Anzeige auch in Fall-, Kriterium- und Quellendialogen, damit Blocker nicht hinter dem Sheet verborgen bleiben. Skript-Ladefehler verwenden WorkspaceErrorMessage statt roher Fehlerinterpolation. Keine neue Domain-/Workflowlogik. Überblick und Bewertungsreife bleiben informative Ableitungen; keine zusätzliche Fortschritts-State-Machine. Die menschliche Abnahmevorlage enthält keine reale Partei oder Aussage.


## Phase 5.1: automatische Recherche-Inbox

Extern bestätigte Basis: d0f2460e33f5360c718df7e29b254220431819c8, 463 erfolgreiche Tests und nativer arm64-Build. Neuer Stand benötigt eigene CI-Verifikation. „Automatisch Fälle finden“ startet ohne manuelle Query sechs symmetrische Quellengruppen; die Inbox ist aus candidate-Cases mit bestehendem ResearchTask.result abgeleitet, kein zweiter gespeicherter Zustand. Quellenlinks, Titel/Zitat, getrennte Akteure/Datumsrollen, transparente Prüfbarkeit und Unsicherheiten sind sichtbar. Öffnen nutzt die vorhandene Fallbearbeitung, Verwerfen ausschließlich deleteDraftCase. Laufende Runde verhindert Doppelstarts, Abbruch verwirft noch nicht übernommene Ergebnisse; vorhandene Fälle bleiben bedienbar.

PoliticalFactCheckResearch liefert typisierte ungeprüfte Kandidaten und echte Web-Search-Provenienz. LocalCaseStore.insertDiscoveryCandidate prüft URL/Quote-Dedup gegen gespeicherte Fallrevisionen und speichert pro Kandidat Graph, ResearchTask und AI-Audit atomar. Quellen-/Fundstellenstatus bleibt ungeprüft, alle AssertedValues aiExtracted/unreviewed. Keine Reviewer, Kriterien, EvidenceLinks, Evaluationen oder Skripte werden automatisch angelegt. Task.result hält nur versionierte ausgewählte Suchmetadaten, keine Secrets/rohen HTTP-Antworten. Schema 1.0.0, Payload 1, historische Revisionen und Delete Rules bleiben unverändert. Quellenprüfung und Bewertung sind separate spätere Schritte. Details und Grenzen: docs/automatic-research.md.


## Phase 5.2: Deep-Research-Dossier

Serielle Bulk-Aktion „Alle Kandidaten automatisch vertiefen“, Einzelaktion im Candidate-Detail, Fortschritt nach Kandidat und Lane, sichere Abbruchgrenze vor atomarer Kandidatenübernahme. Vor Start werden Kandidatenzahl und bis zu 11 Lanes genannt; keine genaue Euro-Kostenschätzung. Manuelle Bearbeitung bleibt nutzbar. Die Dossieransicht trennt Coverage, Proposal-Evidenz und AI-Bewertungsvorschlag von menschlich geprüften Domainbewertungen. Quellenlinks/Fundstellen und Unsicherheiten bleiben sichtbar.

LocalCaseStore.saveCaseResearch ergänzt Drafts und einen ResearchTask mit DeepResearchRecordV1/Domain-Bindings plus AI-Audits in genau einer Transaktion. Bestehende Original-/Discovery-/manuelle Daten und historische IDs bleiben unverändert. Kein confirmed/verified/approved und kein Workflow-Fortschritt aus bloßer Recherchemenge. Erneuter Lauf wird übersprungen; struktur-/referenz-/policy-ungültige Ergebnisse rollen vollständig zurück. Technische Lane-Ausfälle können explizite Coverage-Lücken und noRecommendation in einem gültigen Dossier hinterlassen. Schema 1.0.0, Payload 1 und Delete Rules unverändert. Quellenidentitäts-/Fassungsgrenzen und Assessment-Gates sind in docs/automatic-evidence-research.md dokumentiert. Neue Tests vollständig offline; neuer macOS-CI-Nachweis separat erforderlich.

## Phase 5.3 – Recherche prüfen

Dossier-Fälle erhalten sechs lokale Reviewstufen: Original, Kriterien, Fundstellen, Entwicklungen, Evidenz, Bewertung. Inhalte sind vorbefüllt; Kontext ist korrigierbar. Aktive Prüfklicks verlangen Reviewer-Namen. Fortschritt/Blocker sind aus Domainzuständen und Auditbindungen abgeleitet. Nicht übernommene Gegenbelege benötigen Bestätigung. Finale Freigabe verlangt Checkbox je Kriterium plus Gesamtbestätigung. Manuelle Editoren, Dossier und Skriptbereich bleiben erhalten; kein automatischer Script-Aufruf. Details: [research-review-queue.md](research-review-queue.md).
