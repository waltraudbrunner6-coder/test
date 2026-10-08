# Native macOS UI — Phase 3.2a

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

Noch keine freie Bearbeitung vorhandener Versprechen oder bestätigter Kriterien; Änderungen benötigen zunächst explizite neue Revisionen. Es gibt keine UI zum Erfassen von ActionParticipations, CaseSnapshots oder Bewertungen, keine produktive Methodikversion, keine Bewertungsfreigabe, keine Archivierung, Suche, Filter, Dateiablage, Import/Export, Netzwerk, KI, Cloud, Medien oder Veröffentlichung. Die Tabellen der Quellen und Kriterien sind für einen einzelnen lokalen MVP-Fall gedacht. SwiftUI-Previews erzeugen ausschließlich synthetische Daten in einem In-Memory-Store.

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
