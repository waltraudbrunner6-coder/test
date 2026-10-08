# Manuelle reale Fallabnahme – Vorlage

Diese Vorlage enthält keine reale politische Aussage. Sie wird nach erfolgreicher technischer Abnahme lokal von einem Menschen ausgefüllt. Reale Fallinhalte, Quellen und das ausgefüllte Protokoll nicht automatisch ins Repository committen. Technische Bereitschaft ersetzt keine journalistische Prüfung.

## Vorbereitung und Fallwahl

- [ ] Eigenen lokalen macOS-14+-Teststore ohne Demo-Daten verwenden; bestehende Arbeitsdaten separat sichern.
- [ ] App-Build, Commit und erfolgreichen CI-Lauf im lokalen Protokoll festhalten.
- [ ] Einen einfachen österreichischen Einzelfall selbst auswählen: zugängliche Originalaussage, identifizierbarer Sprecher, mindestens ein überprüfbares Kriterium, geeignete Original-/Primärquelle zur späteren Entwicklung und klarer Bewertungsstichtag. Einfachheit vor politischer Wirkung.
- [ ] Originale tatsächlich öffnen und lesen. Keine Quelle erfinden; keine Aussage aus Erinnerung erfassen, wenn das Original fehlt. Bei fehlendem Zugriff ausdrücklich unbestätigt lassen oder die Prüfung abbrechen.
- [ ] Keine automatische Bewertung, keine vorab gewählte Kategorie. Bestätigende und widersprechende Evidenz samt Kontext prüfen. Fehlende Suchtreffer sind keine Nichterfüllung; bei entscheidenden Lücken „Nicht überprüfbar“ erwägen.
- [ ] Parteiidentität ist kein Maßstab und keine Parteizugehörigkeit ein Verantwortungsbeweis. Eigenes Handeln, institutionelles Ergebnis und kausale Verantwortung trennen. Keine Motivunterstellung.

## Produktiver Durchlauf

1. **Neuen Fall erstellen:** Prüfername setzen (Toolbar oder erstes Fallformular), Arbeitstitel, wortgetreue Originalaussage, separate Prüfthese, Sprecher/Partei zum Aussagezeitpunkt und belegtes Datum eingeben. Ungeprüften candidate erwarten.
2. **Originalquelle erfassen:** URL/Dokumentkennung, konkrete Quellenfassung, Publikationsdatum, genaue Fundstelle, exakten Auszug und Kontext manuell aufnehmen. URL wird nur gespeichert, nicht automatisch abgerufen.
3. **Fundstelle verifizieren:** Auszug, Locator, Fassung und Kontext am Original vergleichen; erst dann Fundstelle und Fassung als geprüft markieren. Neue geprüfte IDs und erhaltene alte Fassung kontrollieren.
4. **Originalzitat bestätigen:** Wortgleichheit und passende geprüfte Fundstelle kontrollieren; Originalaussage separat bestätigen. Keine KI-Paraphrase als Original.
5. **Fall dokumentieren:** candidate → documented über die angebotene Aktion. Keine übersprungenen Meilensteine.
6. **Kontext und Sprecher prüfen:** „Prüfrahmen bestätigen“ öffnen, Kontext und vorhandenen Sprecher anhand separat ausgewählter geprüfter Belege bestätigen. Nicht automatisch eine Parteizugehörigkeit oder Verantwortung daraus ableiten.
7. **Kriterien bestätigen:** Vor Bewertung und vor Einstufung möglichst wenige notwendige Kriterien festlegen: Zielzustand, Umfang, Frist/Bedingungen, Kernstatus und Materialitätsregel. Bereits vorhandene Kriterien werden bei Schritt 6 neu angebunden und beginnen erneut als Draft; diese Revisionen ausdrücklich bestätigen. Bei noch keinen Kriterien diese jetzt anlegen und bestätigen. Ausgangslage oder Bedingungen, die in der derzeitigen Oberfläche nur als unbekannt erfasst werden können, als Produktgrenze protokollieren, falls für den Fall entscheidend.
8. **Bewertungsreife erreichen:** „Fall als geprüft markieren“, danach „Zur Bewertung vorbereiten“. confirmed Kriterien und Bezug zur aktuellen PromiseRevision kontrollieren. Bewertungsreife ist kein Urteil.
9. **Handlungen/Entwicklungen erfassen:** Spätere Original-/Primärquellen als neue Quellen/Fundstellen erfassen und prüfen. Handlung, Verfahrensstatus, Ereignisdatum und Umfang getrennt eingeben, danach „Handlung prüfen“. Antrag, Beschluss, Umsetzung und Wirkung nicht verwechseln. Grenzen der derzeitigen Akteurs-/Beteiligungserfassung bei benötigter Zurechnung protokollieren.
10. **EvidenceLinks prüfen:** Gegen das genaue bestätigte Kriterium Fundstellen und optional konkrete Handlungsrevision auswählen; supports/contradicts/contextualizes, Direktheit, Begründung und Ereignis-/Gültigkeitsbezug menschlich festlegen. „Evidenz zur Prüfung vorlegen“, dann „Evidenz prüfen“. Gegenbelege und verbleibende Lücken ausdrücklich untersuchen.
11. **Stichtag setzen:** Bei „Neue Bewertung starten“ den Bewertungsstichtag ausdrücklich als UTC-Kalendertag eingeben; Snapshot öffnen. Ereigniszeit und Publikationszeit unterscheiden. Eine spätere Publikation über frühere Ereignisse darf nicht allein wegen des Publikationsdatums ausgeschlossen werden; Warnung fachlich prüfen.
12. **CriterionEvaluations durchführen:** Je Snapshot-Kriterium Belege/Gegenbelege, Kategorie, Confidence, Begründung und Unsicherheit eingeben. Keine mathematische Aggregation. Bei notVerifiable einen passenden strukturierten Grund auswählen.
13. **Gesamtbewertung durchführen:** Kategorie und Confidence separat begründen; Tatsachen, Interpretation und Unsicherheit trennen. Erst nach Sichtung der Evidenz wählen. Low Confidence darf kein abschließendes negatives Urteil begründen. Entwurf speichern, jedes Kriterium menschlich prüfen.
14. **Bewertung freigeben:** Separat zur Prüfung vorlegen und menschlich freigeben. Historisches approved, aktuelle Reviewfreiheit, Snapshot, Methodik 1.0 und Reviewer/Approval kontrollieren. App schließen und wieder öffnen; gespeicherten Stand vergleichen.
15. **Skriptentwurf erzeugen:** Wahlweise manuellen Draft erstellen (vollständig ohne API möglich) oder OpenAI nutzen. Bei OpenAI zuerst den Dialog mit allen übertragenen Excerpts lesen; nur nach bewusster Bestätigung senden. Entwicklungs-Key ausschließlich in der Prozessumgebung gemäß [openai-integration.md](openai-integration.md), niemals im Falltext. Keine Live-Abnahme in CI.
16. **Jeden Satz prüfen:** Tatsachen, Interpretation, Frage und Einschränkung unterscheiden; Quellen und Kontext nebeneinander lesen. Jeder fact braucht einen geprüften Snapshot-Auszug, der den konkreten Satz tatsächlich trägt. Keine erfundenen Fakten oder Motive; Kategorie und Unsicherheit nicht verschärfen. Jeder Satz erhält eine eigene menschliche Prüfung. Korrekturen als neue Skriptversion speichern und erneut prüfen.
17. **Skript freigeben:** Separat zur Prüfung vorlegen und freigeben. Alle Satzreviews und aktuelle approved Evaluation prüfen. Nach erneutem App-Start Inhalte, Quellenbezüge und Freigaben vergleichen.
18. **Redaktionspaket exportieren:** Im Exportabschnitt Zusammenfassung prüfen, neuen expliziten Zielort mit `.politicalfactcheck` wählen. Acht Dateien kontrollieren: Manifest, Bericht, vollständiges Archiv, Skript, Quellen, Storyboard, Methodik, README. Storyboard enthält noch keine erzeugten Visuals. Exporte sind historische Stände.
19. **In frischen Store importieren:** App schließen. Einen getrennten frischen Teststore verwenden; die App speichert standardmäßig unter Application Support `PoliticalFactCheck/Cases.store`. Kein Store-Wechseldialog vorhanden. Bestehenden Store nur bei geschlossener App sicher sichern/isolieren, nie ungesichert überschreiben; bei Unsicherheit separate macOS-Testumgebung benutzen. Paket wählen, Vorschau prüfen, ausdrücklich importieren; App schließen und wieder öffnen. Der gleiche Case im ursprünglichen Store wird absichtlich als Kollision abgewiesen.
20. **Fachlichen Stand vergleichen:** Case-ID, Promise-Historie, Kriterienrevisionen, Quellenfassungen/Fundstellen, Handlungen, Evidenzlinks, CaseRevision, CriterionEvaluations, CaseEvaluation, Methodik, ursprüngliche Reviewer/Approval-Zeiten, Skript/Satzreviews und AuditEntries anhand Archiv und Oberfläche vergleichen. Aktueller CaseReviewState muss unverändert sein. Import ist keine neue journalistische Freigabe.

## Ergänzende Fehler- und Revisionsprüfung

- [ ] OpenAI bei fehlendem Key oder Providerfehler: verständliche Meldung, keine verlorenen Daten, manueller Entwurf weiterhin möglich. Keine Zugangsdaten oder rohe HTTP-Dumps in der UI.
- [ ] Bereits vorhandenes Exportziel: kontrollierte Ablehnung, vorhandenes Paket und Falldaten unverändert.
- [ ] Ausschließlich Kopie des Pakets manipulieren: Import abgewiesen, kein Teilfall im frischen Store.
- [ ] Optional in einer separaten Fall-/Storekopie nach Freigabe neue relevante Evidenz prüfen: Evaluation reviewRequired, historisches Urteil/Approval erhalten, bisheriges Skript superseded, neuer finaler Export und neue Skripte blockiert. Nicht an der einzigen abgenommenen Fassung ausprobieren. Der UI-Ersatzreview ist noch nicht implementiert; keine Umgehung über Statusänderungen.
- [ ] Bei unzureichender Evidenz einen explizit begründeten notVerifiable-Befund zulassen, sichere Teilbefunde/Unsicherheiten sichtbar halten.
- [ ] Auffindbarkeit aller Aktionen, Fehlermeldungen, Wiederöffnung und Formverhalten tatsächlich am Mac prüfen. Ungespeicherte Formtexte können beim Schließen verloren gehen; gespeicherte Snapshots dürfen das nicht.

## Datenschutz und Grenzen

Der OpenAI-Dialog zeigt vor dem Senden die übertragenen Auszüge. Nur notwendige Snapshotdaten verwenden; keine privaten Notizen oder unnötigen personenbezogenen Daten in übertragenen Fallfeldern erfassen. Keinen API-Key in Screenshots, Logs oder Exportpakete aufnehmen. Das vollständige Archiv enthält auch alte/ungeprüfte Texte und personenbezogene Reviewer-/Auditdaten; vor Weitergabe prüfen. Hashes beweisen Dateiidentität, keine Wahrheit oder Authentizität. Keine automatische Recherche, Bewertung oder Veröffentlichung.

Video, TTS, automatische Untertitel, Visualgenerierung, Teamfunktionen, öffentliche Distribution, Backend-Broker, App Store und Notarisierung gehören nicht zu dieser Abnahme.

## Abnahmeprotokoll

Lokal ausgefüllte Kopie verwenden; diese Repository-Datei bleibt leere Vorlage.

| Feld | Eintrag |
| --- | --- |
| Testdatum | |
| App-Commit / CI-Lauf / macOS-Version | |
| Fallbezeichnung | |
| Evaluations-ID | |
| Script-ID | |
| Exportpaket | |
| Ergebnis (bestanden / mit Blockern / abgebrochen) | |
| Gefundene Blocker | |
| UX-Probleme | |
| Datenverlust ja/nein, Details | |
| Fachliche Inkonsistenz ja/nein, Details | |
| OpenAI-Generation getestet ja/nein | |
| Import erfolgreich ja/nein | |
| Freigabe durch menschlichen Tester / Zeitpunkt | |

Erst nach erfolgreichem vollständigem menschlichem Durchlauf und dokumentierter Freigabe kann der Status `MVP ACCEPTED` lauten. Die Vorlage selbst erteilt keine Freigabe.
