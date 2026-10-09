# Evidence Source Policy v1

Ressource: `Sources/PoliticalFactCheckResearch/Resources/evidence-source-policy-v1.json`; Version `evidence-source-policy-v1`. Die unveränderte Discovery-Policy bleibt ein eigener Vertrag. Beide Policy-Snapshots werden im DeepResearchRecordV1 erhalten.

| Domain | Provenienzkategorie |
| --- | --- |
| parlament.gv.at | parliament |
| ris.bka.gv.at | lawOrRegulation |
| bundeskanzleramt.gv.at | government |
| oesterreich.gv.at | publicAdministration |
| rechnungshof.gv.at | auditInstitution |
| statistik.at | officialStatistics |
| gv.at einschließlich echter Subdomains | otherOfficialPrimary |
| Originaldomain des Kandidaten | originalPromiseSource |
| offizielle Parteidomains aus Discovery-Policy | officialPartySource |

Original-URL, spezifische Domainklassifizierung und breite `gv.at`-Regel werden getrennt behandelt. Bei gleichzeitiger Übereinstimmung gewinnt die spezifische Domain vor gv.at; die genaue Original-URL wird als originalPromiseSource kenntlich gemacht. Die vollständige Originaldomain und die konfigurierten Parteidomains werden zum Filter hinzugefügt. Alle Lanes eines Cases erhalten exakt denselben Filter. Punktgrenzen verhindern ähnliche Domainnamen/Suffix-Tricks. Es wird keine politische Zuständigkeit aus Ministeriumsname, Domain oder Parteizugehörigkeit abgeleitet.

Quellen müssen aus abgeschlossenen tatsächlichen `web_search_call.action.sources` stammen, nicht allein aus Citations oder Modelltext. Quellen/Citations außerhalb der Policy werden aus der gespeicherten Liste entfernt; ein expliziter Proposal auf eine unzulässige oder unbekannte Quelle wird abgewiesen. Kategorien beschreiben Herkunft, keine Wahrheit. Die gv.at-Regel ist eine breite technische Primärquellenpräferenz, keine vollständige Domain-/Autoren-Authentifizierung.

Parteiquellen können eigene Positionen, Forderungen und dokumentierte eigene Schritte wiedergeben. Institutionelle Outcome-Vorschläge dürfen nicht allein darauf beruhen. Die technischen Assessment-Gates sind konservativ: abschließende positive und negative Vorschläge verlangen mindestens eine institutionelle Quelle im relevanten Support bzw. Contra. Das kann auch zulässige parteieigene Handlungen zunächst ohne Empfehlung lassen; die Redaktion kann sie später gesondert prüfen. Ein Quellenbadge ist keine Verifikation und ersetzt weder Wortlaut-/Kontextprüfung noch Zuständigkeitsprüfung.

SUPPORT, CONTRADICTION und CONTEXT haben gleiche Tool-, Zeit-, Ergebnis- und Tokenbudgets. Fehlende Treffer werden weder als Erfolg noch als Misserfolg gewertet. Keine Partei- oder Kontroversitätsfaktoren. Vollständige Suchabdeckung ist nicht garantiert; Quellenlisten können mehrere Dokumente derselben Ursprungsinformation enthalten. Keine automatische Unabhängigkeitsbehauptung.
