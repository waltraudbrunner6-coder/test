import Foundation
import PoliticalFactCheckCore

public enum CaseResearchDraftMapper {
    public static let taskGoal = "Automatische Evidenzrecherche und Bewertungsentwurf"
    public static func dossier(in graph: DomainContext) throws -> DeepResearchRecordV1? {
        let tasks = graph.researchTasks.filter { $0.goal.value == taskGoal }
        guard tasks.count <= 1 else { throw CaseResearchError.invalidStoredRecord }
        guard let task = tasks.first else { return nil }
        guard let text = task.result else { throw CaseResearchError.invalidStoredRecord }
        let record = try DeepResearchRecordV1.decode(text)
        guard record.caseID == graph.cases.first?.id.rawValue, let b = record.bindings else { throw CaseResearchError.invalidStoredRecord }
        guard Set(b.criterionRevisions.keys) == Set(record.result.proposedCriteria.map { $0.criterionKey }),
              Set(b.sources.keys) == Set(record.result.sources.map { $0.claim.sourceKey }), Set(b.sourceVersions.keys) == Set(b.sources.keys),
              Set(b.excerpts.keys) == Set(record.result.excerpts.map { $0.excerptKey }),
              Set(b.actionRevisions.keys) == Set(record.result.developments.map { $0.developmentKey }),
              Set(b.evidenceLinks.keys) == Set(record.result.evidenceProposals.map { $0.evidenceKey }) else { throw CaseResearchError.invalidStoredRecord }
        for (key, id) in b.criterionRevisions {
            guard let c = graph.find(EntityID<CriterionRevision>(id)), c.promiseRevisionID.rawValue == record.promiseRevisionID,
                  c.goal.value == record.result.proposedCriteria.first(where: { $0.criterionKey == key })?.goal else { throw CaseResearchError.invalidStoredRecord }
        }
        for (key, id) in b.sourceVersions { guard let v = graph.find(EntityID<SourceVersion>(id)), v.sourceID.rawValue == b.sources[key] else { throw CaseResearchError.invalidStoredRecord } }
        for (key, id) in b.excerpts {
            guard let excerpt = graph.find(EntityID<SourceExcerpt>(id)), let proposed = record.result.excerpts.first(where: { $0.excerptKey == key }),
                  excerpt.sourceVersionID.rawValue == b.sourceVersions[proposed.sourceKey] else { throw CaseResearchError.invalidStoredRecord }
        }
        for id in b.actionRevisions.values { guard graph.find(EntityID<ActionRevision>(id)) != nil else { throw CaseResearchError.invalidStoredRecord } }
        for (key, id) in b.evidenceLinks {
            guard let e = graph.find(EntityID<EvidenceLink>(id)), let proposed = record.result.evidenceProposals.first(where: { $0.evidenceKey == key }),
                  e.criterionRevisionID.rawValue == b.criterionRevisions[proposed.criterionKey],
                  Set(e.excerptIDs.map { $0.rawValue }) == Set(proposed.excerptKeys.compactMap { b.excerpts[$0] }) else { throw CaseResearchError.invalidStoredRecord }
        }
        return record
    }
    public static func adding(_ record: DeepResearchRecordV1, to graph: DomainContext) throws -> DomainContext {
        let request = record.request; try CaseResearchValidation.validate(record.result, request: request)
        guard record.formatVersion == 1, !record.provider.isEmpty, record.model == record.provider, graph.cases.count == 1, let root = graph.cases.first, root.workflowState == .candidate,
              root.id == request.caseID, root.currentPromiseRevisionID == request.promiseRevisionID,
              let item = try DiscoveryCandidateMapper.inboxItem(in: graph), item.record == record.discovery,
              graph.find(root.currentPromiseRevisionID)?.quote.content.knownValue?.value == record.discovery.candidate.exactQuote else { throw CaseResearchError.staleCandidate }
        if try dossier(in: graph) != nil { throw CaseResearchError.alreadyResearched }
        let result = record.result, now = result.completedAt
        let author = Authorship.ai(model: try NonEmptyText(record.model), templateVersion: result.promptVersion)
        func metadata() throws -> RevisionMetadata { RevisionMetadata(number: 1, reason: try NonEmptyText("Ungeprüfter automatischer Rechercheentwurf"), author: author, createdAt: now) }
        var criteria = graph.criteria, revisions = graph.criterionRevisions, sources = graph.sources, versions = graph.sourceVersions, excerpts = graph.excerpts
        var actions = graph.actions, actionRevisions = graph.actionRevisions, links = graph.evidenceLinks, audits = graph.auditEntries
        var criterionIDs: [String: EntityID<CriterionRevision>] = [:], sourceIDs: [String: EntityID<Source>] = [:], versionIDs: [String: EntityID<SourceVersion>] = [:]
        var excerptIDs: [String: EntityID<SourceExcerpt>] = [:], actionIDs: [String: EntityID<ActionRevision>] = [:], linkIDs: [String: EntityID<EvidenceLink>] = [:]
        func audit<T>(_ id: EntityID<T>, kind: EntityKind, operation: String) throws {
            audits.append(AuditEntry(caseID: root.id, target: ObjectReference(kind: kind, id: id), operation: try NonEmptyText(operation), author: author,
                occurredAt: now, reason: try NonEmptyText("KI-Recherche – ungeprüft; keine menschliche Freigabe")))
        }
        for c in result.proposedCriteria {
            let id = EntityID<EvaluationCriterion>(), revisionID = EntityID<CriterionRevision>()
            let revision = CriterionRevision(id: revisionID, criterionID: id, promiseRevisionID: root.currentPromiseRevisionID, goal: try NonEmptyText(c.goal),
                targetGroup: try NonEmptyText(c.targetGroup ?? "Unbekannt: Zielgruppe in der KI-Recherche nicht bestimmbar"),
                baseline: try c.baseline.map { .known(try NonEmptyText($0)) } ?? .unknown(reason: NonEmptyText("Ausgangslage unbekannt")),
                deadline: try DiscoveryDates.value(c.deadline, role: .deadline),
                conditions: try c.conditions.map { .known(try $0.map { try NonEmptyText($0) }) } ?? .unknown(reason: NonEmptyText("Bedingungen unbekannt")),
                isCore: c.isCore, materialityRule: try NonEmptyText(c.materialityRule), metadata: try metadata())
            criteria.append(EvaluationCriterion(id: id, promiseID: root.promiseID, currentRevisionID: revisionID, createdAt: now))
            revisions.append(revision); criterionIDs[c.criterionKey] = revisionID; try audit(revisionID, kind: .criterionRevision, operation: "researchDraftCriterion")
        }
        var observedVersions: [String: EntityID<SourceVersion>] = [:]
        for s in result.sources {
            let url = try DiscoveryIdentity.canonicalURL(s.claim.url)
            let existing = sources.first { (try? $0.canonicalURL.map { try DiscoveryIdentity.canonicalURL($0.absoluteString) }) == url }
            let source: Source
            if let existing { source = existing }
            else { source = Source(canonicalURL: URL(string: url), createdAt: now); sources.append(source); try audit(source.id, kind: .source, operation: "researchDraftSource") }
            let versionID: EntityID<SourceVersion>
            if let observed = observedVersions[url] { versionID = observed }
            else if let reusable = versions.first(where: { $0.sourceID == source.id && $0.verification == .unreviewed && $0.kind == .unknown && $0.hash == nil && $0.localCopyReference == nil }) {
                // Reuse an unverified observation anchor; enrichments remain in the dossier, never overwrite old metadata.
                versionID = reusable.id; observedVersions[url] = reusable.id
            } else {
                let v = SourceVersion(sourceID: source.id, requestedURL: URL(string: url), title: try s.claim.title.map { try NonEmptyText($0) },
                    publisher: try s.claim.publisher.map { try NonEmptyText($0) }, author: try s.claim.author.map { try NonEmptyText($0) },
                    publicationDate: try DiscoveryDates.value(s.claim.publicationDate, role: .publication), retrievedAt: try .instant(result.startedAt, role: .retrieval),
                    eventDate: try s.claim.eventDate.map { try DiscoveryDates.value($0, role: .event) },
                    contentType: try NonEmptyText(s.claim.contentType ?? "unknown"), language: try NonEmptyText(s.claim.language ?? "unknown"))
                versions.append(v); versionID = v.id; observedVersions[url] = v.id; try audit(v.id, kind: .sourceVersion, operation: "researchDraftSourceVersion")
            }
            sourceIDs[s.claim.sourceKey] = source.id; versionIDs[s.claim.sourceKey] = versionID
        }
        for e in result.excerpts {
            guard let versionID = versionIDs[e.sourceKey] else { throw CaseResearchError.invalidReference }
            if let existing = excerpts.first(where: { $0.sourceVersionID == versionID && $0.locator.value == e.locator && DiscoveryIdentity.normalizedQuote($0.text.value) == DiscoveryIdentity.normalizedQuote(e.text) }) { excerptIDs[e.excerptKey] = existing.id; continue }
            let excerpt = SourceExcerpt(sourceVersionID: versionID, locator: try NonEmptyText(e.locator), text: try NonEmptyText(e.text), context: try NonEmptyText(e.context),
                language: try NonEmptyText(e.language), provenance: .aiExtracted, createdAt: now)
            excerpts.append(excerpt); excerptIDs[e.excerptKey] = excerpt.id; try audit(excerpt.id, kind: .excerpt, operation: "researchDraftExcerpt")
        }
        func refs(_ keys: [String]) throws -> [EntityID<SourceExcerpt>] {
            var seen = Set<EntityID<SourceExcerpt>>()
            return try keys.map { key in guard let id = excerptIDs[key] else { throw CaseResearchError.invalidReference }; return id }.filter { seen.insert($0).inserted }
        }
        func asserted<T>(_ value: FieldValue<T>, refs: [EntityID<SourceExcerpt>]) throws -> AssertedValue<T> { try AssertedValue(content: value, provenance: .aiExtracted, excerptIDs: refs) }
        for d in result.developments {
            let id = EntityID<ActionOrDevelopment>(), revisionID = EntityID<ActionRevision>(), ids = try refs(d.excerptKeys)
            let revision = ActionRevision(id: revisionID, actionID: id, type: d.type.domain, title: try NonEmptyText(d.title),
                description: try asserted(.known(NonEmptyText(d.description)), refs: ids), eventDate: try asserted(.known(DiscoveryDates.value(d.eventDate, role: .event)), refs: ids),
                proceduralState: try NonEmptyText(d.proceduralState), scope: try asserted(d.scope.map { .known(try NonEmptyText($0)) } ?? .unknown(reason: NonEmptyText("Umfang unbekannt")), refs: ids),
                excerptIDs: ids, metadata: try metadata())
            actions.append(ActionOrDevelopment(id: id, caseID: root.id, currentRevisionID: revisionID, createdAt: now)); actionRevisions.append(revision)
            actionIDs[d.developmentKey] = revisionID; try audit(revisionID, kind: .actionRevision, operation: "researchDraftAction")
        }
        for e in result.evidenceProposals {
            guard let criterionID = criterionIDs[e.criterionKey] else { throw CaseResearchError.invalidReference }
            let link = EvidenceLink(criterionRevisionID: criterionID, excerptIDs: try refs(e.excerptKeys), actionRevisionID: e.developmentKey.flatMap { actionIDs[$0] },
                relationship: e.relationship.domain, directness: e.directness.domain, rationale: try NonEmptyText(e.rationale),
                temporalReference: try DiscoveryDates.value(e.temporalDate, role: e.temporalRole == .event ? .event : .validity), metadata: try metadata())
            links.append(link); linkIDs[e.evidenceKey] = link.id; try audit(link.id, kind: .evidenceLink, operation: "researchDraftEvidence")
        }
        let bindings = ResearchDomainBindings(criterionRevisions: criterionIDs.mapValues { $0.rawValue }, sources: sourceIDs.mapValues { $0.rawValue }, sourceVersions: versionIDs.mapValues { $0.rawValue },
            excerpts: excerptIDs.mapValues { $0.rawValue }, actionRevisions: actionIDs.mapValues { $0.rawValue }, evidenceLinks: linkIDs.mapValues { $0.rawValue })
        let stored = DeepResearchRecordV1(request: request, provider: record.provider, result: result, bindings: bindings)
        let task = ResearchTask(caseID: root.id, goal: try NonEmptyText(taskGoal), criterionRevisionIDs: Array(criterionIDs.values),
            query: "ORIGINAL; pro Kriterium symmetrisch SUPPORT/CONTRADICTION/CONTEXT; Methodology 1.0 ASSESSMENT", status: .completed, result: try stored.encode(),
            attemptedAt: result.startedAt, nextStep: "Menschliche Review-Queue: Original, Kriterien, Quellen, Handlungen, Evidenz und Bewertungsentwurf prüfen",
            sourceIDs: Array(Set(sourceIDs.values)), excerptIDs: Array(Set(excerptIDs.values)), author: author, createdAt: now)
        try audit(task.id, kind: .researchTask, operation: "researchCaseDrafts")
        let updatedRoot = PoliticalFactCheckCore.Case(id: root.id, title: root.title, promiseID: root.promiseID, currentPromiseRevisionID: root.currentPromiseRevisionID,
            activeCriterionRevisionIDs: root.activeCriterionRevisionIDs + result.proposedCriteria.compactMap { criterionIDs[$0.criterionKey] },
            currentActionRevisionIDs: root.currentActionRevisionIDs + result.developments.compactMap { actionIDs[$0.developmentKey] },
            workflowState: root.workflowState, createdAt: root.createdAt, modifiedAt: now)
        let updated = DomainContext(reviewers: graph.reviewers, cases: [updatedRoot], actors: graph.actors, affiliations: graph.affiliations,
            promises: graph.promises, promiseRevisions: graph.promiseRevisions, criteria: criteria, criterionRevisions: revisions,
            sources: sources, sourceVersions: versions, excerpts: excerpts, actions: actions, actionRevisions: actionRevisions, participations: graph.participations,
            evidenceLinks: links, caseRevisions: graph.caseRevisions, criterionEvaluations: graph.criterionEvaluations, caseEvaluations: graph.caseEvaluations,
            methodologies: graph.methodologies, researchTasks: graph.researchTasks + [task], auditEntries: audits, scripts: graph.scripts, statements: graph.statements)
        try DomainValidator.validate(updated).requireValid(); return updated
    }
}
