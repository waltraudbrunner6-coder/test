import Foundation
import SwiftData
import PoliticalFactCheckCore

extension LocalCaseStore {
    public func addAction(caseID: EntityID<Case>, action: ActionOrDevelopment, revision: ActionRevision,
                          reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("addAction") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard action.caseID == caseID, action.currentRevisionID == revision.id, revision.actionID == action.id,
                  revision.metadata.number == 1 else { throw PersistenceError.invalidAggregate }
            guard graph.find(action.id) == nil, graph.find(revision.id) == nil else {
                throw PersistenceError.duplicateID(kind: "ActionOrDevelopment", id: action.id.rawValue)
            }
            guard revision.description.verification == .unreviewed,
                  revision.eventDate.verification == .unreviewed, revision.scope.verification == .unreviewed,
                  revision.description.review == nil, revision.eventDate.review == nil, revision.scope.review == nil,
                  revision.participationIDs.isEmpty else { throw PersistenceError.invalidValue(detail: "Neue Handlungen müssen ungeprüft sein und dürfen keine automatische Akteurszurechnung enthalten.") }
            var dto = CaseGraphDTO(graph)
            dto.actions.append(ActionOrDevelopmentDTO(action))
            dto.actionRevisions.append(ActionRevisionDTO(revision))
            dto.cases[0].currentActionRevisionIDs.append(StoredID(revision.id, kind: "ActionRevision"))
            try appendManualAudit(caseID: caseID, target: ObjectReference(kind: .actionRevision, id: revision.id),
                operation: "addAction", reason: revision.metadata.reason, reviewer: reviewer.id, at: date, to: &dto)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    /// Checks the three asserted fact fields in a new immutable revision; no attribution is inferred.
    public func verifyAction(caseID: EntityID<Case>, revisionID: EntityID<ActionRevision>,
                             excerptIDs: [EntityID<SourceExcerpt>], reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("verifyAction") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let old = graph.find(revisionID), let action = graph.find(old.actionID),
                  action.caseID == caseID, action.currentRevisionID == old.id,
                  graph.cases[0].currentActionRevisionIDs.contains(old.id) else {
                throw PersistenceError.missingEntity(kind: "ActionRevision", id: revisionID.rawValue)
            }
            guard old.participationIDs.isEmpty else {
                throw PersistenceError.invalidValue(detail: "Die Prüfung von Handlungen mit Beteiligungszuordnungen folgt in einem späteren Ausbau.")
            }
            try validateCheckedExcerpts(excerptIDs, in: graph)
            let review = HumanReview(reviewerID: reviewer.id, reviewedAt: date)
            let revised = try domainChange {
                try ActionRevision(actionID: old.actionID, type: old.type, title: old.title,
                    description: checked(old.description, excerpts: excerptIDs, review: review),
                    eventDate: checked(old.eventDate, excerpts: excerptIDs, review: review),
                    validity: old.validity, institutionalLevel: old.institutionalLevel,
                    objectIdentifier: old.objectIdentifier, proceduralState: old.proceduralState,
                    scope: checked(old.scope, excerpts: excerptIDs, review: review), excerptIDs: excerptIDs,
                    metadata: RevisionMetadata(number: old.metadata.number + 1,
                        reason: NonEmptyText("Handlungsfelder anhand ausgewählter Fundstellen menschlich geprüft"),
                        author: .human(reviewer.id), createdAt: date))
            }
            try domainChange { try DomainValidator.validate(revised, in: graph).requireValid() }
            var dto = CaseGraphDTO(graph)
            dto.actionRevisions.append(ActionRevisionDTO(revised))
            guard let index = dto.actions.firstIndex(where: { $0.id.value == action.id.rawValue }) else {
                throw PersistenceError.missingEntity(kind: "ActionOrDevelopment", id: action.id.rawValue)
            }
            dto.actions[index].currentRevisionID = StoredID(revised.id, kind: "ActionRevision")
            dto.cases[0].currentActionRevisionIDs = dto.cases[0].currentActionRevisionIDs.map {
                $0.value == old.id.rawValue ? StoredID(revised.id, kind: "ActionRevision") : $0
            }
            try appendManualAudit(caseID: caseID, target: ObjectReference(kind: .actionRevision, id: revised.id),
                operation: "verifyAction", reason: revised.metadata.reason, reviewer: reviewer.id, at: date,
                before: ObjectReference(kind: .actionRevision, id: old.id), to: &dto)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    public func addEvidenceDraft(caseID: EntityID<Case>, link: EvidenceLink,
                                 reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("addEvidenceDraft") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard link.status == .draft, link.review == nil else {
                throw PersistenceError.invalidValue(detail: "Neue Evidenz muss als ungeprüfter Draft beginnen.")
            }
            guard graph.find(link.id) == nil else { throw PersistenceError.duplicateID(kind: "EvidenceLink", id: link.id.rawValue) }
            try validateManualEvidence(link, in: graph)
            var dto = CaseGraphDTO(graph)
            dto.evidenceLinks.append(EvidenceLinkDTO(link))
            try appendManualAudit(caseID: caseID, target: ObjectReference(kind: .evidenceLink, id: link.id),
                operation: "addEvidenceDraft", reason: link.metadata.reason, reviewer: reviewer.id, at: date, to: &dto)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    public func requestEvidenceReview(caseID: EntityID<Case>, linkID: EntityID<EvidenceLink>,
                                      reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("requestEvidenceReview") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let old = graph.find(linkID) else { throw PersistenceError.missingEntity(kind: "EvidenceLink", id: linkID.rawValue) }
            try validateManualEvidence(old, in: graph)
            let next = try domainChange { try DomainChanges.transition(old, to: .needsReview, in: graph) }
            var dto = CaseGraphDTO(graph)
            let index = try evidenceIndex(linkID, in: dto)
            dto.evidenceLinks[index] = EvidenceLinkDTO(next)
            try appendManualAudit(caseID: caseID, target: ObjectReference(kind: .evidenceLink, id: next.id),
                operation: "requestEvidenceReview", reason: NonEmptyText("Evidenz zur menschlichen Prüfung vorgelegt"),
                reviewer: reviewer.id, at: date, to: &dto)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    func manualGraph(caseID: EntityID<Case>, reviewer: ReviewerIdentity, in context: ModelContext) throws -> DomainContext {
        guard let graph = try readCase(caseID.rawValue, in: context) else {
            throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue)
        }
        var dto = CaseGraphDTO(graph)
        if let index = dto.reviewers.firstIndex(where: { $0.id.value == reviewer.id.rawValue }) {
            dto.reviewers[index] = ReviewerIdentityDTO(reviewer)
        } else { dto.reviewers.append(ReviewerIdentityDTO(reviewer)) }
        return try domainChange { try dto.domain() }
    }

    func validateManualEvidence(_ link: EvidenceLink, in graph: DomainContext) throws {
        guard let criterion = graph.find(link.criterionRevisionID),
              graph.cases[0].activeCriterionRevisionIDs.contains(criterion.id),
              graph.find(criterion.criterionID)?.promiseID == graph.cases[0].promiseID else {
            throw PersistenceError.missingEntity(kind: "CriterionRevision", id: link.criterionRevisionID.rawValue)
        }
        guard criterion.state == .confirmed else { throw PersistenceError.invalidDomain([.criterionNotConfirmed(criterion.id)]) }
        try validateCheckedExcerpts(link.excerptIDs, in: graph)
        if let id = link.actionRevisionID {
            guard let revision = graph.find(id), graph.find(revision.actionID)?.caseID == graph.cases[0].id else {
                throw PersistenceError.missingEntity(kind: "ActionRevision", id: id.rawValue)
            }
        }
        try domainChange { try DomainValidator.validate(link, in: graph).requireValid() }
    }

    private func validateCheckedExcerpts(_ ids: [EntityID<SourceExcerpt>], in graph: DomainContext) throws {
        if ids.isEmpty { throw PersistenceError.invalidDomain([.missingEvidenceExcerpt]) }
        for id in ids {
            guard let excerpt = graph.find(id) else { throw PersistenceError.missingEntity(kind: "SourceExcerpt", id: id.rawValue) }
            guard excerpt.state == .verified else { throw PersistenceError.invalidDomain([.excerptNotVerified(id)]) }
            try domainChange { try DomainValidator.validate(excerpt, in: graph).requireValid() }
        }
    }

    private func checked<Value>(_ old: AssertedValue<Value>, excerpts: [EntityID<SourceExcerpt>],
                                 review: HumanReview) throws -> AssertedValue<Value> {
        try TransitionRules.validate(old.verification, to: .verified)
        return try AssertedValue(content: old.content, provenance: old.provenance,
            verification: .verified, excerptIDs: excerpts, review: review)
    }

    private func evidenceIndex(_ id: EntityID<EvidenceLink>, in graph: CaseGraphDTO) throws -> Int {
        guard let index = graph.evidenceLinks.firstIndex(where: { $0.id.value == id.rawValue }) else {
            throw PersistenceError.missingEntity(kind: "EvidenceLink", id: id.rawValue)
        }
        return index
    }

    private func appendManualAudit(caseID: EntityID<Case>, target: ObjectReference, operation: String,
                                   reason: NonEmptyText, reviewer: EntityID<ReviewerIdentity>, at date: Date,
                                   before: ObjectReference? = nil, to graph: inout CaseGraphDTO) throws {
        graph.cases[0].modifiedAt = date
        graph.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID, target: target,
            operation: try NonEmptyText(operation), before: before,
            author: .human(reviewer), humanRequesterID: reviewer, occurredAt: date, reason: reason)))
    }
}
