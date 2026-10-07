# Spezifikationsvalidierung 01

Stand: 7. Oktober 2026 · Bezug: `test-case-01.md`, Revision TC01-R1

## Ergebnis und Aussagegrenze

Die Produktspezifikation wurde vollständig gelesen und unverändert angewendet. Der einzige gewählte Recherchefall ist die angekündigte Einführung des österreichweiten KlimaTickets 2021. Die entscheidenden Primärquellen konnten wegen Proxy-403 nicht gelesen werden. Das Ergebnis lautet deshalb **nicht überprüfbar**, nicht „nicht erfüllt“.

**Der empirische Stresstest ist noch nicht abgeschlossen.** Die nachfolgenden Befunde stammen aus der versuchten Fallabbildung und der Spezifikationsprüfung. Sie sind keine Erkenntnisse aus bereits verifizierten politischen Handlungen. Der Fall hat die Regeln zum Umgang mit fehlender Evidenz beansprucht; die Abgrenzung von „erfüllt“, „teilweise erfüllt“ und „gegenteilig gehandelt“ wurde noch nicht an realer Evidenz validiert.

Es wurde weder Anwendungscode geschrieben noch `product-spec.md` verändert. Die Vorschläge unten müssen vor Übernahme geprüft und beschlossen werden.

## 1. Informationen, die noch nicht sauber modelliert sind

| Befund aus der Fallabbildung | Konkreter Vorschlag | Priorität |
| --- | --- | --- |
| Ein Recherchekandidat ist noch kein gesichertes Versprechen. Derzeit können unbekannte Angaben markiert werden, aber der verbindliche Status der Prüfthese/Kriterien ist nicht explizit. | Recherche-/Fallstatus ergänzen: Kandidat, Original gesichert, Kriterien bestätigt, Evidenz geprüft, bewertet. Kriterienrevision mit Bestätigungszeitpunkt und bestätigendem Menschen referenzieren. | Vor Datenmodell-Implementierung klären. |
| Nicht zugängliche Webseiten, Suchabfragen und unerfüllte Rechercheaufträge sind keine Quellen mit belegenden Fundstellen. Ein allgemeines Prüfprotokoll ist dafür nur grob spezifiziert. | Strukturierte Rechercheeinträge vorsehen: Ziel/Abfrage, Zeitpunkt, Zugriffsergebnis, technische Fehlerart, zu prüfendes Kriterium, nächster Schritt. Verknüpfung als Evidenz erst mit tatsächlicher Fundstelle erlauben. | Vor Implementierung klären. |
| Aussagedatum, Ereignisdatum, Publikationsdatum, Abrufdatum und rechtlicher/tariflicher Gültigkeitsbeginn können voneinander abweichen. „Datum“ beim Handlungsobjekt ist dafür nicht eindeutig. | Datumsrollen benennen; Präzision und unbekannte Werte strukturiert speichern. Gültigkeitsintervalle bei Tarifen/Regeln sowie Zeitzone bei Tagesfristen vorsehen. Kein künstlich genaues Datum. | Vor Implementierung klären. |
| Eine heutige offizielle Webseite beweist nicht automatisch einen historischen Preis. Die Quelle besitzt zwar Abrufdatum/Hash, aber historische Fassungen und deren Bezugszeit sind nicht explizit verknüpft. | Quelle von konkreter Quellenversion trennen; Fundstellen auf genau eine Version beziehen. Historische Gültigkeit, Archivherkunft und Original-URL erfassen. Ein einfacher lokaler Versionsdatensatz genügt; kein Archivdienst nötig. | Vor Implementierung klären. |
| „Nicht überprüfbar“ kann Originalmangel, offene Frist, fehlende Evidenz oder unklare Zurechnung bedeuten. Das Freitextfeld verhindert vergleichbare Filter und Fortschrittsanzeigen. | Kategorie unverändert lassen; strukturierte Grundcodes plus Pflichtbegründung ergänzen. Technische Rechercheblockade gesondert kennzeichnen. | Vor Implementierung klären. |
| Die Methodikversion wird verlangt, aber die aktuelle Spezifikation besitzt keine Versionskennung. Ein Datei-Hash ersetzt keine inhaltlich benannte Regelversion. | Explizite Methodik-ID und Versionsnummer einführen; Bewertungen binden Fall-, Kriterien- und Methodikrevision. | Vor Implementierung klären. |

Für unbekannte Angaben sollte mindestens „unbekannt“, „nicht verifiziert“ und „nicht anwendbar“ unterschieden werden. Ein vermuteter Sprecher ist etwas anderes als ein bestätigter Sprecher ohne bekanntes Aussagedatum. Diese Unterscheidung ist beim gewählten Fall bereits erforderlich.

## 2. Redundanzen und notwendige Abgrenzungen

- Frist, Bedingungen und Umfang stehen sowohl beim Versprechen als auch bei Kriterien. Das ist sinnvoll, wenn beim Versprechen die Originalbedeutung und beim Kriterium die operationalisierte Prüfbedeutung gespeichert wird. Diese Zuständigkeit muss explizit werden; Änderungen dürfen sich nicht automatisch gegenseitig überschreiben.
- Quellen-/Fundstellenreferenzen stehen bei Versprechen, Handlung und Evidenz. Sie sollten gemeinsame IDs referenzieren, nicht separate Kopien desselben Zitats erzeugen. Eine Fundstelle kann Originalwortlaut belegen und zugleich für Kontext relevant sein.
- Begründungen beim Evidenzlink und bei der Bewertung sind unterschiedlich: Der Link erklärt die Beziehung eines konkreten Belegs, die Bewertung die Zusammenschau. Keine Streichung empfohlen.
- „Wirkung/Umfang“ bei Handlungen darf keine unbewiesene kausale Wirkung erzwingen. Unbekannt muss zulässig bleiben. Ein dokumentierter Tarif ist keine Messung der tatsächlichen Nutzung.
- Numerische Gewichte sind für diesen Fall unnötig. Gleichwertige notwendige Kernkriterien lassen sich ohne Zahlen ausdrücken. Das optionale Gewicht sollte nicht zu Pflicht-Scheingenauigkeit führen.

Es ist bislang kein Feld anhand vollständig geprüfter realer Evidenz als generell unnötig nachgewiesen.

## 3. Beziehungen und Kardinalitäten

Die konzeptionellen Beziehungen sind plausibel, aber noch nicht hinreichend präzise für ein verbindliches Persistenzmodell:

1. Versprechen → mehrere versionierte Kriterien; Originalzitat → konkrete Fundstelle einer Quellenversion. Eine bloße URL ist kein Ersatz.
2. Handlung → ein oder mehrere beteiligte Akteure mit jeweiliger Rolle. Eine nationale Einführung kann institutionell mehrere Beteiligte haben; das ist in diesem Fall noch zu ermitteln, keine festgestellte politische Zurechnung.
3. Evidenzlink → genau ein Kriterium einer bestimmten Revision und mindestens eine Fundstelle; optional eine Handlung. „Handlung/Fundstelle“ muss als Schema präzisiert werden, damit kein fundstellenloser Handlungseintrag als Beweis gilt.
4. Gemeinsame Ursprungsquelle → referenzierte Herkunftsgruppe oder andere Quelle, statt nur unstrukturierter Text. Mehrfachpublikation darf nicht als unabhängige Bestätigung zählen.
5. Bewertung → unveränderliche Fallrevision und explizite Kriterienrevision; jede Kriterienbewertung besitzt eigene Begründung, Fundstellenreferenzen und Sicherheit.

Diese Regeln sollten vor Implementierung als kleines Entity-/Relationsschema festgelegt werden. Ein einzelner lokaler Datenspeicher reicht weiterhin aus.

## 4. Reproduzierbarkeit der Bewertung

**Für den aktuellen Recherchestand eindeutig:** Die entscheidende Originalquelle fehlt. Nach Abschnitt 4 verhindert dies ein abschließendes inhaltliches Urteil; „nicht überprüfbar“ ist reproduzierbar, wenn die Gründe sichtbar bleiben.

**Für einen später vollständig belegten Fall noch offen:**

- Was bedeutet „Start“ im Original: Verkauf, erste Gültigkeit oder politische Einführung? Die Prüfthese darf diese Begriffe nicht zusammenziehen. Erst der Wortlaut entscheidet, ob K01 aufgeteilt werden muss.
- Welcher Geltungsumfang wurde tatsächlich zugesagt? Ein bundesweit geltendes Angebot verspricht nicht automatisch ausnahmslose Geltung in jedem Verkehrsmittel. Ausnahmen müssen vor der Einstufung eingeordnet werden.
- Ist ein Einführungspreis oder regulärer Tarif gemeint? Die Originalaussage und zeitgenössische Bedingungen müssen den Preismaßstab festlegen.
- Die Spezifikation verlangt Kriterien vor der Bewertung, definiert jedoch noch keinen verbindlichen Freeze und kein Verfahren bei später entdeckten Bedingungen. Vorschlag: neue Kriterienrevision, Änderungsgrund und erneute Prüfung aller betroffenen Bewertungen.
- „Wesentlich“, „untergeordnet“ und „substanziell“ haben keine fallbezogene Entscheidungsregel. Vorschlag: Materialitätsregel bei der Kriterienbestätigung dokumentieren; keine neuen universellen Prozentgrenzen.
- Das Verhältnis von direktem Widerspruch, späterer Korrektur und schließlich erreichtem Ergebnis braucht zeitbezogene Beispiele. Die vorhandene Vorrangregel nicht ungeprüft ändern; nach verfügbarer Evidenz prüfen, ob sie für diesen Fall überhaupt relevant wird.
- Der Stichtag betrifft Ereignisse, nicht zwingend Publikations- oder Abrufdaten. Eine nachträgliche Quelle über einen historischen Sachverhalt muss möglich bleiben, mit sichtbarer Rückschau. Das ist eine Präzisierung der Datenrollen, keine Erlaubnis, spätere Handlungen vorzuziehen.

Ein tatsächlicher Reproduzierbarkeitstest braucht eine zweite menschliche Bewertung derselben gesicherten Fallrevision. Diese Prüfung wurde noch nicht durchgeführt. Ein anonymisierter Parteienwechsel kann die Identitätsneutralität kontrollieren, ersetzt aber keine Prüfung der Evidenz und Kriterien.

## 5. Menschliche Interpretation und Grenzen der Automatisierung

Bereits menschlich zu bestätigen sind Auswahl und Eingrenzung des Kandidaten, die Bedeutung von „österreichweit“, die Fristinterpretation und die Abgrenzung regulärer von ermäßigten Preisen. In dieser Sitzung stammen sie aus KI-Vorschlägen und besitzen noch keine menschliche Freigabe.

Ein LLM darf später insbesondere **nicht allein**:

- Eine erfolglose Recherche in eine negative politische Feststellung verwandeln.
- Vermuteten Wortlaut, Sprecher oder Datum als bestätigte Daten übernehmen.
- Aus aktuellen Tarifseiten historische Verhältnisse ableiten oder Ankündigungen mit Umsetzung gleichsetzen.
- Bedingungen, Kernkriterien oder Materialität nach Sichtung des gewünschten Ergebnisses umdefinieren.
- Gesamturteil freigeben, kausale Verantwortlichkeit zuschreiben oder Täuschungsabsicht behaupten.

Automatisierbar sind Vollständigkeitsprüfungen, Referenzintegrität, Versionsbindung, Hinweise auf Datumsprobleme und das Markieren unbelegter Aussagen. Ob eine Quelle eine Behauptung tatsächlich trägt, bleibt eine fachliche Entscheidung.

## 6. Technisch erzwingbare Validierungsregeln

| Regel | Softwareverhalten |
| --- | --- |
| Originalzitat muss eine vorhandene Fundstelle einer Quellenversion referenzieren. | Ohne bestätigten Originalbeleg nur Kandidatenstatus; keine Freigabe. |
| Unbekannte Pflichtfelder benötigen Status und Grund. | Keine stillen Leerwerte oder geschätzten Daten als bestätigte Angaben. |
| Kriterienbestätigung geht verbindlicher Bewertung voraus. | Bestätigende Person, Zeitpunkt und Kriterienrevision verlangen; alte Urteile bei Kriterienänderung erneut prüfbedürftig markieren. |
| Rechercheaufträge und Zugriffsfehler sind keine Evidenz. | Keine unterstützende/widersprechende Evidenzverknüpfung ohne geprüfte Fundstelle. |
| Evidenzlink referenziert existierendes Kriterium und konkrete Fundstellen. | Fremdschlüssel und Versionszugehörigkeit prüfen; Direktheit/Beziehung mit Begründung verlangen. |
| Negative Einstufung erfordert belastbare Evidenz, keine bloße Leermenge. | Belegreferenzen und menschliche Begründung verlangen; tatsächliche Aussagekraft kann Software nicht garantieren. |
| Niedrige Sicherheit erlaubt kein abschließendes negatives Gesamturteil. | Freigabe gemäß bestehender Regel blockieren; „nicht überprüfbar“ mit Grund zulassen. |
| Spätere Ereignisse dürfen historische Bewertungen nicht begründen. | Ereignis-/Gültigkeitsdatum gegen Stichtag prüfen; spätere Veröffentlichung allein nicht pauschal ablehnen. Unbekannte Zeitbezüge zur Prüfung vorlegen. |
| Neue relevante Belege können Freigaben überholen. | Betroffene Bewertung/Skript markieren; keine stillschweigende automatische Neubewertung. |
| KI ist kein menschlicher Prüfer. | Urheber und Freigebenden getrennt speichern; für Freigabe menschliche Bestätigung verlangen. |

Bei einem „nicht überprüfbar“-Befund muss die Software unterscheiden können zwischen einer bestätigten Recherchelücke und einem bestätigten Originalversprechen. Im aktuellen Fall wäre die Fallbeschreibung noch nicht publikationsreif, selbst wenn die Kategorie korrekt angewendet wird.

## 7. Offene Voraussetzungen und Empfehlung

**Noch nicht bereit für die verbindliche Implementierung des Datenmodells.** Das Grundmodell ist tragfähig, aber Kandidaten-/Prüfstatus, Quellenfassungen, Datumsrollen, Kriterienrevisionen und Evidenzkardinalitäten müssen konkretisiert werden. Dafür sind keine Microservices und kein größerer Technologieentscheid nötig.

Zuerst die Originalankündigung und zeitgenössischen offiziellen Belege beschaffen, die Fallakte vervollständigen und menschlich prüfen. Anschließend die hier vorgeschlagenen Modellpräzisierungen anhand derselben Akte bestätigen oder verwerfen. Die bestehende Methodik bleibt bis dahin unverändert. Weder das reale Fallurteil noch die empirische Validierung dürfen als abgeschlossen dargestellt werden.
