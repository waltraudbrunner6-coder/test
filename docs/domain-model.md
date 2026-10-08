# Domain Model: Politische Versprechen und Faktenchecks

Status: Spezifikationsentwurf zur Implementierung · Version 1 · 7. Oktober 2026

Dieses Modell beschreibt eine lokale macOS-Anwendung für zunächst eine Person und einen Fall mit einem Versprechen. Es setzt weder einen Server noch Microservices voraus. SwiftData ist die geplante Persistenz, nicht Teil dieses Dokuments. Alle IDs sind lokal erzeugte, stabile UUIDs. Fachlich abgeschlossene Revisionen und Bewertungen sind append-only; Korrekturen erzeugen neue Revisionen. Zeitangaben speichern absolute Zeit mit Zeitzone, wo relevant; Kalenderdaten speichern Präzision und Kalender-/Zeitzonenbezug.

## 1. Gemeinsame Begriffe und Regeln

### 1.1 Unbekanntheit, Herkunft, Verifikation und Freigabe

Diese Bedeutungen sind getrennt zu speichern:

- **Feldwert:** bekannt, unbekannt (mit Grund), oder nicht anwendbar (mit Grund). Ein leerer String ist kein Unbekanntheitsstatus.
- **Herkunft:** manuell eingegeben oder KI-extrahiert; KI-Metadaten werden protokolliert. Herkunft sagt nichts über Richtigkeit.
- **Sachprüfung:** ungeprüft, verifiziert oder verworfen; Verifikation benennt eine lokale ReviewerIdentity, Zeitpunkt und gegebenenfalls Fundstellen. „Verifiziert“ bedeutet redaktionell auf Plausibilität und Beleg geprüft, nicht metaphysische Gewissheit.
- **Arbeitsfortschritt:** Case-Workflowstatus (Abschnitt 8); er ist weder Evidenzsicherheit noch Verifikationsstatus eines Einzelfeldes.
- **Freigabe:** eigener menschlicher Akt für eine Evaluation oder Skriptfassung. Sachverifikation allein ist keine Freigabe.
- **Überholt:** bezeichnet eine ersetzte Revision/einen ersetzten Beleg und ist kein Urteil über dessen frühere Richtigkeit.

KI-Ergebnis kann als ungeprüfte Eingabe gespeichert werden, wird aber nie zu Quelle, Fundstelle oder Evidenz allein dadurch, dass es gespeichert oder wiederholt wird.

### 1.2 Datumsmodell

`AssertedValue<T>` hält für ein einzelnes sachliches Feld den Wert (oder explizit unbekannt/nicht anwendbar mit Grund), Herkunft, FactVerificationState und dazugehörige Excerpt-IDs. Dadurch kann etwa das Aussagedatum ungeprüft bleiben, während ein Originalzitat verifiziert ist. `DatedValue` ist ein Feldtyp darin und besteht aus Wert oder explizitem Unknown-Status, Rolle, Präzision (Zeitpunkt, Tag, Monat, Jahr, Intervall), optionaler Zeitzone und Begründung. `DateInterval` hat bekannte oder offene Anfangs-/Endgrenzen, Präzision und Konvention; für Gültigkeit gilt Ende exklusiv, wenn die Quelle nichts anderes festlegt.

Datumsrollen sind eigenständige Felder statt eines generischen `date`:

| Rolle | Verwendung | Relevanz für Stichtag |
| --- | --- | --- |
| Aussagezeitpunkt | PromiseRevision | Ordnet Versprechen zeitlich ein; kein Beleg für spätere Erfüllung. |
| Ereigniszeitpunkt/-zeitraum | ActionRevision | Maßgeblich dafür, ob eine Handlung bis zum Bewertungsstichtag eingetreten ist. |
| Veröffentlichung | SourceVersion | Beschreibt wann die Fassung publiziert wurde; schließt spätere historische Dokumentation nicht aus. |
| Abruf | SourceVersion | Provenienz/Recherche, nicht Ereignisdatierung. |
| Gültigkeitsintervall | SourceVersion, ActionRevision oder sachlicher Tarif-/Regelinhalt | Gegen sachlich relevanten Zeitraum und Stichtag prüfen. |
| Erstellung/Änderung | alle veränderlichen Aggregate bzw. Revisionen | Auditierbarkeit, keine politische Ereigniszeit. |
| Bewertungsstichtag | CaseEvaluation | Grenze der bewerteten Sachlage. |
| Sachprüfung/Freigabe | Prüf-/Freigabemetadata | Zeitpunkt menschlicher Arbeit, nicht Ereigniszeit. |

Eine 2025 publizierte SourceVersion kann ein Ereignis von 2021 belegen: Für Zulässigkeit zählt der belegte Ereigniszeitpunkt bzw. relevante Gültigkeitszeitraum, nicht pauschal ihr Publikationsdatum. Rückblickende Dokumentation wird in der Evaluation als solche kenntlich gemacht. Ist die Ereigniszeit nicht hinreichend datiert oder auf den Stichtag beziehbar, entsteht eine menschlich zu prüfende Unsicherheit. Software kann offensichtliche Zeitkonflikte markieren, aber historische Aussagekraft nicht selbst entscheiden.

### 1.3 Statusachsen

Keine einzelne Statusvariable soll Datenherkunft, Faktentreue, Workflow und Freigabe vermengen. Das Modell verwendet:

1. **FactVerificationState** pro behauptungsrelevantem Revision-/Fundstelleninhalt: `unreviewed`, `verified`, `rejected`, `superseded`. Herkunft (`humanEntered`, `aiExtracted`, `imported`) bleibt separater Wert. KI-Extraktion bleibt `unreviewed`, bis ein Mensch prüft.
2. **CaseWorkflowState** für den Gesamtfortschritt: `candidate`, `documented`, `verified`, `readyForEvaluation`, `evaluated`, `approved`. Bedeutung und Übergänge siehe Abschnitt 8. `CaseWorkflowState` beschreibt monoton erreichte Workflow-Reife. `approved` bedeutet, dass mindestens eine historisch menschlich freigegebene CaseEvaluation existiert; es behauptet weder absolute Faktensicherheit noch aktuelle Reviewfreiheit. Aktueller Reviewbedarf wird separat aus EvaluationStatus und den verwendeten Revisionen abgeleitet, nicht als zweiter Workflowstatus gespeichert.
3. **CriterionRevisionState** (`draft`, `confirmed`, `superseded`) für den Freeze der Prüfmesslatte; getrennt von FactVerificationState. Eine bestätigte Revision wird nie editiert.
4. **EvaluationStatus** für einen konkreten Snapshot: `draft`, `needsReview`, `approved`, `reviewRequired`, `superseded`.
5. **ExcerptVerificationState** für eine genaue SourceExcerpt-Fundstelle: `unverified`, `verified`, `rejected`, `superseded`.
6. **ScriptStatus** für spätere Entwürfe: `draft`, `needsReview`, `approved`, `superseded`.

Diese Achsen sind absichtlich klein und spezifisch. Feldwerte bleiben zusätzlich explizit unbekannt/nicht anwendbar; diese Zustände sind keine Reviewstatus.

## 2. Objekte und Verantwortlichkeiten

Feldtypen sind konzeptionell: `ID`, Text, Datumstyp aus 1.2, Enum, Zahl, URL, lokaler Datei-Referenz, Menge von IDs. „Pflicht“ bezeichnet fachliche Pflicht bei entsprechender Freigabe, nicht, dass ein unvollständiger Kandidat nicht gespeichert werden kann.

### 2.1 ReviewerIdentity

- **Zweck:** Lokale menschliche Person, die Information verifiziert oder redaktionell freigibt; getrennt von politischen Actor-Datensätzen.
- **Felder:** stabile ID, Anzeigename, feste Art `human`; optional lokale Notiz. Kein Passwort oder Konto erforderlich.
- **Identität/Versionierung:** ein lokaler Datensatz, bei Namensänderung AuditEntry; keine fachliche Revision.
- **Beziehungen:** Referenz aus allen menschlichen Verifikations-, Prüf- und Freigabefeldern.
- **Löschen:** archivieren, sobald historisch referenziert.
- **Invarianten:** nur `human` kann Reviewer/Freigebender sein. KI-Provenienz wird in Herkunfts-/Auditfeldern geführt und kann diese Referenz nicht setzen.

### 2.2 Case — Fallaggregate

- **Zweck:** Lokaler Bearbeitungs- und Navigationscontainer für genau ein politisches Versprechen und dessen Prüfungen. In diesem MVP genau ein Promise pro Case; weitere unabhängige Versprechen erhalten eigene Cases.
- **Felder:** ID (Pflicht, stabil), Titel/Arbeitstitel, `workflowState`, Erstellungs-/Änderungszeit, aktuelle `PromiseRevisionID`, aktuelle Revisionen der Kriterien und Handlungen, aktuelle ResearchTasks, `CaseRevision`-Manifeste.
- **Identität/Versionierung:** veränderliche Identität/Arbeitskopf. Keine Inhaltsrevision durch Kopie des kompletten Case bei jeder Änderung; fachlich relevante Auswertungsgrundlage wird als unveränderliches CaseRevision-Manifest eingefroren.
- **Beziehungen:** genau ein Promise; null oder mehr EvaluationCriteria; null oder mehr ActionOrDevelopment; Source-Datensätze über Referenzen; null oder mehr ResearchTasks, AuditEntries und CaseRevisions; null oder mehr CaseEvaluations.
- **Löschen:** Case-Löschung darf nicht still Historie oder externe Originale beseitigen. Lokales Löschen verlangt Bestätigung und erhält entsprechend Datenschutz-/Aufbewahrungsentscheidung einen Export/Backup; externe Dateien werden nur gelöscht, wenn sie von der App verwaltet werden.
- **Invarianten:** `approved` setzt mindestens eine historisch menschlich freigegebene CaseEvaluation mit erhaltenem Reviewer und Freigabezeitpunkt voraus, auch wenn deren operativer Status inzwischen `reviewRequired` oder `superseded` ist. Workflow-Reife springt nicht zurück; neue Arbeitsrevisionen dürfen die historischen Meilensteine nicht entwerten. Ein Kandidat darf unvollständig sein. IDs/Referenzen bleiben stabil.

### 2.3 Actor

- **Zweck:** Partei, Person, Fraktion, Regierung, Behörde oder sonstiger institutioneller Akteur.
- **Felder:** ID, Name, Typ, optionale Beschreibung; jede Zugehörigkeit/Rolle hat ein eigenes zeitliches Intervall und ihren eigenen Beleg-/Prüfstatus.
- **Versionierung:** stabile, mutierbare Identität; relevante Namens-/Rollenänderungen als AuditEntry. Historische Evaluation referenziert unveränderliche Action-/Promise-Revisionen mit zeitlich festgehaltenem Akteur und Rolle; spätere Änderungen dürfen den Snapshot nicht umschreiben.
- **Beziehungen:** PromiseRevision als Sprecher und ggf. Parteizugehörigkeit; ActionParticipation als Beteiligung; AuditEntry.
- **Löschen:** keine kaskadierende Löschung aus fachlichen Datensätzen. Referenzierte Akteure werden archiviert/inaktiv gesetzt.
- **Invarianten:** Parteiidentität ist kein Bewertungsmerkmal. Zugehörigkeit zum Aussagezeitpunkt darf nicht aus heutiger Zugehörigkeit abgeleitet werden.

**ActorAffiliation (abhängiger Datensatz)**

- **Zweck:** Zeitgebundene Rolle oder Zugehörigkeit eines Actor, etwa Partei- oder Amtszugehörigkeit.
- **Felder:** stabile ID, ActorID, zugeordneter ActorID (z. B. Partei), Rolle/Beziehung, Gültigkeitsintervall, Verifikationsstatus, SourceExcerptIDs, ReviewerIdentity/Prüfdatum.
- **Versionierung:** Inhaltliche Korrektur als neuer Datensatz/Revision plus AuditEntry; frühere Zugehörigkeit bleibt historisch nachvollziehbar.
- **Beziehungen:** gehört genau zu einem Actor; verweist optional auf einen anderen Actor und auf Belegstellen.
- **Löschen:** archivieren, wenn referenziert.
- **Invarianten:** keine zeitliche Zugehörigkeit ohne definierten oder explizit unbekannten Zeitraum; heutige Zugehörigkeit beweist keine frühere.

### 2.4 Promise

- **Zweck:** Stabile Identität des einzelnen zu prüfenden Versprechens, auch während sich Erfassung und Interpretation entwickeln.
- **Felder:** ID, CaseID, Erstellungszeit, aktuelle PromiseRevisionID.
- **Versionierung:** Identität stabil; fachlicher Inhalt liegt ausschließlich in unveränderlichen PromiseRevisions.
- **Beziehungen:** genau ein Case; eine oder mehr PromiseRevisions; Kriterien referenzieren Promise.
- **Löschen:** nur gemeinsam mit explizitem Case-Löschvorgang, keine automatische Löschung historischer Evaluationsreferenzen.
- **Invarianten:** nie mehr als ein aktives Versprechen im MVP-Case.

### 2.5 PromiseRevision

- **Zweck:** Unveränderlicher Stand des Wortlauts, Kontextes und der prüfbaren These eines Promise; auch ein ungeprüfter Entwurf erhält eine eigene Revision.
- **Felder:** ID, PromiseID, Revisionsnummer, Zitattext oder Unknown mit Grund, separate Prüfthese, Aussagezeitpunkt samt Präzision/Status, Kontext, Zielgruppe, Originalbedingungen, Zuständigkeit als zu prüfende Hypothese, Themen; SprecherActorID und ParteiActorID zum Aussagezeitpunkt oder explizit unbekannt; Änderungsgrund, erstellt von/Datum. Jedes behauptungsrelevante Feld, einschließlich Zitat, Datum und Akteur, ist als `AssertedValue<T>` mit eigener Herkunft, Verifikationslage und Belegreferenzen erfasst.
- **Versionierung:** von Erstellung an unveränderlich. Korrektur, Kontext- oder Prüfthesenänderung erzeugt eine neue Revision; Vorrevision bleibt erhalten und wird bei Ersatz `superseded`.
- **Beziehungen:** genau ein Promise; Sprecher/Akteure; mindestens eine verifizierte SourceExcerpt-Fundstelle für einen verifizierten Originalwortlaut; Quellen können mehrfach referenziert sein.
- **Löschen:** keine physische Löschung nach Zitierung in CaseRevision/Evaluation; zurückgezogene Version als superseded mit Grund markieren.
- **Invarianten:** Originalzitat ist nie KI-Paraphrase. Verifiziertes Originalzitat muss auf konkrete SourceExcerptID → SourceVersionID zeigen. Ungeprüfte KI-Extraktion bleibt nicht verifiziert.

### 2.6 EvaluationCriterion und CriterionRevision

- **EvaluationCriterion Zweck:** Stabile Identität eines einzelnen Prüfkriteriums im Promise; ID, PromiseID, aktuelle CriterionRevisionID, Erstellungsdatum. Kriterien sind nicht direkt editierbar; ihr Inhalt liegt in Revisionen.
- **CriterionRevision Zweck:** Exakte, vor der Bewertung festgelegte Prüfmesslatte.
- **Felder:** ID (stabile Revisions-ID), CriterionID, Revisionsnummer, Zielzustand, Zielgruppe/Umfang, Ausgangslage (Wert oder unbekannt mit Grund), Frist/Messzeitraum, notwendige Bedingungen, Kernkriterium ja/nein, Materialitätsregel als Text oder strukturierte Erklärung, optionales Gewicht nur mit Begründung, Änderungsgrund, Autor und Datum, menschlicher Bestätiger und Bestätigungsdatum, CriterionRevisionState.
- **Versionierung:** unveränderlich; jede inhaltliche Änderung erzeugt eine neue Revision. Bestätigung friert die Messlatte für spätere Bewertung ein. Aussagen über Kern und Materialität bestätigt ein Mensch vor `readyForEvaluation`.
- **Beziehungen:** genau ein EvaluationCriterion und Promise; eine oder mehr CriterionRevisions; EvidenceLinks und CriterionEvaluations referenzieren genau eine CriterionRevision.
- **Löschen:** nur solange unbenutzt; danach archivieren/als überholt markieren. Keine kaskadierende Löschung aus Promise.
- **Invarianten:** `readyForEvaluation` verlangt bestätigte Revisionen aller aktiven Kriterien. Eine Bewertung listet die exakt verwendeten Revisionen auf. Änderung nach Bestätigung verlangt Grund und neue Revision und markiert abhängige Evaluationen als `reviewRequired`.

### 2.7 Source, SourceVersion und SourceExcerpt

#### Source

- **Zweck:** Identität eines logischen Quelldokuments oder Source-Endpoints, nicht einer unveränderlichen Textfassung.
- **Felder:** ID, ursprüngliche/kanonische URL oder Dokumentkennung (mindestens eine davon), Erstellungsdatum, optionale `originSourceID` auf die bekannte Ursprungsquelle für abhängige Mehrfachveröffentlichungen.
- **Versionierung:** Identität/Metadaten veränderlich mit AuditEntry. Inhaltsänderungen werden nie durch Änderung von Source repräsentiert.
- **Beziehungen:** eine oder mehr SourceVersions.
- **Löschen:** referenzierte Source wird archiviert, nicht kaskadierend gelöscht.
- **Invariante:** URL allein ist keine zitierbare Quelle.

#### SourceVersion

- **Zweck:** Beobachtete, unveränderliche Fassung eines Source-Inhalts zu einem Abrufzeitpunkt.
- **Felder:** ID, SourceID, Versionierungsstatus (Originalfassung, Archivfassung, Spiegelung, unbekannt), aufgerufene URL, finale URL, Archiv-URL optional, Veröffentlichungsdatum (DatedValue), Abrufzeit, Ereignisdatum/-zeitraum soweit inhaltlich relevant, Gültigkeitsintervall falls relevant, Abrufverfügbarkeit (abrufbar, nicht verfügbar, Zugriff blockiert, unbekannt), Verifikationsstatus (ungeprüft, verifiziert, verworfen, überholt), ReviewerIdentity/Datum, Inhaltstyp/Sprache, optional lokale verwaltete Dateireferenz und SHA-256. Hashalgorithmus mit Hashwert speichern.
- **Versionierung:** Metadaten/Fassung unveränderlich nach Prüfung; neuer Abruf oder veränderter Inhalt erzeugt neue SourceVersion. Verfügbarkeit ist die beim Abruf beobachtete Lage und wird nicht rückwirkend verändert.
- **Beziehungen:** genau ein Source; null oder mehr SourceExcerpts; null oder mehr SourceVersions derselben logischen Source.
- **Löschen:** Datei kann nach Aufbewahrungsregeln entfernt werden, aber Metadaten/Hash referenzierter Evidenz bleiben als fehlende Kopie markiert. Keine automatische Löschung von Originaldokumenten außerhalb des App-Verzeichnisses.
- **Invarianten:** Hash belegt lokale Byteidentität, nicht Wahrheit oder Authentizität. `publicationDate`, `retrievedAt`, `eventDate` und `validityInterval` sind getrennt.

#### SourceExcerpt / Fundstelle

- **Zweck:** Präziser, kontextualisierter Ausschnitt aus genau einer Quellenfassung.
- **Felder:** ID, SourceVersionID (Pflicht), Fundstellenlocator (Seite/Absatz/Zeitmarke/Abschnitt), exakter Text oder Datenauszug, Kontexttext, Sprache, `translationOfExcerptID` optional, ExcerptVerificationState, ReviewerIdentity/Datum, Herkunft.
- **Versionierung:** Belegtext und Locator unveränderlich nach Verifikation. Korrektur erzeugt neue SourceExcerpt; vorheriger Ausschnitt wird verworfen/überholt, aber erhalten.
- **Beziehungen:** genau eine SourceVersion; kann von PromiseRevision, ActionRevision, ActionParticipation, EvidenceLink, Evaluation/Script-Aussagen referenziert werden.
- **Löschen:** keine physische Löschung, wenn in einer Evaluation verwendet; als verworfen/überholt markieren.
- **Invarianten:** kein Excerpt ohne SourceVersion. `verified` setzt Locator, Text/Auszug und menschliche Prüfung voraus. Verifizierter Originalwortlaut referenziert einen verifizierten Excerpt.

### 2.8 ActionOrDevelopment und ActionRevision

- **Zweck:** Beobachtbare Handlung, institutioneller Vorgang oder dokumentierte Entwicklung, getrennt von politischer Interpretation und Kausalbehauptung.
- **ActionOrDevelopment Felder:** ID, CaseID, aktuelle ActionRevisionID, erstellt am.
- **ActionRevision Felder:** ID, ActionID, Revisionnummer, Typ (Abstimmung, Initiative, Beschluss, Umsetzung, Entwicklung, sonstiges), Titel, Beschreibung als überprüfbare Tatsachenbehauptung, Ereignisdatum/-zeitraum, institutionelle Ebene, Objekt/Gegenstand, Verfahrensstatus, Wirkung/Umfang (oder unbekannt), Änderungsgrund, Autor/Zeit, verifiziert von ReviewerIdentity/Zeit, SourceExcerptIDs. Behauptungsrelevante Felder sind als AssertedValue mit eigener Herkunft/Prüfstatus erfasst.
- **Versionierung:** ActionOrDevelopment ist stabile Identität; ActionRevision unveränderlich. Korrektur/Sachänderung erzeugt neue Revision. Laufender Verfahrensstatus ändert nicht alte Evaluation-Snapshots.
- **Beziehungen:** eine ActionOrDevelopment besitzt Revisionen; jede Revision hat null oder mehr ActionParticipations und verifizierte SourceExcerpts; EvidenceLink kann eine konkrete ActionRevision referenzieren.
- **Löschen:** wie PromiseRevision; nach Evaluation nur superseden.
- **Invarianten:** eine Handlung ohne Fundstelle kann Recherchekontext sein, aber niemals direkt Evidenz. Antrag, Beschluss, Umsetzung und Wirkung sind unterschiedliche Verfahrensstände.

### 2.9 ActionParticipation

- **Zweck:** Explizite Zuordnung eines Akteurs zu einer konkreten ActionRevision.
- **Felder:** ID, ActionRevisionID, ActorID, Rolle (z. B. Antragsteller, abstimmende Person/Fraktion, beschließendes Organ, umsetzende Stelle, unterstützender Akteur, betroffener Akteur), Beteiligungsart (eigene Handlung, institutionelles Ergebnis, politische Unterstützung, behauptete kausale Verantwortung), Begründung optional, Fundstellenreferenzen, Prüfstatus und ReviewerIdentity/Zeit.
- **Versionierung:** gehört zu unveränderlicher ActionRevision und ist nach Verifikation unveränderlich; geänderte Zuordnung erzeugt neue ActionRevision/Teilnahme. Noch ungeprüfte Beteiligung ist als solche markiert.
- **Beziehungen:** genau eine ActionRevision und ein Actor; null oder mehr Fundstellen.
- **Löschen:** nicht kaskadieren; nach Verwendung nur als verworfen/überholt markieren.
- **Invarianten:** Parteizugehörigkeit beweist keine Beteiligung oder Kausalität. `causalResponsibility` verlangt ausdrücklich belegte Zurechnung und menschliche Prüfung. Institutionelles Ergebnis bleibt von individueller Handlung getrennt.

### 2.10 EvidenceLink

- **Zweck:** Fachliche, prüfbare Beziehung zwischen einem Kriterium und einer konkreten Evidenzbasis.
- **Felder:** ID, genau eine CriterionRevisionID, eine oder mehr SourceExcerptIDs, optionale ActionRevisionID, Beziehung `supports` / `contradicts` / `contextualizes`, Direktheit `direct` / `indirect`, fachliche Begründung, zeitliche Relevanz/Datumsbezug, Prüfstatus (draft, needsReview, verified, rejected, superseded), Prüfer/Datum, erstellt von/Datum.
- **Versionierung:** Entwurf ist editierbar; nach Prüfung unveränderlich. Korrektur erzeugt neuen Link und erhält alten. `verified` wird durch eine Prüfung durch ReviewerIdentity gesetzt.
- **Beziehungen:** genau eine CriterionRevision; mindestens ein verifizierter SourceExcerpt; optional genau eine ActionRevision. Die ActionRevision selbst ersetzt nie Fundstellen.
- **Löschen:** kein physisches Löschen nach Verwendungsbezug einer Evaluation; superseden.
- **Invarianten:** ResearchTask und ActionRevision ohne Fundstelle sind niemals EvidenceLink-Evidenz. Jeder verifizierte Link hat fachliche Begründung und mindestens einen verifizierten Excerpt. Beziehung ist keine Wahrheitsbewertung der Quelle.

### 2.11 CaseRevision

- **Zweck:** Unveränderliches Manifest der exakten Tatsachengrundlage, auf die eine Evaluation rechnet.
- **Felder:** ID, CaseID, Revisionsnummer, PromiseRevisionID, CriterionRevisionIDs, ActionRevisionIDs samt ActionParticipationIDs und deren Verifikationsstatus, SourceVersionIDs/ExcerptIDs samt Verifikationsstatus zum Erstellungszeitpunkt, EvidenceLinkIDs sowie ResearchTaskIDs mit damaligem Status, Erstellungszeit, Autor und Anlass. Das Manifest speichert IDs und nötigenfalls zeitgebundene Statuswerte, keine zweite editierbare Kopie der Inhaltstexte.
- **Versionierung:** immutable. Neue/ersetzte relevante Informationen erzeugen ein neues Manifest, niemals Überschreiben.
- **Beziehungen:** genau ein Case; genau eine PromiseRevision; referenziert alle für Evaluation verfügbaren Kriterien und Evidenzobjekte.
- **Löschen:** nie physisch, solange eine Evaluation darauf verweist.
- **Invarianten:** alle Referenzen bleiben auflösbar; IDs identifizieren die exakten Inhaltsrevisionen. Das Manifest setzt Zeitbezug, nicht Bewertungskategorie.

### 2.12 CriterionEvaluation und CaseEvaluation

**CriterionEvaluation**

- **Zweck:** Ergebnis und Begründung für ein einzelnes Kriterium in genau einer CaseEvaluation.
- **Felder:** ID, CaseEvaluationID, exakt eine CriterionRevisionID, Ergebnis aus denselben fachlichen Kategorien wie Abschnitt 4 der Produktspezifikation, Begründung, verwendete EvidenceLinkIDs, Gegenbelege (Links plus Erläuterung), Evidenzsicherheit (hoch/mittel/niedrig), Unsicherheiten, Prüfstatus (unreviewed/reviewed) und ReviewerIdentity/Prüfdatum.
- **Versionierung:** nach Freigabe unveränderlich; Korrektur erzeugt neue CaseEvaluation oder Revision derselben Evaluation, die als neuer unveränderlicher Datensatz geführt wird.
- **Beziehungen:** genau eine CaseEvaluation und CriterionRevision; null oder mehr EvidenceLinks, aber leere Menge begründet keine Nichterfüllung.
- **Löschen:** nicht löschen, wenn Elternbewertung erhalten bleibt; Korrektur superseden.
- **Invarianten:** verwendete Kriterienrevision muss im CaseRevision-Manifest stehen. `notFulfilled` verlangt belastbare, verifizierte Evidenz und menschliche Begründung. `notVerifiable` verlangt strukturierten Grund und Begründung. `contraryAction` benötigt mindestens einen verifizierten widersprechenden EvidenceLink. Niedrige Sicherheit sperrt abschließendes negatives Urteil gemäß Methodik.

**CaseEvaluation**

- **Zweck:** Unveränderlicher Gesamtbefund für eine eingefrorene Fallrevision und einen Bewertungsstichtag.
- **Felder:** ID, CaseID, CaseRevisionID, Bewertungsstichtag als DatedValue, MethodologyVersionID, Gesamtkategorie, Gesamtevidenzsicherheit, Begründung, Tatsachen/Interpretation/Unsicherheit getrennt oder als sauber typisierte Abschnitte, erstellt von/Datum, freigegeben von ReviewerIdentity/Zeit, Reviewgrund und EvaluationStatus; optionale `replacesEvaluationID` auf die ausdrücklich ersetzte historische CaseEvaluation desselben Cases (azyklische Ersatzkette).
- **Versionierung:** Entscheidungsinhalt und Freigabedaten sind nach Freigabe unveränderlicher historischer Snapshot. Neue Evidenz erzeugt eine neue CaseRevision und Evaluation; alte Evaluation wird nicht überschrieben. Ihr operativer Reviewstatus kann per AuditEntry `reviewRequired` oder nach Ersatz `superseded` werden, ohne damalige Kategorie, Begründung, CaseRevisionID, CriterionEvaluations, MethodologyVersion, Reviewer oder ursprünglichen Freigabezeitpunkt zu ändern. Neue menschliche Freigabe erfolgt an einer neuen Evaluation, bei neuer Evidenz mit neuem Snapshot; die alte Evaluation wird niemals wieder zu einem umgeschriebenen Urteil freigegeben.
- **Beziehungen:** genau ein Case und CaseRevision; eine CriterionEvaluation je verwendeter CriterionRevision; eine MethodologyVersion.
- **Löschen:** nach Freigabe nie physisch löschen; Aufbewahrungs-/Löschbedarf als ausdrücklich protokollierte Redaktion behandeln.
- **Invarianten:** freigegebene Bewertung benötigt menschlichen Reviewer; KI kann Autor/Helfer sein, nie ReviewerIdentity. Kategorie und Evidenzsicherheit sind unabhängige Werte. Gesamturteil muss mit den CriterionEvaluations konsistent begründet sein; automatische Regelprüfung darf menschliche Gesamtbewertung nicht ersetzen.

### MethodologyVersion

- **Zweck:** Regelstand, der für genau eine CaseEvaluation angewendet wurde.
- **Felder:** stabile ID, semantische Versionsnummer, Titel/Datum, Hash oder Exportreferenz auf den vollständigen Methodiktext, Änderungsnotiz.
- **Versionierung:** unveränderlich; jede Methodikänderung erhält neue Version.
- **Beziehungen:** eine Version wird von null oder mehr CaseEvaluations referenziert.
- **Löschen:** nie löschen, sobald verwendet.
- **Invarianten:** eine Bewertung referenziert genau eine MethodologyVersion; vor der ersten produktiven Bewertung ist Version 1.0 festzulegen.

### 2.13 ScriptDraft und ScriptStatement

- **Zweck:** Spätere redaktionelle Videoausgabe, deren Tatsachensätze auf geprüfte Belege zurückführen.
- **Felder:** ScriptDraft ID, CaseEvaluationID, Version, Zieldauer, Status, Modell-/Prompt-/Zeitmetadaten für KI-Hilfe, erstellt von/Datum, freigegeben von ReviewerIdentity/Zeit. ScriptStatement hat ID, ScriptDraftID, Szenenposition, Text, Typ (Tatsache, Interpretation, Frage, Einschränkung), referenzierte SourceExcerptIDs/EvidenceLinkIDs, Unsicherheits-/Kontextnotiz, Prüfstatus.
- **Versionierung:** ScriptDraft und Statements werden nach Freigabe eingefroren; neue Fassung bei Änderung. KI-Provenienz wird separat von menschlicher Prüfung geführt.
- **Beziehungen:** Draft referenziert genau eine CaseEvaluation; mehrere Statements; Statements referenzieren null oder mehr Belegstellen, verpflichtend für Tatsachen.
- **Löschen:** freigegebene Skripte bleiben Teil des redaktionellen Verlaufs; Assetdateien folgen eigener Ablage-/Löschregel.
- **Invarianten:** freigegebener Tatsachensatz braucht mindestens einen verifizierten Excerpt; Interpretation muss als solche markiert sein. Gemäß Phase 4.1 dürfen Interpretation/Frage/Einschränkung ohne Fundstellen als Entwurf vorliegen; vorhandene Referenzen müssen geprüft und snapshotgebunden sein. Freigabe ist menschlich.

### 2.14 ResearchTask

- **Zweck:** Recherchebedarf oder Rechercheversuch festhalten, ohne Evidenz vorzutäuschen.
- **Felder:** ID, CaseID, Frage/Ziel, betroffene CriterionRevisionID(s) optional, gesuchte Quelltypen, Abfrage/Recherchehinweis, Status (open, attempted, blocked, completed, cancelled), Ergebnis/Fehlerart, versucht am, nächster Schritt, verantwortlich/erstellt von. Bei Abschluss kann Source/Excerpt referenziert werden, aber der Task bleibt Task.
- **Versionierung:** Identität stabil, Ergebnis/Status auditierbar durch AuditEntry; Abschlussergebnis darf nicht als Belegtext ausgegeben werden.
- **Beziehungen:** genau ein Case; optional Criteria; optional Sources für Rechercheziele, aber keine Evidenzverknüpfung.
- **Löschen:** archivieren, nicht automatisch löschen; ein erledigter Task ersetzt keine Quellenaufnahme.
- **Invarianten:** ResearchTask kann keine Evaluation direkt stützen oder widerlegen und nie als EvidenceLink verknüpft werden.

### 2.15 AuditEntry

- **Zweck:** Unveränderlicher Verlauf fachlich relevanter Änderungen, Statuswechsel, Verifikation, Freigaben und Korrekturen.
- **Felder:** ID, CaseID, Zielobjekt-ID und Typ, Aktion, vorher/nachher Referenzen oder knappe Änderungen, Akteurtyp (Mensch/KI/System), ReviewerIdentity sofern vorhanden, Zeitpunkt, Grund, betroffene Revisionen.
- **Versionierung:** append-only; Korrektur durch Folgeeintrag. Kein Vollkopieren vertraulicher Inhalte erforderlich, wenn IDs und kontrollierte Feldänderungen genügen.
- **Beziehungen:** genau ein Case; polymorphe fachliche Zielreferenz, nicht selbst Evidenz.
- **Löschen:** nach Case-Freigabe nicht physisch editieren; lokale Case-Löschung folgt Aufbewahrungsentscheidung.
- **Invarianten:** KI-Eintrag weist optionalen menschlichen Anforderer als ReviewerIdentity aus, wird jedoch nie als menschliche Bestätigung/Freigabe interpretiert.

## 3. Aggregate und Referenzregeln

**Case ist das einzige fachliche Aggregate-Root.** Es koordiniert IDs, Draft-Fortschritt und Snapshot-Erstellung. Andere große Inhalte (SourceVersion-Dateien, SourceExcerpt, Revisionen, Evaluations) sind abhängige Datensätze mit eigenen stabilen IDs, keine eigenen Services oder Datenbanken.

CaseRevision ist ein ID-Manifest, kein zyklisches Objekt: Es referenziert PromiseRevision, CriterionRevision, ActionRevision, SourceVersion/Excerpt und EvidenceLink. CaseEvaluation referenziert CaseRevision; CriterionEvaluation ist Kind der CaseEvaluation. CaseRevision enthält keine CaseEvaluation. EvidenceLink referenziert CriterionRevision und SourceExcerpt, optional ActionRevision; die ActionRevision führt nicht zurück zum EvidenceLink. Dadurch bleibt der Graph azyklisch.

Identische Zitattexte werden nicht mehrfach als eigene Belege gespeichert: SourceExcerpt ist kanonischer Textausschnitt; PromiseRevision und ScriptStatement referenzieren ihn. Eine konkrete Behauptung in einer ActionRevision kann mehrere Quellen haben, aber die belegende Fundstelle bleibt jeweils eindeutiger SourceExcerpt. Snapshot-Manifeste halten die verwendeten IDs fest, statt alle Textfelder doppelt zu speichern.

## 4. Bewertungsobjekt und bestehende Methodik

Ergebniswerte und Definitionen entsprechen unverändert der bestehenden Produktspezifikation Abschnitt 4. CriterionEvaluation und CaseEvaluation strukturieren deren Anwendung; sie führen keine neue politische Skala ein. Das strukturierte „Nicht überprüfbar“-Grundfeld ergänzt die verlangte Begründung und ändert nicht die Kategorie. Mögliche Gründe: unklare Aussage, offene Frist, Bedingung nicht eingetreten, entscheidende Evidenz fehlt, Zurechnung ungeklärt, Quellenkonflikt, technischer Recherchezugriff blockiert. Mehrere Gründe sind möglich.

Materialitätsregel wird pro bestätigter CriterionRevision textlich begründet und vor der Evaluation festgelegt; keine allgemeine Prozentgrenze. Methodik-Versionierung benennt die Regelbasis. Hoch/mittel/niedrig bleibt qualitative Evidenzsicherheit, getrennt von Ergebnis und Reviewstatus.

## 5. Technische Invarianten und Erzwingbarkeit

| # | Invariante | Erzwingbarkeit |
| --- | --- | --- |
| 1 | Kein verifiziertes Originalzitat ohne SourceExcerpt an einer konkreten SourceVersion. | **Technisch teilweise:** Referenz, Version, Text und Status erzwingbar; inhaltliche Authentizität nur menschlich. |
| 2 | Kein SourceExcerpt ohne SourceVersion. | **Technisch vollständig** über nicht-optionale Referenz/Fremdschlüssel. |
| 3 | Kein EvidenceLink ohne genau eine CriterionRevision. | **Technisch vollständig** über Referenz und Kardinalität. |
| 4 | Kein verifizierter EvidenceLink ohne mindestens eine verifizierte Fundstelle. | **Technisch teilweise:** Kardinalität/Prüfstatus erzwingbar; trägt die Fundstelle den Befund, prüft ein Mensch. |
| 5 | ResearchTask ist niemals Evidenz. | **Technisch vollständig** durch getrennte Typen und keine EvidenceLink-Referenzmöglichkeit. |
| 6 | Keine freigegebene Bewertung ohne menschlichen Reviewer. | **Technisch vollständig** hinsichtlich Vorhandensein und Mensch-Actor-Typ; ob die Prüfung sachgerecht war, menschlich. |
| 7 | „Nicht erfüllt“ darf nicht allein aus leerer Evidenz entstehen. | **Technisch teilweise:** nichtleere verifizierte Links plus menschlicher Grund verlangen; Aussagekraft des Belegs ist fachlich. |
| 8 | „Gegenteilig gehandelt“ braucht widersprechende Evidenz. | **Technisch teilweise:** mindestens ein verifizierter `contradicts` Link erzwingbar; direkte Widersprüchlichkeit zum Kern menschlich zu bestätigen. |
| 9 | „Nicht überprüfbar“ braucht expliziten Grund. | **Technisch vollständig** für strukturierten Code plus Begründung. |
| 10 | Änderung einer verwendeten CriterionRevision markiert abhängige Evaluation als reviewRequired. | **Technisch vollständig** bei jeder neuen Revision/Änderung; alte Revision selbst bleibt unverändert. |
| 11 | Neue Evidenz überschreibt historische Evaluation nicht. | **Technisch vollständig** durch immutable Evaluation/Snapshot und neue Datensätze. |
| 12 | Stichtag wird gegen Ereignis/Gültigkeit geprüft, nicht pauschal gegen Quellenpublikation. | **Technisch teilweise:** Rollen und eindeutige Zeitgrenzen prüfbar; Relevanz historischer Quelle menschlich. |
| 13 | KI kann nicht als menschlicher Reviewer eingetragen werden. | **Technisch vollständig** durch getrennten Akteurtyp/Reviewer-Identität. |
| 14 | Freigegebener Script-Tatsachensatz hat Fundstellenreferenz. | **Technisch vollständig** für Referenz und Reviewstatus; tatsächliche Belegkraft menschlich. |
| 15 | Eine Handlung ohne Fundstelle darf nicht allein Evidenz sein. | **Technisch vollständig** durch EvidenceLink-Pflicht auf SourceExcerpt; politische Aussagekraft bleibt fachlich. |
| 16 | Bestätigte Kriterien müssen vor verbindlicher Bewertung eingefroren sein. | **Technisch vollständig** für Zeitstempel, Bestätiger und Revision; Angemessenheit menschlich. |
| 17 | Ein Publikationsdatum nach Bewertungsstichtag disqualifiziert eine Quelle nicht allein. | **Technisch teilweise:** keine automatische Sperre anhand publicationDate; rückblickende Relevanz wird angezeigt und menschlich beurteilt. |

„Vollständig“ bezieht sich auf die formale Regel in der lokalen Datenbank, nicht auf die Wahrheit des gespeicherten politischen Befunds. SwiftData kann Beziehungen und App-Validierungen unterstützen; mehrstufige fachliche Regeln müssen zusätzlich in der Domain-Logik geprüft werden.

## 6. Versionierung und Neubewertung

- **Immutable fachliche Revisionen:** PromiseRevision, CriterionRevision, SourceVersion, verifizierte SourceExcerpt, ActionRevision, geprüfter EvidenceLink, CaseRevision, freigegebene Evaluation und freigegebenes Script.
- **Stabile Identität mit Audit statt Vollrevisionierung:** Case, Promise, EvaluationCriterion, Actor, Source, ActionOrDevelopment, ResearchTask und ScriptDraft-Arbeitskopf. Inhaltliche Änderungen an diesen Objekten erzeugen die oben benannten Revisionen oder AuditEntries.
- Ein neues Ereignis oder verifizierter EvidenceLink erzeugt ein neues CaseRevision-Manifest. Die alte CaseEvaluation bleibt historisch lesbar. Betroffene Freigaben werden zusätzlich als `reviewRequired` markiert; dies ist ein Workflowhinweis, keine rückwirkende Änderung ihrer damaligen Kategorie.
- Eine bestätigte CriterionRevision wird niemals in-place geändert. `CriterionRevisionState` wechselt nur von `draft` zu `confirmed` oder `superseded`; eine bestätigte Revision kann nicht zurück in Draft. Neue Revision verlangt Änderungsgrund. Abhängige aktive Evaluationen werden markiert; eine neue Bewertung referenziert neue Kriterien. Alte Scripts und Bewertungen bleiben mit ihren alten Kriterienrevisionen verbunden.
- Ein Excerpt kann in mehreren Revisionen/Evaluationen wiederverwendet werden; sein Text bleibt unverändert. Neue Quellfassung erzeugt SourceVersion und bei Bedarf neue Excerpts.
- Kein Cascade Delete für referenzierte historische Objekte. Lokale Aufbewahrung/Datenschutz kann eine explizite Löschung des ganzen Cases verlangen; das ist sichtbar zu protokollieren und die erwarteten Folgen für externe Dateien zu nennen.

### Präzisierung für Phase 3.2a: Prüfrahmen vor erster Bewertung

Die menschliche Kontext- und Sprecherprüfung eines `documented` Cases erzeugt eine neue PromiseRevision. Originalzitat einschließlich Prüfstatus, Fundstellen und ursprünglicher HumanReview sowie alle anderen unveränderten Felder werden exakt übernommen. Kontext und dieselbe bestehende Sprecher-Actor-ID erhalten ausdrücklich ausgewählte verifizierte Excerpts an verifizierten SourceVersions und einen menschlichen Prüfvermerk. Daraus folgt keine Parteiverifikation.

Jede aktive CriterionRevision wird bei diesem Promise-Head-Wechsel mit gleicher Messlatte, neuer ID und erhöhter Revisionsnummer an die neue PromiseRevision gebunden. Auch zuvor bestätigte Kriterien beginnen wieder als `draft` ohne confirmation; der Mensch bestätigt die Eignung für den neuen Prüfrahmen separat. Alte Revisionen und deren Bestätigungen bleiben unverändert. Vorhandene EvidenceLinks und ResearchTasks behalten ihre bisherigen Kriterienreferenzen; es gibt keine automatische Neubindung von Evidenz.

Dieser konkrete Vorgang ist auf den dokumentierten Fall vor der ersten Bewertung begrenzt und wird bei vorhandener CaseRevision oder CaseEvaluation desselben Cases vollständig blockiert. Nach erfolgreicher Prüfung folgen getrennte bestehende Core-Transitions `documented → verified → readyForEvaluation`. Bewertungsreife bedeutet einen stabilen menschlich geprüften Prüfrahmen, noch kein Urteil. In Phase 3.2a entsteht kein Bewertungssnapshot, keine Kriterien-/Gesamtbewertung und keine Methodikversion. Spätere Änderungen eines bereits fortgeschrittenen oder historisch bewerteten Falls benötigen einen eigenen Neubewertungsablauf.

### Phase 3.2b: erste manuelle Bewertung und Freigabe

`docs/methodology-v1.0.md` konsolidiert wortgleich Produktspezifikation 4 und 5 sowie die Mindestanforderungen aus 3.1. MethodologyVersion **1.0** ist ab dieser Phase eingefroren: eine kanonische UUID, Referenz und SHA-256 bezeichnen denselben Regelstand für alle Cases. Änderungen benötigen künftig eine neue Version; ein abweichender Datensatz unter 1.0 ist ein Konflikt, kein Update.

Die erste Bewertung beginnt ausschließlich aus `readyForEvaluation`. Eine pure Core-Operation erzeugt ein unveränderliches, Domain-validiertes CaseRevision-Manifest: aktuelle PromiseRevision, exakt aktive bestätigte Kriterien, aktuelle und von geprüfter Evidenz referenzierte Handlungsrevisionen, zugehörige Beteiligungen, gespeicherte Quellenfassungen/Fundstellen mit ihren tatsächlichen Statuswerten, ausschließlich aktuell verified EvidenceLinks zu den Snapshot-Kriterien sowie ResearchTasks als Kontext. Kein historisch superseded Link wird für einen neuen Snapshot in verified umgedeutet. Zusätzliche im Case gespeicherte Quellen bleiben im Manifest nachvollziehbar, sind dadurch aber nicht automatisch bewertbare Evidenz.

Kategorie, Begründung, qualitative Evidenzsicherheit und Unsicherheiten werden für jedes Kriterium und den Gesamtfall separat menschlich eingegeben. Genau eine CriterionEvaluation gehört zu jeder Snapshot-CriterionRevision. Verwendete Links müssen im Snapshot verified sein und zu diesem Kriterium gehören; Gegenbelege sind eine Teilmenge der verwendeten Links. Keine mathematische Aggregation, keine automatische Kategorie aus Beziehung oder Parteiidentität. Fakten und Interpretationen sind getrennte menschliche Texte.

CriterionEvaluation beginnt unreviewed ohne HumanReview. Ein eigener Core-Prüfschritt erlaubt genau einmal den Wechsel zu reviewed mit gültiger ReviewerIdentity; alle Inhaltsfelder und IDs bleiben dabei unverändert. Das präzisiert die bisher konservativ vollständig immutable CriterionEvaluation-Repräsentation, ohne historische Inhalte editierbar zu machen. Nach Prüfung sind auch die Prüfmetadaten unveränderlich. Die Elternbewertung beginnt draft. Vorlage (`draft → needsReview`) und menschliche Freigabe (`needsReview → approved`) sind eigene Schritte; Freigabe verlangt geprüfte Kinder und die bestehenden finalen Validatorregeln. Confidence ist keine Wahrheitswahrscheinlichkeit. Materialität, Quellenkonflikte und Zurechnung bleiben menschliche Entscheidungen.

Beim atomaren Speichern eines vollständigen gültigen Entwurfs wechselt der Case per Core-Transition von readyForEvaluation zu evaluated. Erst nach Freigabe der Evaluation wechselt er atomar von evaluated zu approved. Der Bewertungsstichtag wird ausdrücklich gewählt und als DatedValue mit evaluationCutoff in der Evaluation gespeichert. Ein zuvor allein gespeicherter Snapshot enthält nach bestehendem Modell keinen Stichtag; beim Fortsetzen vor Entwurfsspeicherung muss der Nutzer den Stichtag erneut ausdrücklich eingeben. Historische Snapshots bleiben unverändert. Neue geprüfte Evidenz kann weiterhin reviewRequired auslösen, ohne Urteil, Methodik, Kinder oder ursprüngliche Freigabe umzuschreiben. Ersatzreview und Entwurfs-Inhaltskorrektur über neue Datensätze folgen separat; dieser konkrete Workflow erzeugt nur die Erstbewertung mit replacesEvaluationID = nil.

## 7. Scope-Entscheidungen für SwiftData

Ein einzelner lokaler Store genügt. Beziehungen werden über IDs/Referenzen und inverse Verknüpfungen modelliert; Snapshot-Manifest kann geordnete ID-Listen speichern. Große Dokumentdateien bleiben außerhalb SwiftData im verwalteten Application-Support-Speicher, Metadaten/Hashes liegen in SwiftData. Export als JSON-Paket enthält Manifest und benötigte lokale Quellen nur, soweit Nutzungsrechte dies erlauben.

SwiftData-eigene Modellklassen sind später Persistenzabbildung, nicht selbst die fachliche Spezifikation. Fachliche Invarianten gehören in testbare Domain-Validierung plus UI-Meldungen. Es werden keine generischen Event-Sourcing-, Berechtigungs-, Mehrmandanten- oder Synchronisierungsrahmen eingeführt.

## 8. Zustandsübergänge

### CaseWorkflowState

`candidate → documented → verified → readyForEvaluation → evaluated → approved`

- **candidate:** Idee/Recherchekandidat; Versprechen kann nur Hypothese sein.
- **documented:** PromiseRevision und Originalfundstelle(n) erfasst; Details können ungeprüft sein.
- **verified:** Originalwortlaut, Kontext und Akteurzuordnung menschlich geprüft; noch keine vollständige Evidenzbewertung behauptet.
- **readyForEvaluation:** Kriterienrevisionen menschlich bestätigt und eingefroren; Quellen/Fundstellen verifiziert; offene ResearchTasks sind sichtbar. Der Zustand behauptet nicht, dass jede Tatsachenfrage abschließend geklärt ist.
- **evaluated:** mindestens ein CaseEvaluation-Snapshot existiert, noch nicht zwingend freigegeben.
- **approved:** mindestens eine historisch menschlich freigegebene CaseEvaluation mit erhaltenen Freigabemetadaten existiert. Ihre aktuelle Reviewfreiheit ist damit nicht ausgesagt.

Die Case-Folge ist monoton; es gibt keine Rücksprünge bei neuer Evidenz oder Kriterienrevisionen. Korrekturen erzeugen neue Revisionen und AuditEntry; die bestehende Evaluation erhält `reviewRequired`, ohne die erreichte Case-Reife zu ändern. Für `evaluated` und `approved` belegen historische Evaluation-Snapshots die erreichten Meilensteine, auch wenn die aktuellen Arbeitsköpfe bereits neuere Entwürfe enthalten. Keine alte Snapshot-Bewertung wird wieder in Draft umgeschrieben. Bei nicht verifizierbarem Fall kann `readyForEvaluation` zu einer ausdrücklich begründeten Evaluation „nicht überprüfbar“ führen; eine Rechercheblockade darf dabei nicht als Nichterfüllung kodiert werden.

**Abgeleiteter CaseReviewState (kein persistiertes Feld):** `notYetApproved` bedeutet noch keine historische Freigabe; `reviewRequired` bedeutet offenen erneuten Prüfbedarf; `upToDate` bedeutet eine aktuelle menschliche Freigabe ohne unaufgelösten Reviewbedarf. Ein historisch freigegebener Case kann deshalb gleichzeitig WorkflowState `approved` und CaseReviewState `reviewRequired` besitzen.

Ein offen reviewbedürftiges oder überholtes Urteil wird nur durch eine menschlich freigegebene Evaluation mit ausdrücklicher, gegebenenfalls transitiver Ersatzbeziehung aufgelöst. Eine andere Freigabe allein genügt nicht. Die aktuelle Freigabe muss im Manifest die aktuellen Promise-/Kriterien-/Handlungsrevisionen und die verfügbaren verifizierten Links zu diesen Kriterien abdecken. Ein ungeprüfter Ersatzentwurf löst keinen Review auf. Bei strukturell ungültigen Eingaben darf die Ableitung kein `upToDate` vortäuschen. Dies ist eine technische Aktualitätsprüfung, keine automatische politische Neubewertung.

### SourceExcerpt

`unverified → verified → superseded`

`unverified → rejected` ist zusätzlich erlaubt. Verifizierter Text wird nicht in-place editiert. Neue korrekte Fundstelle erzeugt neue ID; alte wird rejected/superseded mit Grund.

### CriterionRevisionState

`draft → confirmed → superseded`

`confirmed` friert die Kriterienrevision ein. Eine Änderung erzeugt eine neue Draftrevision mit Änderungsgrund; die bestätigte Revision bleibt historisch erhalten.

### EvaluationStatus

`draft → needsReview → approved → reviewRequired → superseded`

Draft/needsReview dürfen nach Korrektur in neue Draftrevision überführt werden. `approved` ist unveränderlich; neuer Beleg/Kriterienrevision setzt Reviewbedarf, danach entsteht neue Evaluation. `superseded` bedeutet durch neue freigegebene Evaluation ersetzt, nicht dass der historische Befund nie galt. Keine automatische politische Neuberechnung.

### FactVerificationState

`unreviewed → verified | rejected`; `verified → superseded` bei belegter Ablösung/Korrektur. Verwerfen ist nicht gleich „politisch falsch“.

## 9. Bewusste Vereinfachungen und offene Detailentscheidungen

- Ein Case enthält im MVP ein Promise; zusammengesetzte Versprechen erhalten getrennte Criteria oder getrennte Cases, wie Abschnitt 2 der Produktspezifikation vorsieht.
- Eine ActionRevision hält den fachlichen Vorgang; Akteursbeziehungen sind separate ActionParticipations. Eine Participation referenziert Belegstellen der Zurechnung.
- EvidenceLink kann mehrere Fundstellen haben, aber genau ein Kriterium einer Revision. Eine bekannte Ursprungsquelle wird in Source über `originSourceID` referenziert, nicht als freier Text auf EvidenceLink.
- Kein separates Ereignis-/Abstimmungsdienst, keine externe Archivintegration, kein automatischer Belegimport. Nutzer kann historische Archive manuell als SourceVersion erfassen.
- Präzise rechtliche Ausgestaltung von Datenlöschfristen und urheberrechtlicher Aufbewahrung ist Produkt-/Rechtsreview vor öffentlicher Distribution, kein Blocker für internes Domain Model.
- MethodologyVersion braucht vor erster produktiver Bewertung eine verbindliche `1.0` plus Inhaltsexport. Spezifikation benennt bisher keine semantische Grenze für Materialität; die konkrete Maßstabsbegründung ist menschliche/redaktionelle und fallbezogene Entscheidung.

## 10. Architektur-Review

- **Zyklen:** Keine fachlichen Zyklen. CaseRevision manifestiert Eingaben und referenziert nicht zurück auf Evaluation; EvidenceLink referenziert Kriterienrevision und Fundstelle, ActionRevision nicht EvidenceLink.
- **Doppelte Datenhaltung:** Originalzitat, Handlungsauszug und Skriptquelle verweisen auf kanonische SourceExcerpts. Snapshots speichern IDs plus zeitabhängige Prüfstatus, nicht zweite editierbare Volltexte.
- **Eindeutige Feldbedeutung:** Datumsrollen, Erfassungsherkunft, Verifikationsstatus, Workflow, Freigabe und Evidenzsicherheit sind getrennt. MethodologyVersion braucht vor erstem freigegebenen Urteil eine feste semantische Version.
- **SwiftData-Eignung:** Stabile IDs, kleine Revisionseinträge und Beziehungen sind in einem lokalen SwiftData-Store umsetzbar. Dateien liegen außerhalb des Stores. Domain-Prüfungen bleiben in testbarer Logik statt nur in UI oder Persistenzklassen.
- **Roundtrip für einen Fall:** Case, PromiseRevision, bestätigte CriterionRevisions, Sources/Versions/Excerpts, Handlungen/Beteiligungen, EvidenceLinks, CaseRevision und Evaluation referenzieren stabil; Export/Backup muss Manifeste, IDs und verwaltete Dateien gemeinsam erhalten.
- **Historische Nachvollziehbarkeit:** Immutable Inhaltsrevisionen, feste MethodologyVersion und CaseRevision-Manifest bewahren den damaligen Befund. Neue Informationen eröffnen erneute Prüfung und überschreiben keine alte Kategorie.
- **Erweiterbarkeit:** ScriptDraft/ScriptStatement referenzieren bestehende Evaluations und Fundstellen. Spätere Visual-/Voiceover-Assets können an ScriptStatement hängen, ohne Promise-/Evidence-Kern zu ändern.

Das Modell bleibt für den festgelegten Einzelfall-MVP implementierbar. Externe Rechts-/Aufbewahrungsfristen und konkrete Materialitätsentscheidungen sind außerhalb der technischen Modellstruktur zu klären; sie blockieren die Definition der Domain-Objekte nicht.

Phase 3.2b präzisiert die Aktualitätsableitung: Der erwartete Satz von ActionRevision-IDs umfasst aktuelle Arbeitsköpfe plus ältere Revisionen, auf die aktuell verfügbare verified Links ausdrücklich verweisen. Dieser geschlossene Referenzsatz verhindert einen falschen ReviewRequired-Befund allein durch notwendige historische Evidenzabhängigkeiten; geänderte Arbeitsköpfe oder neue nicht abgedeckte Links erzeugen weiterhin Reviewbedarf.

### Präzisierung Phase 4.1 – Skriptprüfung und Quellenbindung

ScriptStatement-Inhalt bleibt immutable. Als einzige Lifecycle-Ergänzung ist der einmalige Wechsel review=nil → HumanReview erlaubt, durch DomainChanges.reviewScriptStatement: vorhandener gespeicherter Satz, parent draft/needsReview, aktuell approved CaseEvaluation, vorhandene menschliche ReviewerIdentity und Prüfdatum ab Skripterstellung. Ein vorhandener Review darf nicht ersetzt werden. Text, Typ, Position, Unsicherheit und Referenzen dürfen unter derselben ID niemals geändert werden. Inhaltliche Bearbeitung erzeugt eine neue vollständige ScriptDraft-Version mit neuen Satz-IDs und zurückgesetzten Reviews.

Jeder Tatsachensatz benötigt bereits als Entwurf eine geprüfte Fundstelle aus dem konkreten CaseRevision-Snapshot der Evaluation. Auch optionale Referenzen anderer Satztypen müssen darin geprüft sein. Quellenfassungen gehören ebenfalls geprüft zum Manifest. EvidenceLink-Referenzen müssen im Snapshot verified und in den CriterionEvaluations dieser Evaluation verwendet sein; alle Fundstellen eines referenzierten Links müssen am Satz stehen. Ein Skript besitzt mindestens einen Satz mit eindeutiger nicht negativer Position. Freigabe verlangt alle menschlichen Satzprüfungen und weiterhin operativ approved Evaluation; der erlaubte Lifecycle bleibt unverändert. Neue Versionen lösen frühere Freigaben nicht automatisch ab. Sprachliche Wahrheit, Motive und Tragfähigkeit einer Quellenzuordnung bleiben menschlich/fachlich zu prüfen.

Provider-Input/Output sind ausschließlich Transferwerte außerhalb des Domain-Core und keine persistierte Wahrheit oder Evidenz. Provider-Ausgaben erzeugen nur ungeprüfte ScriptDraft-/ScriptStatement-Datensätze. Die vorhandene historisch monotone Case-Freigabe und operative Evaluation-/Script-Reviewlogik bleiben unverändert.
