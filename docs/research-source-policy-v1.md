# Quellenpolitik research-source-policy-v1

Verbindliche maschinenlesbare Fassung: `Sources/PoliticalFactCheckResearch/Resources/research-source-policy-v1.json`. Die geladene Policy wird pro Kandidat mitgespeichert; spätere Ressourcenänderungen ändern alte Recherchemetadaten nicht.

| Gruppe | Erlaubte Domains | Kategorie |
| --- | --- | --- |
| party-1 | oevp.at | offizielle Parteiquelle |
| party-2 | spoe.at | offizielle Parteiquelle |
| party-3 | fpoe.at | offizielle Parteiquelle |
| party-4 | neos.eu | offizielle Parteiquelle |
| party-5 | gruene.at | offizielle Parteiquelle |
| institutional | parlament.gv.at; ris.bka.gv.at; bundeskanzleramt.gv.at; oesterreich.gv.at | Parlament; RIS; Bundesregierung; Verwaltungsportal |

Diese Domains sind ausschließlich technische Recherchekonfiguration, keine Wertung. Subdomains gelten nur an einer echten Punktgrenze. Ähnliche Domains, Suffix-Erweiterungen und URLs mit Zugangsdaten sind ausgeschlossen. Primärquellenpräferenz bedeutet nicht automatisch Originalität oder Verifikation: Auch offizielle Webseiten können fremde Aussagen wiedergeben.

Alle fünf Parteigruppen erhalten denselben Prompt, dieselbe Suchvorlage, denselben Altersfilter und dasselbe Budget: maximal zwei Kandidaten (konfigurierbar 1–5), maximal drei Tool-Aufrufe, 8192 Output-Tokens, 120 Sekunden pro Request. Die institutionelle Gruppe erhält dasselbe Request-Budget, nicht vier separate Kandidatenquoten. Suchvorlage: `politisches Versprechen Ankündigung Wahlprogramm konkretes Ziel Frist Österreich`. Nur erlaubte Domains unterscheiden die Requests; keine parteispezifischen Kontroversen oder gewünschten Urteile werden vorgegeben. OpenAI formuliert die tatsächlichen Queries selbst; eine identische Trefferzahl oder vollständige Berücksichtigung aller Quellen ist nicht garantiert. Null Treffer ist zulässig.

Die Auswahl verlangt einen konkreten Zielzustand, beobachtbares Ergebnis, Originalversprechen statt Bericht/Meinung, nachvollziehbare Quelle und Fundstelle. Diese inhaltlichen Angaben bleiben KI-Extraktionsbehauptungen. Mindestalter standardmäßig 180 Tage; eine abgelaufene Frist kann ein jüngeres Versprechen zulassen. Unbekanntes Aussagedatum bleibt unbekannt mit Unsicherheit und niedrigerem Prüfbarkeitsscore. Keine Neuigkeiten oder allgemeinen Werteversprechen als Ersatz zur Quotenfüllung.

Eine Kandidaten-URL muss sowohl in den tatsächlichen `web_search_call.action.sources` als auch im Domainfilter ihrer Gruppe liegen. URL-Citation-Annotations werden separat erfasst; sie ersetzen den Search-Sources-Nachweis nicht. Suchquellen werden mit stabiler `WEB-n`-Kennung pro Gruppenantwort, kanonischer URL, gegebenenfalls tatsächlichem Titel, Domain, Recherchezeitpunkt, Policy-Version und Kategorie gespeichert. Extrahierter Dokumenttitel bleibt davon getrennt. Suchnachweis belegt weder Zitatrichtigkeit noch Authentizität, Attribution oder Erfüllung.

Keine Partei-Rankings, keine Gewichtung nach Parteinamen, Empörung, Kontroversität oder vermuteter Diskrepanz. Eine neue Policy benötigt eine neue Versionskennung. Grenzen: Suchindex, Dokumentzugang, Sprache, Modellselektion und getrennte Budgets können die realen Funde verzerren; gleiche Regeln sind keine Garantie gleicher Abdeckung.
