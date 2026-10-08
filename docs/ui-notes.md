# Native macOS UI — Phase 3.1

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

Attribution wird nicht aus Parteizugehörigkeit abgeleitet. ActionParticipation-Erfassung bleibt nächster Ausbau. Die Handlungsprüfung bestätigt gemeinsam die drei asserted fields; getrennte Feldprüfungen, freie Inhaltsbearbeitung und Korrektur vorhandener Evidenzlinks sind noch nicht Teil dieser Oberfläche. Historische Handlungsrevisionen sind nur lesend. Weitere Case-Übergänge über `documented` hinaus werden noch nicht angeboten. Keine neue Evaluation, kein Bewertungssnapshot und keine produktive MethodologyVersion werden erzeugt. Bewertung folgt erst in Phase 3.2.

Der bestätigte Ausgangsstand `9bd58e74e21cd4237bc75cd006efda06d028d3d2` hat laut externer Nutzerprüfung 139 erfolgreiche Tests und einen erfolgreichen nativen arm64-Build mit Apple Swift 6.1.2. Neu sind 6 AppModel- und 15 Persistence-Tests; erwartet werden 160 insgesamt (90 Core, 57 Persistence, 13 AppModel). Alle bisherigen Tests bleiben unverändert. Für diese Änderungen sind `swift --version`, `swift test` und `xcodebuild` lokal mit Exit 127 fehlgeschlagen (Tools fehlen). Neuer Compile-/Test-/App-Build-Nachweis steht aus; die unveränderte macOS-15-CI führt weiterhin zuerst Tests, dann den App-Build aus.
