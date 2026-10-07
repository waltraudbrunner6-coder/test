# Domain Model: Beziehungen

Status: Spezifikationsentwurf · 7. Oktober 2026

## Aggregate-Übersicht

```text
Case (Aggregate Root)
├── Promise (stabile Identität)
│   ├── PromiseRevision (unveränderlicher Aussage-/Kontextstand)
│   │   └── SourceExcerpt ── SourceVersion ── Source
│   └── EvaluationCriterion (stabile Kriterienidentität)
│       └── CriterionRevision (unveränderliche Prüfmesslatte; draft/confirmed)
│           └── EvidenceLink (genau eine CriterionRevision)
│               ├── SourceExcerpt (mindestens eine verifizierte Fundstelle)
│               └── ActionRevision (optional)
├── ActionOrDevelopment (stabile Identität)
│   └── ActionRevision (unveränderlicher Sach-/Verfahrensstand)
│       ├── ActionParticipation ── Actor
│       │   └── SourceExcerpt (Zurechnungsbeleg, sofern erforderlich)
│       └── SourceExcerpt (Beleg der Handlung/Entwicklung)
├── CaseRevision (unveränderliches Manifest der Eingaben)
│   ├── PromiseRevision
│   ├── CriterionRevision(s)
│   ├── ActionRevision(s)
│   ├── SourceVersion/Excerpt(s)
│   └── EvidenceLink(s)
├── CaseEvaluation (unveränderliches Snapshot-Urteil)
│   ├── referenziert genau eine CaseRevision
│   ├── referenziert MethodologyVersion
│   └── CriterionEvaluation(s)
│       └── verwendet EvidenceLink(s) aus dem Snapshot
├── ScriptDraft (später; referenziert eine CaseEvaluation)
│   └── ScriptStatement(s) ── SourceExcerpt/EvidenceLink
├── ResearchTask (Recherchebedarf/-versuch, keine Evidenz)
├── ReviewerIdentity (lokale menschliche prüfende Person)
└── AuditEntry (append-only Verlaufsdatensatz)
```

Die Baumdarstellung zeigt Referenzen und ist kein Lösch-/Besitzbaum. Excerpts und Actors können von mehreren Datensätzen geteilt werden.

## Kardinalitäten und verbindliche Referenzen

| Von → zu | Kardinalität | Bedeutung |
| --- | --- | --- |
| Case → Promise | 1:1 im MVP | Ein Case prüft ein einzelnes Versprechen. |
| Promise → PromiseRevision | 1:N | Jede fachliche Korrektur/Präzisierung schafft Revision; die alte bleibt lesbar. |
| Promise → EvaluationCriterion → CriterionRevision | 1:N:N | Kriterienidentität bleibt stabil; jede Prüfmesslatte ist ein eigener unveränderlicher Stand. |
| Source → SourceVersion → SourceExcerpt | 1:N:N | Logische Quelle, beobachtete Inhaltsfassung und exakte Fundstelle sind getrennt. Kein Excerpt kann direkt nur auf eine URL zeigen. |
| ActionOrDevelopment → ActionRevision | 1:N | Handlung und Verfahrensstatus sind versioniert, nicht als veränderliche historische Tatsache überschrieben. |
| PromiseRevision → Actor | N:1 je Sprecher/Partei, jeweils optional bei explizit unbekannt | Aussageakteur und Parteizuordnung zum Aussagezeitpunkt; Quellenbeleg referenzieren. |
| Actor → ActorAffiliation | 1:N | Zeitgebundene Rollen/Zugehörigkeiten samt Belegstatus. |
| ActionRevision → ActionParticipation | 1:N | Jede Beteiligung nennt Akteur, Rolle und Beteiligungsart. Zurechnungsbeleg wird direkt referenziert, sofern erforderlich. |
| CriterionRevision → EvidenceLink | 1:N | Jeder Link gehört genau zu einer konkreten Revision, nie bloß zum veränderlichen Kriterium. |
| EvidenceLink → SourceExcerpt | N:M | Link hat mindestens eine verifizierte Fundstelle; Excerpt darf in mehreren Links wiederverwendet werden. |
| EvidenceLink → ActionRevision | N:0..1 | Eine Handlung kann Kontext sein, bleibt aber ohne SourceExcerpt keine Evidenz. |
| Case → CaseRevision | 1:N | Jede Evaluation arbeitet auf einem eingefrorenen Manifest aus stabilen Revisions-IDs. |
| CaseRevision → ResearchTask | N:M | Manifest hält offene Rechercheaufträge und damaligen Taskstatus als Kontext fest; Tasks bleiben keine Evidenz. |
| CaseRevision → CaseEvaluation | 1:N | Ein Snapshot kann zu mehreren Stichtagen bewertet werden; jedes Urteil bleibt separat. |
| CaseEvaluation → CriterionEvaluation | 1:N | Pro verwendeter CriterionRevision gibt es ein Kriteriumsergebnis; die verwendeten Kriterienrevisionen sind daraus ableitbar. |
| CriterionEvaluation → EvidenceLink | N:M | Begründung nutzt geprüfte Links des referenzierten Snapshots; Gegenbelege bleiben sichtbar. |
| CaseEvaluation → MethodologyVersion | N:1 | Bewertung benennt den exakt angewandten Regelstand. |
| CaseEvaluation → ScriptDraft | 1:N | Skriptfassungen sind an ein konkretes Urteil gebunden. |
| ScriptDraft → ScriptStatement → SourceExcerpt/EvidenceLink | 1:N:N | Tatsachensätze referenzieren überprüfbare Fundstellen; Interpretation wird typisiert. |
| Case → ReviewerIdentity | 0..N Referenzen | Eine lokale menschliche Person prüft und gibt frei; getrennt von politischen Actor-Datensätzen. |
| Case → ResearchTask/AuditEntry | 1:N | Aufgaben und Verlauf gehören zum Case, sind niemals EvidenceLink-Belege. |

## Referenz- und Abhängigkeitsregeln

- CaseRevision ist ein Manifest aus IDs, kein duplizierter veränderlicher Fall. Es enthält keine Evaluation und erzeugt daher keinen Zyklus.
- EvidenceLink verweist auf CriterionRevision und Fundstelle, optional auf ActionRevision. ActionRevision verweist nicht zurück auf EvidenceLink.
- CriterionEvaluation gehört zu genau einer CaseEvaluation. CaseEvaluation wiederum referenziert CaseRevision, nicht umgekehrt.
- Eine Änderung/Neurevision markiert abhängige freigegebene Evaluationen als erneut prüfbedürftig. Der historische Snapshot behält unveränderte IDs und damalige Entscheidung.
- Quelldateien sind externe, lokal verwaltete Assets; SourceVersion hält Datei-Referenz und Hash. SwiftData enthält Metadaten und Beziehungen, keine großen Binärdateien.
- IDs der gelöschten/archivierten Akteure, Sources und Excerpts dürfen nicht still verschwinden, wenn ein Snapshot sie referenziert.

## Bewusst nicht modelliert

- Kein globales Partei-Ranking oder einzelner Score.
- Keine direkte Beziehung von ResearchTask zu CriterionEvaluation oder CaseEvaluation.
- Keine direkte Beziehung `Action.actor`; Beteiligung ist eine eigene ActionParticipation mit Rolle und Belegbarkeit.
- Keine duplizierten Quellentexte je Versprechen, Handlung, Bewertung und Skript.
- Keine bidirektionalen Fachzyklen zwischen Fallmanifest, Bewertung und Evidenz.
