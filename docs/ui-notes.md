# Native macOS UI — Phase 2.3

## Aufbau

`PoliticalFactCheckApp.xcodeproj` enthält das native SwiftUI-App-Target mit macOS 14 als Mindestversion und bindet das lokale Package über die Root-`Package.swift` ein. Der Domain-Core und SwiftData bleiben eigene Module; die App erhält fachliche Typen über `PoliticalFactCheckCore` und `PoliticalFactCheckPersistence`.

`App/PoliticalFactCheckApp/App/PoliticalFactCheckApp.swift` öffnet beim Start `LocalCaseStore` im Application-Support-Verzeichnis `PoliticalFactCheck/Cases.store`. Startfehler werden in die Oberfläche weitergegeben. `Views/MainWindowView.swift` stellt die Split-Navigation, Sidebar, Toolbar und Empty State bereit. `Views/CaseDetailView.swift` zeigt Überblick, Versprechen, Kriterien, Quellen/Fundstellen, Evidenz und vorhandene historische Bewertungen. `Views/EditorSheets.swift` enthält kleine manuelle Erfassungsdialoge.

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
- ReviewRequired neben historisch erhaltenen Bewertungen anzeigen

Die gespeicherten Informationen und Validierungsfehler bleiben sichtbar. Es gibt keine automatische Freigabe, Bewertung, Quellenbeschaffung oder Korrektur.

## Build und Tests

Auf macOS: `swift test` für Core, Persistence und App-Modell; `xcodebuild -project PoliticalFactCheckApp.xcodeproj -scheme PoliticalFactCheckApp -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build` für das App-Target. Der GitHub-Actions-Workflow führt beide Befehle auf `macos-15` aus. Xcode- und SwiftUI-Builds sind lokal in einer Linux-Cloud-Umgebung nicht ausführbar; ein grüner Run ist für diesen UI-Schritt separat zu prüfen.

## Bewusste Grenzen

Noch keine freie Bearbeitung vorhandener Versprechen oder bestätigter Kriterien; Änderungen benötigen zunächst explizite neue Revisionen. Es gibt keine UI zum Erfassen von Handlungen, EvidenceLinks, CaseSnapshots oder Bewertungen, keine produktive Methodikversion, keine Bewertungsfreigabe, keine Archivierung, Suche, Filter, Dateiablage, Import/Export, Netzwerk, KI, Cloud, Medien oder Veröffentlichung. Die Tabellen der Quellen und Kriterien sind für einen einzelnen lokalen MVP-Fall gedacht. SwiftUI-Previews erzeugen ausschließlich synthetische Daten in einem In-Memory-Store.
