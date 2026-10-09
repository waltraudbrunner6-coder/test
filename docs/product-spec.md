# Produktspezifikation: Politische Faktencheck-Videos für macOS

Status: Phase 5.2 · automatische Evidenzrecherche · Stand: 9. Oktober 2026

## 1. Ziel und Leitprinzipien

Eine macOS-Anwendung unterstützt die nachvollziehbare Prüfung öffentlich dokumentierter politischer Versprechen österreichischer Parteien. Sie vergleicht die Originalaussage mit später dokumentierten Handlungen und bereitet einen journalistisch pointierten, quellentreuen Kurzvideo-Entwurf vor.

**Alle Parteien werden nach derselben Methodik geprüft.** Parteiidentität, Popularität oder eine angenommene Absicht sind keine Bewertungskriterien. Eine Abweichung belegt für sich weder Täuschung noch Unehrlichkeit. Große, gut belegte Diskrepanzen dürfen die spätere redaktionelle Fallauswahl beeinflussen; sie verändern keine Bewertungsmaßstäbe.

Die bisherige technische MVP-Basis ist extern bestätigt: Commit d0f2460e33f5360c718df7e29b254220431819c8, 463 erfolgreiche Tests und nativer arm64-Build. Die Produktstrategie wird erweitert: automatische Fallfindung → Primärquellen → später automatisierte Beleg-/Gegenbelegsuche → Bewertungsentwurf → Skript/Storyboard/Video → menschliche Endprüfung und Freigabe. Phase 5.1 implementiert automatische Versprechenssuche und ungeprüfte candidate-Cases in einer Recherche-Inbox. Phase 5.2 ergänzt eigenständige Original-/Support-/Contra-/Kontext-Recherche, ungeprüfte Kriterien-/Source-/Action-/Evidence-Drafts und einen ausdrücklich separaten AI-Bewertungsvorschlag im Dossier. Diese Vorschläge sind keine echte CaseEvaluation und erzeugen keine menschliche Verifikation oder Freigabe. Alle späteren Automationsschritte sind Ausbauziele; manuelle Bearbeitung bleibt verfügbar. Methodik und menschliche Endfreigabe bleiben verbindlich. Siehe `docs/automatic-evidence-research.md`, `docs/automatic-research.md` und `docs/research-source-policy-v1.md`.

## 2. Komponenten und Ablauf

| Komponente | Aufgabe im MVP |
| --- | --- |
| Automatische Fallfindung | Gleiche versionierte Primärquellenpolitik für alle Parteigruppen; ungeprüfte Kandidaten ohne Nutzerquery, keine Bewertung. |
| Fallverwaltung | Ein Versprechen mit Akteur, Kontext, Prüfzeitraum und Kriterien anlegen. |
| Quellenablage | Dokumente, URLs, Auszüge und genaue Fundstellen manuell aufnehmen. |
| Automatische Vertiefung | Gleich budgetierte Recherche-Lanes und ungeprüfte Drafts; Kriterien vor Outcome-Recherche festhalten; keine automatische Reviewfreigabe. |
| Belegprüfung | Originalität, Kontext, Datum und Aussagekraft prüfen; Gegenbelege und offene Fragen dokumentieren. |
| Vergleichsansicht | Originalversprechen, Kriterien, spätere Handlungen und Evidenz nebeneinander anzeigen. |
| Bewertung | Regelgestützten Vorschlag erklären; abschließende Einstufung durch einen Menschen. |
| Skriptassistenz | Aus dem geprüften Fall einen kurzen Text mit belegten Aussagen und sichtbaren Einschränkungen entwerfen. |
| Redaktion und Export | Satzweise Quellenzuordnung prüfen; Skript, Quellenliste und Prüfprotokoll exportieren. |

Die KI kann zunächst eine ausdrücklich ungeprüfte Prüfthese vorschlagen. Der Mensch bestätigt die prüfbare Bedeutung und Kriterien vor der Bewertung. Allgemeine Ziele werden nur bewertet, wenn überprüfbare Kriterien ohne nachträgliche Bedeutungsverschiebung ableitbar sind. Mehrteilige Versprechen erhalten einzelne Kriterien; unabhängige Versprechen werden getrennte Fälle.

Eine Checkliste verlangt die Suche nach bestätigenden und widersprechenden Belegen, einschließlich späterer Korrekturen und Stellungnahmen des betroffenen Akteurs. „Keine Handlung gefunden“ ist zunächst eine Recherchelücke. Eine Aussage über das Ausbleiben einer Handlung braucht eine geeignete, ausreichend vollständige Dokumentationsgrundlage.

## 3. Datenmodell, Identität und Versionierung

Die Implementierungsreferenz ist `docs/domain-model.md`; Beziehungen und Kardinalitäten stehen in `docs/domain-model-relations.md`. Dieser Abschnitt fasst die fachlichen Festlegungen zusammen. Die Anwendung bleibt eine lokale macOS-App für zunächst einen Benutzer, zunächst vollständige einzelne Fälle mit je einem Versprechen, ohne Server oder Microservices.

**Aggregate und Identitäten:** `Case` ist Aggregate Root. Es enthält im MVP genau ein `Promise`, mehrere Kriterien, Quellen und Quellenfassungen, Handlungen/Entwicklungen, Evidenzverknüpfungen, ResearchTasks und Prüfungen. Actor, Source, Promise und ActionOrDevelopment haben stabile IDs. Unabhängige Versprechen erhalten separate Cases.

**Unveränderliche Revisionen:** PromiseRevision hält Originalwortlaut, Kontext und separate Prüfthese; EvaluationCriterion ist die stabile Kriterienidentität, CriterionRevision die vor der Bewertung bestätigte Messlatte. Source bezeichnet ein logisches Dokument/Endpoint, SourceVersion eine konkrete Fassung (Publikations-, Abruf- und gegebenenfalls Ereignis-/Gültigkeitsdaten, Verfügbarkeit, Archiv-URL sowie lokale Kopie/Hash), SourceExcerpt eine genaue Fundstelle in genau einer SourceVersion. ActionOrDevelopment erhält ActionRevisions. Korrekturen erzeugen neue Revisionen mit Grund; alte Referenzen bleiben auflösbar. Hashes belegen Dateiidentität, nicht Inhaltwahrheit.

**Bewertungs-Snapshots:** CaseRevision ist ein unveränderliches Manifest der konkreten PromiseRevision, CriterionRevisions, ActionRevisions, SourceVersions/Excerpts und geprüften EvidenceLinks. Jede CaseEvaluation referenziert genau einen Snapshot, Bewertungsstichtag und MethodologyVersion. CriterionEvaluations referenzieren jeweils genau die verwendete CriterionRevision und halten Ergebnis, Begründung, Evidenzlinks, Gegenbelege, Evidenzsicherheit, Unsicherheiten und menschlichen Prüfstatus fest. Neue Evidenz oder eine neue Kriterienrevision überschreibt nie ein früheres Urteil; abhängige Evaluationen werden `reviewRequired` markiert und können als neuer Snapshot neu bewertet werden.

**Beteiligung und Evidenz:** ActionParticipation verknüpft ActionRevision und Actor mit Rolle, Beteiligungsart und gegebenenfalls Belegen der Zurechnung. Eigene Handlung, institutionelles Ergebnis, politische Unterstützung und behauptete kausale Verantwortung bleiben unterscheidbar. EvidenceLink referenziert genau eine CriterionRevision, mindestens einen geprüften SourceExcerpt, optional eine ActionRevision, Beziehung (`supports`, `contradicts`, `contextualizes`), Direktheit (`direct`, `indirect`), fachliche Begründung und Prüfstatus. Eine Handlung ohne Fundstelle und ein ResearchTask sind keine Evidenz.

**ResearchTasks, Verlauf und Skript:** ResearchTask speichert Suchbedarf/-versuch und technische Blockaden ohne Evidenzstatus. AuditEntry ist append-only. Spätere ScriptDrafts verweisen auf konkrete CaseEvaluation-Snapshots; Aussagen sind typisiert und freigegebene Tatsachensätze besitzen Fundstellenreferenzen. KI-Herkunft ist von menschlicher Sachprüfung und Freigabe getrennt.

**Getrennte Zustandsachsen:** Herkunft (manuell/KI/importiert), Verifikation einzelner Angaben/Fundstellen, Case-Arbeitsfortschritt und Freigabe einer Evaluation sind verschiedene Felder. Eine KI-Extraktion beginnt ungeprüft. Unbekannt/nicht anwendbar braucht einen Grund und ist kein Status. Zulässige Case-Folge: `candidate → documented → verified → readyForEvaluation → evaluated → approved`. SourceExcerpt: `unverified → verified → superseded` (oder `rejected`). Evaluation: `draft → needsReview → approved → reviewRequired → superseded`. Korrekturen führen über neue Revisionen und einen protokollierten Statuswechsel, nie durch Umschreiben einer freigegebenen Bewertung. Die Case-Folge beschreibt monoton erreichte Workflow-Reife: `approved` verlangt eine historisch menschlich freigegebene Evaluation mit erhaltenem Reviewer und Freigabezeitpunkt, auch wenn sie inzwischen `reviewRequired` ist. Aktueller Reviewbedarf wird separat aus Evaluationen und ihren Revisionsbezügen abgeleitet, nicht als zweiter gespeicherter Workflowstatus. Neue Evidenz setzt den Case nicht zurück. Eine neue menschliche Freigabe benötigt eine neue Evaluation, bei geänderter Evidenz einen neuen Snapshot; Kategorie, Begründung, damalige Revisionen, Methodik und ursprüngliche Freigabe der alten Bewertung bleiben erhalten. Nur eine ausdrücklich freigegebene Ersatzbewertung kann den offenen Review auflösen.

**Datumsrollen:** Aussagezeit, Ereigniszeit/-zeitraum, Quellenveröffentlichung, Abruf, Gültigkeitsintervall, Bewertungsstichtag, Erstellung, Prüfung und Freigabe sind getrennte, präzise Datumswerte. Die Stichtagsprüfung bezieht sich auf relevante Ereignis-/Gültigkeitsdaten. Eine später veröffentlichte Quelle kann ein Ereignis vor dem Stichtag dokumentieren; Publikationsdatum oder Abrufdatum disqualifizieren sie nicht automatisch. Rückblickende Dokumentation und unsichere Ereignisdatierung werden kenntlich gemacht und menschlich eingeordnet.

**Löschung:** Referenzierte Revisionen, Fundstellen und freigegebene Bewertungen werden nicht kaskadierend gelöscht. Referenzierte Akteure/Quellen werden archiviert; lokale Dateien werden getrennt verwaltet. Eine explizite Löschung des gesamten Cases muss Auswirkungen auf lokale Kopien nachvollziehbar behandeln.

## 3.1 Technische Invarianten

Formale Referenzen und Pflichtzustände kann die Domain-Logik prüfen; Aussagekraft und Authentizität bleiben menschliche Prüfungen. Die vollständige Liste einschließlich Erzwingbarkeitsgrad steht in `docs/domain-model.md`.

- Verifiziertes Originalzitat → konkreter SourceExcerpt → konkrete SourceVersion; kein Excerpt ohne SourceVersion.
- Jeder EvidenceLink referenziert genau eine CriterionRevision und mindestens einen verifizierten Fundstellenbeleg; ResearchTask und fundstellenlose Handlung sind ausgeschlossen.
- Keine freigegebene Evaluation ohne menschlichen Reviewer. KI ist kein Reviewer.
- „Nicht erfüllt“ verlangt belastbare, geprüfte Evidenz; eine leere Evidenzmenge reicht nie. „Gegenteilig gehandelt“ verlangt widersprechenden, geprüften Beleg. „Nicht überprüfbar“ verlangt strukturierten Grund und Begründung.
- Geänderte bestätigte Kriterien verlangen neue CriterionRevision, Änderungsgrund und menschliche Bestätigung vor Evaluation; abhängige Evaluationen werden überprüfungsbedürftig.
- Historische CaseRevisionen und Evaluationen werden nicht überschrieben. Ereignis-/Gültigkeitszeit ist gegen den Bewertungsstichtag zu prüfen, nicht pauschal das Publikationsdatum.
- Jeder freigegebene Script-Tatsachensatz verweist auf mindestens eine geprüfte Fundstelle.
- KI-Ausgaben können ungeprüfte Eingabe sein, niemals Beleg oder automatische politische Gesamtbewertung.

## 4. Neutrale Bewertungsmethodik

### Prüfverfahren

1. **Aussage sichern:** Originalzitat, Kontext und Sprecherzuordnung prüfen; Aussage, Prognose und Versprechen unterscheiden.
2. **Prüfrahmen festlegen:** Kriterien, Kernbestandteile, Bedingungen, Frist, Zuständigkeit und Ausgangslage vor der Einstufung dokumentieren. Änderungen bleiben begründet und versioniert.
3. **Evidenz prüfen:** Möglichst Originaldokumente verwenden, z. B. Parlamentsprotokolle, namentliche Abstimmungen, Gesetzestexte, amtliche Umsetzungsdaten oder archivierte Parteiaussagen. Presseberichte unterstützen die Einordnung. Mehrere Berichte derselben Ursprungsquelle zählen nicht als unabhängige Bestätigung.
4. **Vergleichen:** Für jedes Kriterium Erfüllungsgrad, Gegenbelege, Verfahrensstand und verbleibende Lücken erfassen. Bedingungen dürfen nicht nachträglich erfunden werden.
5. **Menschlich einstufen:** Kategorie und Evidenzsicherheit getrennt bestimmen, Begründung und Einschränkungen prüfen, dann freigeben.

### Kategorien und Entscheidungsregeln

| Kategorie | Voraussetzung |
| --- | --- |
| **Erfüllt** | Alle wesentlichen zugesagten Kriterien einschließlich Umfang und Frist sind belegt erfüllt. |
| **Überwiegend erfüllt** | Alle Kernkriterien sind erfüllt; verbleibende Abweichungen sind nach vorab festgelegtem Maßstab untergeordnet und ausdrücklich benannt. |
| **Teilweise erfüllt** | Ein substanzieller Teil ist belegt erfüllt, aber mindestens ein wesentlicher Teil fehlt oder ist nur teilweise umgesetzt; der Kern ist nicht nachweislich ins Gegenteil verkehrt. |
| **Nicht erfüllt** | Die relevante Frist ist abgelaufen, Bedingungen waren anwendbar, und belastbare Belege zeigen, dass der zugesagte Kern nicht erreicht wurde. Bloß fehlende Suchtreffer reichen nicht. |
| **Gegenteilig gehandelt** | Eine klar zurechenbare, dokumentierte Handlung widerspricht dem zugesagten Kern direkt. Die konkrete entgegengesetzte Handlung wird benannt; eine bloße Nichterfüllung genügt nicht. |
| **Nicht überprüfbar** | Keine verantwortbare Gesamteinstufung möglich, etwa wegen unklarer Aussage, offener Frist, nicht eingetretener Bedingung, fehlender Belege, ungeklärter Zurechnung oder entscheidender Quellenkonflikte. Grund obligatorisch. |

Zuerst wird die Prüfbarkeit beurteilt. Bei ausreichender Evidenz hat ein direkter Widerspruch zum Kern Vorrang; bei gemischten Befunden werden erfüllte Teilaspekte zusätzlich sichtbar gemacht. Sonst folgt die Einstufung nach den Erfüllungsregeln. Wenn unklare Teile die Gesamtkategorie ändern könnten, lautet das Gesamturteil „nicht überprüfbar“; sichere Teilbefunde bleiben sichtbar.

Bei noch offener Frist ist ein abschließendes negatives Erfüllungsurteil unzulässig. Bereits vollständig erreichte Ziele oder eine klar dokumentierte gegenteilige Handlung können als Befund zum Stichtag bewertet werden; der vorläufige Charakter und mögliche spätere Änderungen müssen sichtbar bleiben.

**Keine universelle Prozentpunktzahl:** Die Bedeutung einzelner Bestandteile unterscheidet sich je Versprechen. Gewichte und Materialität werden vor der Bewertung begründet. Für natürlich quantitative Ziele kann der belegte Erfüllungsanteil zusätzlich angezeigt werden, ersetzt aber keine fachliche Einordnung von Kern, Umfang und Frist.

**Evidenzsicherheit:** hoch = direkte, kontextgeprüfte Belege ohne entscheidenden offenen Konflikt; mittel = ausreichend belegbarer Befund mit benannten indirekten Belegen oder begrenzten Lücken; niedrig = entscheidende Lücken oder Konflikte. Niedrige Sicherheit erlaubt kein abschließendes negatives Gesamturteil. Sicherheit ist keine mathematische Wahrheitswahrscheinlichkeit.

**Zurechnung und Kontext:** Opposition, Koalitionskompromisse, Zuständigkeiten und externe Entwicklungen werden dokumentiert. Ergebnis, eigenes Handeln und kausale Verantwortung bleiben getrennt. Eine Gegenstimme kann ein versprochenes Abstimmungsverhalten widerlegen, beweist aber nicht allein Verantwortung für ein Gesamtergebnis. Eine geänderte Position wird zeitlich dokumentiert und ersetzt das frühere Versprechen nicht rückwirkend.

Spätere Priorisierung berücksichtigt Belegstärke, öffentliche Relevanz, Größe und Aktualität der Diskrepanz sowie Fälle mit erfüllten Zusagen. Auswahlgründe werden protokolliert; aus selektiv ausgewählten Fällen werden keine pauschalen Partei-Rankings abgeleitet.

## 5. KI-Grenzen und redaktionelle Freigabe

KI darf Auszüge strukturieren, mögliche Kriterien und Gegenbelege vorschlagen, Material zusammenfassen und Skripte entwerfen. Ihre Ausgabe ist ein Vorschlag mit Herkunft und Prüfstatus.

Menschliche Entscheidungen sind zwingend bei:

- Authentizität, Vollständigkeit und Kontext von Originalaussagen; OCR- und Transkriptionsfehlern.
- Interpretation mehrdeutiger Zusagen, Kriteriengewichtung, Zuständigkeit und Zurechnung.
- Auflösung widersprechender Quellen, Beurteilung fehlender Handlungen und kausaler Aussagen.
- Endgültiger Bewertung, Umgang mit Unsicherheit und Tatsachenbehauptungen im Skript.
- Persönlichkeitsrechten, irreführender Zuspitzung und Veröffentlichung.

Im MVP kann dieselbe Person prüfen und freigeben; die Schritte bleiben getrennt und protokolliert. KI darf keine erfundenen Quellen ergänzen, eigene Texte als Belege verwenden oder Motive wie „bewusste Lüge“ aus einer Diskrepanz ableiten. Ein pointierter Einstieg darf wesentliche Einschränkungen nicht verschweigen. Entwürfe bleiben deutlich als ungeprüft markiert; ungeklärte Kernaussagen blockieren die redaktionelle Freigabe.

## 6. Realistischer MVP und Abnahmekriterien

**Zwingend für MVP:** lokale Fallbearbeitung, manuelle Quellenaufnahme, Kriterien und Evidenzbeziehungen, neutrale Bewertung mit menschlicher Freigabe, ein austauschbarer KI-Anbieter für Skriptentwürfe, Satz-für-Satz-Quellenprüfung, versioniertes Prüfprotokoll und Export. Keine Konten, Cloud-Synchronisierung oder automatisierte Bewertung oder Medienerzeugung nötig. Automatische Versprechenssuche ist seit Phase 5.1 Teil des Einstiegs, ohne diesen manuellen Abnahmeweg zu ersetzen.

Der Export enthält ausschließlich ein menschlich freigegebenes Skript mit einer Zielzeit von ungefähr 30–60 Sekunden, eine Szenengrundlage mit noch festzulegenden Visualhinweisen, eine lesbare Quellenliste mit Fundstellen und einen maschinenlesbaren Fallbericht samt vollständigem Fallarchiv (JSON). Ein Quellenblatt ergänzt kurze Quellenkennungen im Skript. Noch kein fertiges Video. Zieldauer wird geschätzt; tatsächliche Sprechdauer ist erst mit Voiceover verifizierbar.

Phase 4.3 implementiert dafür ein offline erzeugtes Verzeichnis-Paket mit Formatversion 1 und geprüftem Wiederimport (`docs/export-format-v1.md`). Der Publication Gate verlangt eine aktuell approved CaseEvaluation und ein Domain-valides approved Script mit menschlichen Satzprüfungen; ReviewRequired blockiert. Methodology-Hash und Datei-SHA-256 werden geprüft, IDs/Historie bleiben erhalten, Kollisionen werden nicht gemerged. Die Basis df027bafca4da0d84cebe90f113f349344f93966 ist extern mit 455 erfolgreichen Tests und nativem arm64-Build bestätigt. Phase 4.4 ergänzt synthetische Cross-Layer-Abnahmetests und die Vorlagen `docs/mvp-acceptance.md` / `docs/mvp-real-case-acceptance.md`; der neue CI-Nachweis und die menschliche reale Fallabnahme bleiben separat erforderlich.

Der MVP ist abgenommen, wenn ein einzelner echter Fall:

1. Mit Originalversprechen, Datum, Kontext, klaren Kriterien und Stichtag erfasst ist.
2. Spätere Handlungen, Gegenbelege bzw. dokumentierte Suche danach und genaue Fundstellen enthält.
3. Nach denselben veröffentlichten Regeln bewertet und menschlich geprüft wurde.
4. Einen überprüften KI-Skriptentwurf besitzt, dessen Tatsachensätze jeweils passende Quellen haben.
5. Als vollständiges Redaktionspaket exportiert, erneut geöffnet und ohne Datenverlust bearbeitet werden kann.

Zusätzlich müssen ein Fall mit unzureichender Evidenz korrekt als „nicht überprüfbar“ behandelt und unbelegte KI-Aussagen bei der Freigabe aufgehalten werden. Fehlender API-Zugang oder Netzwerkausfall darf keine Falldaten verlieren; manuelle Bearbeitung und Export bleiben möglich. Methodiktests verwenden anonymisierte, vergleichbare Fälle und prüfen, dass ein Wechsel der Parteiidentität die Bewertung nicht ändert.

## 7. Einfache macOS-Architektur

**Empfehlung:** native SwiftUI-Anwendung, zunächst macOS 14 oder neuer, mit einer einzigen lokalen Anwendung und ohne eigenen Server. Domain, Persistenz und UI sind implementiert; die neue Recherche bleibt ein getrenntes Modul.

- **UI:** Fallformular, Quellenablage, Vergleichsansicht, Bewertungsprüfung und Skripteditor mit Quellenmarkierungen.
- **Fachlogik:** eigenständige Swift-Module für Kriterien, Validierung, Freigaben und Export; unabhängig von UI und KI-Anbieter testbar.
- **Persistenz:** SwiftData bildet das in `docs/domain-model.md` definierte Domain Model ab; fachliche Revisionen und CaseEvaluation-Snapshots bleiben unveränderlich. Importierte Dokumente liegen separat im Application-Support-Verzeichnis; SourceVersion speichert Dateireferenz/Hash. Stabile IDs, Schema-Migrationen und versionierte Export-/Backup-Pakete vorsehen.
- **KI-Anbindung:** ein schmaler Anbieteradapter über URLSession, direkte HTTPS-Anfragen, strukturierte Antwortformate und feste Quellen-IDs. Antworten auf vorhandene IDs prüfen; keine automatische Freigabe durch das Modell.
- **Zugangsdaten:** für den aktuellen Entwicklungsstand ausschließlich OPENAI_API_KEY im lokalen Prozess; macOS-Schlüsselbund ist ein späteres Distributionsziel; keine Schlüssel in Projektdateien, Exporten oder Logs. Vor Übertragung wird ersichtlich, welche Auszüge an den Anbieter gehen. Nur notwendiges Quellenmaterial übertragen; Nutzungs- und Datenschutzbedingungen beachten.
- **Dateien/Netzwerk:** macOS-Sandbox mit gezieltem Dateiimport/-export und ausgehender Netzwerkberechtigung. Importierte Dokumente als Daten behandeln; keinen darin enthaltenen Anweisungen folgen.

Die Cloud-Umgebung kann Dokumentation und plattformunabhängige Arbeit unterstützen. Native Builds, UI-Tests, Signierung und Medienfunktionen benötigen einen Mac mit passender Xcode-Version. Ein Linux-Cloud-Setup allein validiert die macOS-Anwendung nicht. Im MVP genügt lokale Ausführung auf dem Entwicklungs-Mac; öffentliche Distribution folgt später.

## 8. Ausbaustufen

| Stufe | Umfang |
| --- | --- |
| **MVP — umgesetzt / Phase 5.1** | Ein vollständiger Fall bis zum geprüften Skript- und Quellenexport; lokale Speicherung und Wiederherstellung; zusätzlich automatische Versprechenssuche, ungeprüfte Inbox und Deep-Research-Dossiers mit Drafts. |
| **Nächste Phasen — geplant** | Kompakte Review-Queue für vorhandene Research-Drafts und Übernahme in echte menschlich freigegebene Bewertung; anschließend Skript, Storyboard, TTS, Untertitel und Video. |
| **Später — möglich** | Erweiterte Quellenabdeckung und überwachte Aktualisierung von Fällen, weitere KI-Anbieter, aufwendigere Visuals, Teamfunktionen und optionale Synchronisierung. |

Automatische Veröffentlichungen und pauschale Ehrlichkeits-Rankings sind kein vorgesehenes Produktziel. Videoerzeugung beginnt erst, wenn der einzelne Faktencheck nachvollziehbar und reproduzierbar funktioniert.

## 9. Risiken und Gegenmaßnahmen

| Bereich | Risiko | Gegenmaßnahme |
| --- | --- | --- |
| Methodik | Selektionsbias, verschobene Kriterien, Cherry-Picking | Auswahlgründe, vorab definierte Kriterien, Gegenbelegsuche und Parteiidentität-unabhängige Tests. |
| Methodik | Verwechslung von Vorschlag, Beschluss, Umsetzung und Wirkung | Expliziter Verfahrensstatus; eigene Belege je Stufe. |
| Methodik | Scheingenauigkeit oder unberechtigte Zurechnung | Keine pauschalen Scores; Ergebnis, Handeln, Verantwortung und Unsicherheit getrennt darstellen. |
| Journalismus | Kontextverlust durch kurze, zugespitzte Videos | Einschränkungen im Skript, Quellenblatt, menschliche Satzprüfung; nötigenfalls Fall nicht für Kurzformat freigeben. |
| Journalismus/Recht | Rufschädigung, fehlerhafte Zitate, Urheber- und Persönlichkeitsrechte | Keine unbelegten Motivunterstellungen; korrekte Zitate, Nutzungsrechte prüfen, bei heiklen Veröffentlichungen fachliche Prüfung. |
| Journalismus | Veraltete Beurteilungen und fehlende Korrekturen | Stichtag sichtbar, Revisionen und Korrekturhinweise; neue Belege lösen erneute Prüfung aus. |
| Technik | Halluzinationen und Prompt-Injection in Quellen | Quellen als untrusted Daten, feste Quellen-IDs, strukturierte Ausgaben, keine Werkzeuge mit Veröffentlichungsrechten, menschliche Freigabe. |
| Technik | Tote Links, veränderte Dokumente, OCR-Fehler | Fundstellen, Abrufdatum, zulässige lokale Kopien und Hashes; Kontextprüfung am Original. |
| Technik | API-Ausfälle, Kosten, Datenabfluss | Begrenzte Anfragen, sichtbare Datenübertragung, Anbieteradapter, lokale Bearbeitung und sichere Schlüsselablage. |
| Technik | Datenverlust oder Plattformgrenzen | Export/Backup, Migrationsprüfungen; echte macOS-Validierung auf einem Mac. |

## 10. Festgelegter Rahmen für den nächsten Schritt

Zunächst einen klar formulierten, zeitlich überprüfbaren Einzelfall mit zugänglichen Originalquellen auswählen und die Methodik daran manuell erproben. Danach Datenfelder und Freigaberegeln anhand des Falls präzisieren. Es gibt noch keine Entscheidung für einen KI-Anbieter oder einen konkreten politischen Fall; diese Wahl blockiert die Produktspezifikation nicht. Anwendungscode und Videoautomatisierung beginnen erst in einer folgenden Phase.
