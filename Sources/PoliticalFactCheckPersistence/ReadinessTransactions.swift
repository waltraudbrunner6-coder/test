import Foundation
import SwiftData
import PoliticalFactCheckCore

extension LocalCaseStore {
    public func verifyPromiseForEvaluationReadiness(caseID: EntityID<Case>, contextText: NonEmptyText,
        contextExcerptIDs: [EntityID<SourceExcerpt>], speakerExcerptIDs: [EntityID<SourceExcerpt>],
        reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("verifyPromiseForEvaluationReadiness") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            let reason = try NonEmptyText("Prüfrahmen menschlich bestätigt; aktive Kriterien an neue PromiseRevision gebunden und erneut zu bestätigen")
            let change = try domainChange {
                try DomainChanges.verifyPromiseForReadiness(graph.cases[0], contextText: contextText,
                    contextExcerptIDs: contextExcerptIDs, speakerExcerptIDs: speakerExcerptIDs,
                    review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), reason: reason, at: date, in: graph)
            }
            var dto = CaseGraphDTO(graph)
            dto.cases[0] = CaseDTO(change.politicalCase)
            dto.promises[0] = PromiseDTO(change.promise)
            dto.promiseRevisions.append(PromiseRevisionDTO(change.revision))
            for criterion in change.criteria {
                guard let index = dto.criteria.firstIndex(where: { $0.id.value == criterion.id.rawValue }) else {
                    throw PersistenceError.missingEntity(kind: "EvaluationCriterion", id: criterion.id.rawValue)
                }
                dto.criteria[index] = EvaluationCriterionDTO(criterion)
            }
            dto.criterionRevisions.append(contentsOf: change.criterionRevisions.map(CriterionRevisionDTO.init))
            let target = ObjectReference(kind: .promiseRevision, id: change.revision.id)
            for operation in ["verifyPromiseForReadiness", "verifyPromiseContext", "verifyPromiseSpeaker"] {
                dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID, target: target,
                    operation: try NonEmptyText(operation),
                    before: ObjectReference(kind: .promiseRevision, id: graph.cases[0].currentPromiseRevisionID),
                    after: target, author: .human(reviewer.id), humanRequesterID: reviewer.id, occurredAt: date, reason: reason)))
            }
            for revision in change.criterionRevisions {
                guard let previous = graph.find(revision.criterionID)?.currentRevisionID else {
                    throw PersistenceError.missingEntity(kind: "EvaluationCriterion", id: revision.criterionID.rawValue)
                }
                dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID,
                    target: ObjectReference(kind: .criterionRevision, id: revision.id), operation: try NonEmptyText("rebindCriterionToPromise"),
                    before: ObjectReference(kind: .criterionRevision, id: previous),
                    after: ObjectReference(kind: .criterionRevision, id: revision.id),
                    author: .human(reviewer.id), humanRequesterID: reviewer.id, occurredAt: date, reason: reason)))
            }
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    /// Deliberately exposes only the two pre-evaluation transitions, with Core as the authority.
    public func advanceEvaluationReadiness(caseID: EntityID<Case>, to state: CaseWorkflowState,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("advanceEvaluationReadiness") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard state == .verified || state == .readyForEvaluation else {
                throw PersistenceError.invalidValue(detail: "Dieser Vorgang führt ausschließlich zu verified oder readyForEvaluation.")
            }
            let next = try domainChange { try DomainChanges.transition(graph.cases[0], to: state, at: date, in: graph) }
            var dto = CaseGraphDTO(graph)
            dto.cases[0] = CaseDTO(next)
            dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID,
                target: ObjectReference(kind: .politicalCase, id: caseID),
                operation: try NonEmptyText(state == .verified ? "markCaseVerified" : "prepareCaseForEvaluation"),
                author: .human(reviewer.id), humanRequesterID: reviewer.id, occurredAt: date,
                reason: try NonEmptyText("Bewertungsreife über bestehende Core-Transition fortgeschrieben; noch keine Bewertung"))))
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }
}
