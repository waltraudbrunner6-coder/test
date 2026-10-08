# Methodology Version 1.0

Ab Phase 3.2b eingefrorene Bewertungsgrundlage. Kanonische Kennung: `political-fact-check/methodology/1.0`.

Diese Fassung konsolidiert wortgleich die Bewertungsmethodik und menschlichen Freigabegrenzen aus `docs/product-spec.md`, Abschnitte 4 und 5. Änderungen benötigen eine neue MethodologyVersion; diese Datei wird nicht dynamisch erzeugt oder im Bewertungsworkflow überschrieben.

## Zweck und Neutralitätsgrundsatz (Produktspezifikation 1)

Eine macOS-Anwendung unterstützt die nachvollziehbare Prüfung öffentlich dokumentierter politischer Versprechen österreichischer Parteien. Sie vergleicht die Originalaussage mit später dokumentierten Handlungen und bereitet einen journalistisch pointierten, quellentreuen Kurzvideo-Entwurf vor.

**Alle Parteien werden nach derselben Methodik geprüft.** Parteiidentität, Popularität oder eine angenommene Absicht sind keine Bewertungskriterien. Eine Abweichung belegt für sich weder Täuschung noch Unehrlichkeit. Große, gut belegte Diskrepanzen dürfen die spätere redaktionelle Fallauswahl beeinflussen; sie verändern keine Bewertungsmaßstäbe.

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

## Formale Mindestanforderungen (Produktspezifikation 3.1)

- Verifiziertes Originalzitat → konkreter SourceExcerpt → konkrete SourceVersion; kein Excerpt ohne SourceVersion.
- Jeder EvidenceLink referenziert genau eine CriterionRevision und mindestens einen verifizierten Fundstellenbeleg; ResearchTask und fundstellenlose Handlung sind ausgeschlossen.
- Keine freigegebene Evaluation ohne menschlichen Reviewer. KI ist kein Reviewer.
- „Nicht erfüllt“ verlangt belastbare, geprüfte Evidenz; eine leere Evidenzmenge reicht nie. „Gegenteilig gehandelt“ verlangt widersprechenden, geprüften Beleg. „Nicht überprüfbar“ verlangt strukturierten Grund und Begründung.
- Geänderte bestätigte Kriterien verlangen neue CriterionRevision, Änderungsgrund und menschliche Bestätigung vor Evaluation; abhängige Evaluationen werden überprüfungsbedürftig.
- Historische CaseRevisionen und Evaluationen werden nicht überschrieben. Ereignis-/Gültigkeitszeit ist gegen den Bewertungsstichtag zu prüfen, nicht pauschal das Publikationsdatum.
- Jeder freigegebene Script-Tatsachensatz verweist auf mindestens eine geprüfte Fundstelle.
- KI-Ausgaben können ungeprüfte Eingabe sein, niemals Beleg oder automatische politische Gesamtbewertung.

