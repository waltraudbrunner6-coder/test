import Foundation
import SwiftData
import PoliticalFactCheckCore

extension LocalCaseStore {
    /// Persists the domain change, operational review statuses and audits in one save.
    public func addVerifiedEvidence(caseID: EntityID<Case>, link: EvidenceLink,
                                    reason: NonEmptyText, requestedBy reviewer: EntityID<ReviewerIdentity>,
                                    at date: Date) throws {
        try transaction("addVerifiedEvidence") { context in
            guard let graph = try readCase(caseID.rawValue, in: context) else {
                throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue)
            }
            try persistVerifiedEvidence(caseID: caseID, link: link, reason: reason,
                reviewer: reviewer, at: date, graph: graph, context: context)
        }
    }

    /// The manual review path promotes an existing needsReview link through the same impact transaction.
    public func verifyEvidence(caseID: EntityID<Case>, linkID: EntityID<EvidenceLink>,
                               reviewer: ReviewerIdentity, at date: Date, reason: NonEmptyText) throws {
        try transaction("verifyEvidence") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let old = graph.find(linkID) else {
                throw PersistenceError.missingEntity(kind: "EvidenceLink", id: linkID.rawValue)
            }
            try validateManualEvidence(old, in: graph)
            let verified = try domainChange {
                try DomainChanges.transition(old, to: .verified,
                    review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: graph)
            }
            try persistVerifiedEvidence(caseID: caseID, link: verified, reason: reason,
                reviewer: reviewer.id, at: date, graph: graph, context: context)
        }
    }

    private func persistVerifiedEvidence(caseID: EntityID<Case>, link: EvidenceLink,
                                         reason: NonEmptyText, reviewer: EntityID<ReviewerIdentity>,
                                         at date: Date, graph: DomainContext, context: ModelContext) throws {
        guard graph.find(reviewer) != nil else {
            throw PersistenceError.missingEntity(kind: "ReviewerIdentity", id: reviewer.rawValue)
        }
        if let existing = graph.find(link.id) {
            guard existing.status == .needsReview else {
                throw PersistenceError.duplicateID(kind: "EvidenceLink", id: link.id.rawValue)
            }
            try domainChange { try RevisionRules.validateReplacement(existing, with: link) }
        }
        guard let criterion = graph.find(link.criterionRevisionID),
              graph.find(criterion.criterionID)?.promiseID == graph.cases[0].promiseID else {
            throw PersistenceError.missingEntity(kind: "CriterionRevision", id: link.criterionRevisionID.rawValue)
        }
        let change = try domainChange { try DomainChanges.addingEvidence(link, reason: reason, in: graph) }
        var dto = CaseGraphDTO(graph)
        if let index = dto.evidenceLinks.firstIndex(where: { $0.id.value == link.id.rawValue }) {
            dto.evidenceLinks[index] = EvidenceLinkDTO(change.link)
        } else {
            dto.evidenceLinks.append(EvidenceLinkDTO(change.link))
        }
        for evaluation in change.evaluationUpdates {
            if let index = dto.caseEvaluations.firstIndex(where: { $0.id.value == evaluation.id.rawValue }) {
                dto.caseEvaluations[index] = CaseEvaluationDTO(evaluation)
            }
        }
        dto.cases[0].modifiedAt = date
        try dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID,
            target: ObjectReference(kind: .evidenceLink, id: link.id), operation: NonEmptyText("addVerifiedEvidence"),
            author: .human(reviewer), humanRequesterID: reviewer, occurredAt: date, reason: reason)))
        try supersedeDependentScripts(change.evaluationUpdates, in: graph, reason: reason,
            reviewer: reviewer, at: date, to: &dto)
        try appendReviewAudits(change.reviewRequests, caseID: caseID, reviewer: reviewer, at: date, to: &dto)
        try writeCase(domainChange { try dto.domain() }, in: context)
    }

    public func reviseCriterion(caseID: EntityID<Case>, revisionID: EntityID<CriterionRevision>,
                                goal: NonEmptyText, reason: NonEmptyText,
                                requestedBy reviewer: EntityID<ReviewerIdentity>, at date: Date,
                                confirmation: HumanReview? = nil) throws {
        try transaction("reviseCriterion") { context in
            guard let graph = try readCase(caseID.rawValue, in: context) else {
                throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue)
            }
            guard graph.find(reviewer) != nil else {
                throw PersistenceError.missingEntity(kind: "ReviewerIdentity", id: reviewer.rawValue)
            }
            guard let old = graph.find(revisionID), graph.cases[0].activeCriterionRevisionIDs.contains(revisionID) else {
                throw PersistenceError.missingEntity(kind: "CriterionRevision", id: revisionID.rawValue)
            }
            let change = try domainChange {
                try DomainChanges.revise(old, goal: goal, reason: reason, author: .human(reviewer), at: date, in: graph)
            }
            var revision = change.revision
            if let confirmation = confirmation {
                revision = try domainChange {
                    try DomainChanges.transition(revision, to: .confirmed, review: confirmation, in: graph)
                }
            }
            var dto = CaseGraphDTO(graph)
            dto.criterionRevisions.append(CriterionRevisionDTO(revision))
            guard let index = dto.criteria.firstIndex(where: { $0.id.value == old.criterionID.rawValue }) else {
                throw PersistenceError.missingEntity(kind: "EvaluationCriterion", id: old.criterionID.rawValue)
            }
            dto.criteria[index].currentRevisionID = StoredID(revision.id, kind: "CriterionRevision")
            dto.cases[0].activeCriterionRevisionIDs = dto.cases[0].activeCriterionRevisionIDs.map {
                $0.value == revisionID.rawValue ? StoredID(revision.id, kind: "CriterionRevision") : $0
            }
            dto.cases[0].modifiedAt = date
            for evaluation in change.evaluationUpdates {
                if let index = dto.caseEvaluations.firstIndex(where: { $0.id.value == evaluation.id.rawValue }) {
                    dto.caseEvaluations[index] = CaseEvaluationDTO(evaluation)
                }
            }
            try dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID,
                target: ObjectReference(kind: .criterionRevision, id: revision.id), operation: NonEmptyText("reviseCriterion"),
                before: ObjectReference(kind: .criterionRevision, id: old.id),
                after: ObjectReference(kind: .criterionRevision, id: revision.id), author: .human(reviewer),
                humanRequesterID: reviewer, occurredAt: date, reason: reason)))
            try supersedeDependentScripts(change.evaluationUpdates, in: graph, reason: reason,
                reviewer: reviewer, at: date, to: &dto)
            try appendReviewAudits(change.reviewRequests, caseID: caseID, reviewer: reviewer, at: date, to: &dto)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    // The existing core disallows an approved script whose evaluation needs review.
    // Preserve the approved text and approval while using its allowed superseded status.
    private func supersedeDependentScripts(_ updates: [CaseEvaluation], in original: DomainContext,
                                           reason: NonEmptyText, reviewer: EntityID<ReviewerIdentity>,
                                           at date: Date, to graph: inout CaseGraphDTO) throws {
        let affected = Set(updates.filter { $0.status == .reviewRequired }.map { $0.id })
        for script in original.scripts where script.status == .approved && affected.contains(script.caseEvaluationID) {
            let archived = try domainChange {
                try DomainChanges.transition(script, to: .superseded, in: original)
            }
            if let index = graph.scripts.firstIndex(where: { $0.id.value == script.id.rawValue }) {
                graph.scripts[index] = ScriptDraftDTO(archived)
            }
            try graph.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: original.cases[0].id,
                target: ObjectReference(kind: .script, id: script.id), operation: NonEmptyText("supersedeDependentScript"),
                author: .system, humanRequesterID: reviewer, occurredAt: date, reason: reason)))
        }
    }

    private func appendReviewAudits(_ requests: [ReviewRequest], caseID: EntityID<Case>,
                                    reviewer: EntityID<ReviewerIdentity>, at date: Date,
                                    to graph: inout CaseGraphDTO) throws {
        for request in requests {
            try graph.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID,
                target: ObjectReference(kind: .caseEvaluation, id: request.evaluationID),
                operation: NonEmptyText("requestEvaluationReview"), author: .system,
                humanRequesterID: reviewer, occurredAt: date, reason: request.reason)))
        }
    }
}
