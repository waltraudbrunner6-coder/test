# Implementierungsnotizen: fachlicher Swift-Core

## Struktur und Prüfstand

Eigenständiges Swift Package `PoliticalFactCheckCore`, Swift-Tools-Version 5.9, ohne externe Dependencies und ohne Plattformbindung. `Domain/` enthält Werttypen, typisierte UUID-IDs, Datenobjekte und reine Änderungsfunktionen; `Validation/` enthält strukturierte Fehler, Warnungen, Übergangsregeln und Validatoren. Foundation dient ausschließlich grundlegenden Werten wie UUID, Datum und URL. `DomainContext` ist ein expliziter, unveränderlicher Validierungseingang mit auflösbaren Referenzen, kein Speicher oder Repository-Service.

73 XCTest-Testmethoden verwenden ausschließlich synthetische Akteure, Quellen und Versprechen. Die Methodik-Fixture ist ausdrücklich `TEST-FIXTURE-ONLY`; eine redaktionelle MethodologyVersion 1.0 wurde nicht erstellt. Getestet werden sollen auch der vollständige Fallgraph, Parteienneutralität, historische Referenzen sowie Veröffentlichung 2025 / Ereignis 2021 / Stichtag 2022.

In dieser Umgebung sind weder `swift` noch `swiftc` verfügbar. Der Aufruf `swift test` endet mit `swift: command not found` (Exit 127). **Kein Test wurde ausgeführt, keine Kompilierung bestätigt.** Eine statische Durchsicht einschließlich Klammern, Modell-Initialisierer, Argumentreihenfolge und Referenztypen ersetzt diese Prüfung nicht. Vor der Freigabe ist `swift test` mit einer Swift-Toolchain ab 5.9 erforderlich.

## Swift-Repräsentation und konservative Präzisierungen

- Alle Beziehungen verwenden `EntityID<T>`; beispielsweise ist eine Actor-ID keine Reviewer-ID. Erforderliche Einzelbeziehungen sind nicht optional. Validatoren prüfen zusätzlich, ob die referenzierte ID tatsächlich existiert. Ein ResearchTask kann strukturell nicht die Fundstelle eines EvidenceLink bilden.
- `NonEmptyText` erhält den Originaltext und verweigert leere oder ausschließlich aus Leerzeichen bestehende Werte. `FieldValue<T>` unterscheidet bekannt, unbekannt mit Grund und nicht anwendbar mit Grund. `AssertedValue<T>` trennt Herkunft, Verifikation und menschlichen Prüfvermerk. Eine nach menschlicher Prüfung bestätigte KI-Extraktion darf weiterhin `aiExtracted` als Herkunft behalten.
- Der eigene `DateInterval` unterstützt offene Grenzen und eine explizite Endkonvention; bei gleichzeitiger Verwendung von Foundation ist der Typ gegebenenfalls mit `PoliticalFactCheckCore.DateInterval` zu qualifizieren. Präzision liegt einmal in `DatedValue`. Tages-, Monats- und Jahrespräzision werden als begrenzte Intervalle repräsentiert; Kalendergrenzen und die richtige Zeitzone muss der Erfassende festlegen. Unbekannte oder den Stichtag überlappende Ereigniszeiten erzeugen einen menschlichen Prüfhinweis. Das Publikationsdatum einer späteren Quelle erzeugt höchstens einen Rückblickhinweis, keinen automatischen Ausschluss.
- Quellenmetadaten wie Titel und Herausgeber liegen an SourceVersion, damit historische Fassungen ihre Metadaten behalten. Source hält die gemeinsame Identität, nicht den historischen Text. Lokale Kopie und Hash sind nur Metadaten; der Core liest keine Datei und berechnet keinen Hash.
- CriterionRevision enthält zusätzlich die konkrete PromiseRevision-ID. Damit ist festgelegt, welche Auslegung des Versprechens die Messlatte betrifft. CaseRevision speichert konkrete Revision-IDs und eingefrorene Prüfzustände; keine zweite Kopie der Inhaltstexte.
- Alle Domain-Objekte sind Werttypen mit `let`-Feldern. Inhaltliche Änderungen benötigen neue Werte und bei Revisionen neue IDs. Kontrollierte Statuswechsel erhalten die ID und den Inhalt. `RevisionRules` verweigert den Austausch historischen Inhalts unter derselben ID; spätere Speicheroperationen müssen diese Grenze ebenfalls verwenden. SourceVersion und PromiseRevision werden vollständig unveränderlich behandelt: Änderungen von Feldverifikation benötigen dort eine neue Fassung, nicht eine Änderung der alten Fassung.
- Neue Kriterienrevisionen und verifizierte zusätzliche Evidenz liefern die neuen Werte sowie ReviewRequests und aktualisierte operative Evaluationszustände als gemeinsames Ergebnis. Die aufrufende Schicht muss dieses Ergebnis später zusammenhängend speichern. Historische Kategorie, Freigabe, Manifest und Begründung bleiben erhalten. Weder eine neue CaseRevision noch eine politische Neubewertung wird automatisch erfunden.
- ReviewerIdentity ist ausschließlich menschlich; KI-Modell und Promptversion gehören zu Authorship. Der Core kann eine angegebene menschliche Identität strukturell prüfen, aber nicht feststellen, wer tatsächlich vor dem Rechner sitzt.
- Es gibt keinen automatischen Kategorienrechner. Validatoren prüfen die Voraussetzungen einer menschlich gewählten Kategorie. Freigegebene positive Kategorien brauchen stützende Evidenz; negative Kategorien brauchen relevante Evidenz, `contraryAction` widersprechende geprüfte Evidenz. Diese Mindestprüfungen ersetzen keine inhaltliche Entscheidung.

## Technische Reichweite der Invarianten

Die Nummern beziehen sich auf die Anforderungen dieses Implementierungsschritts. „Vollständig“ bezeichnet die technische Struktur bei Verwendung der Validierungs- und Änderungsfunktionen, keine Aussage über politische Wahrheit.

| Regeln | Technisch umgesetzt | Grenze |
| --- | --- | --- |
| 2, 3, 5 | Pflichtreferenzen, Auflösung SourceVersion / CriterionRevision, ResearchTask getrennt von EvidenceLink | Keine journalistische Wahrheit ableitbar. |
| 1, 4, 14, 15 | Verifiziertes Zitat und Tatsachensatz benötigen geprüfte Fundstellen; Zitat muss in einer zitierten Fundstelle wortgleich vorliegen; Handlung allein genügt nicht | Authentizität, richtige Auswahl und Kontext bleiben menschlich. |
| 6, 13 | Freigabe benötigt eine auflösbare menschliche ReviewerIdentity und Prüfzeit | Tatsächliche Identität oder eine vorgetäuschte Prüfung ist ohne Benutzerkonten nicht nachweisbar. |
| 7, 8, 9 | Leere Evidenz und bloße Kontextlinks tragen kein negatives Urteil; widersprechender Link für contraryAction; strukturierter Grund und nichtleere Begründung für notVerifiable | Aussagekraft, Vollständigkeit der Gegenbelege und Angemessenheit der Gründe bleiben fachlich. Niedrige Evidenzsicherheit sperrt abschließendes notFulfilled / contraryAction. |
| 10, 11 | Neue Revisions-ID, unveränderliche historische Werte, Replacement-Prüfung und abhängige Review-Markierung | Aufrufer müssen Änderungen und Review-Markierungen gemeinsam anwenden; Persistenz und Audit-Schreibvorgänge fehlen bewusst. |
| 12 | Datumsrollen getrennt; Stichtag gegen Ereignis/Gültigkeit; zukünftiges Ereignis abgewiesen, spätere Veröffentlichung zulässig | Unscharfe Zeiträume und das tatsächliche Ereignisdatum brauchen menschliche Klärung. |
| 16, 17 | Bestätigte aktive Kriterien für readyForEvaluation; nur spezifizierte, benachbarte Workflowübergänge | Ob Messlatte, Materialitätsregel und Tatsachen ausreichend sind, entscheidet ein Mensch. |

Keine Lösch-, Speicher-, Import- oder Audit-Automatik ist enthalten. AuditEntry ist ein fachlicher Datenwert. Die technischen Beziehungen und historischen Inhalte können im Speicher validiert werden; Serialisierung und Wiederladen sind Gegenstand der späteren Persistenzphase.

## Offene Implementierungsfragen

1. Die verbindliche Spezifikation erlaubt ausschließlich vorwärtsgerichtete Case-Übergänge, verlangt aber Reviewbedarf nach neuen Kriterien oder Evidenz. Ein bereits `approved` geführter Case mit ausschließlich `reviewRequired`-Evaluation erfüllt die aktuelle Freigabevoraussetzung nicht mehr. Konservativ werden weder ein Rücksprung noch eine neue Freigabe erfunden; der Zustand wird als ungültig gemeldet. Vor Persistenz/UI muss geklärt werden, wie der Case-Fortschritt während einer erneuten Prüfung dargestellt wird.
2. Freigaben müssen später gemeinsam mit AuditEntry und Review-Markierungen gespeichert werden. Der Core liefert reine Ergebnisse; eine transaktionale Anwendungsoperation und das Lösch-/Archivierungsverhalten sind hier nicht implementiert.
3. Vollständige Inhaltsverifikation, Kriterienmaterialität, politische Zurechnung, tatsächliche menschliche Prüfung und Gesamtkategorie bleiben redaktionelle Entscheidungen. Eine produktive MethodologyVersion muss vor der ersten produktiven Freigabe verbindlich festgelegt werden.

Die drei verbindlichen Spezifikationsdokumente wurden nicht verändert. SwiftData, SwiftUI, AppKit, Netzwerk, Recherche, KI-API, Dateiimport, Export, Video und Voiceover wurden nicht implementiert.
