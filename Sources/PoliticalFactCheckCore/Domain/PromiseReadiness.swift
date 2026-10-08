import Foundation

/// New immutable inputs and working heads, never an evaluation or a political result.
public struct PromiseReadinessChange: Equatable {
    public let politicalCase: Case
    public let promise: Promise
    public let revision: PromiseRevision
    public let criteria: [EvaluationCriterion]
    public let criterionRevisions: [CriterionRevision]
}

extension DomainChanges {
    /// Restricted to the pre-evaluation documented workflow. Existing evidence retains its exact IDs.
    public static func verifyPromiseForReadiness(_ politicalCase: Case, contextText: NonEmptyText,
        contextExcerptIDs: [EntityID<SourceExcerpt>], speakerExcerptIDs: [EntityID<SourceExcerpt>],
        review: HumanReview, reason: NonEmptyText, at date: Date, in graph: DomainContext) throws -> PromiseReadinessChange {
        guard !graph.caseRevisions.contains(where: { $0.caseID == politicalCase.id }),
              !graph.caseEvaluations.contains(where: { $0.caseID == politicalCase.id }) else {
            throw DomainValidationError.historicalReadinessChangeDenied
        }
        guard politicalCase.workflowState == .documented else { throw DomainValidationError.readinessRequiresDocumentedCase }
        guard graph.find(politicalCase.id) == politicalCase,
              let promise = graph.find(politicalCase.promiseID),
              let old = graph.find(politicalCase.currentPromiseRevisionID) else {
            throw DomainValidationError.missingReference(ObjectReference(kind: .politicalCase, id: politicalCase.id))
        }
        try DomainValidator.validate(politicalCase, in: graph).requireValid()
        guard old.quote.verification == .verified else { throw DomainValidationError.originalQuoteNotVerified }
        guard let speakerID = old.speaker.content.knownValue, graph.find(speakerID) != nil else {
            throw DomainValidationError.speakerAssignmentUnavailable
        }
        try DomainValidator.review(review, in: graph).requireValid()
        guard date >= old.metadata.createdAt, review.reviewedAt >= date else { throw DomainValidationError.invalidReviewTime }
        try readinessExcerpts(contextExcerptIDs, in: graph)
        try readinessExcerpts(speakerExcerptIDs, in: graph)
        let next = try PromiseRevision(promiseID: old.promiseID, quote: old.quote, thesis: old.thesis,
            statementDate: old.statementDate,
            context: AssertedValue(content: .known(contextText), provenance: .humanEntered,
                verification: .verified, excerptIDs: contextExcerptIDs, review: review),
            targetGroup: old.targetGroup, conditions: old.conditions, responsibility: old.responsibility,
            speaker: AssertedValue(content: .known(speakerID), provenance: old.speaker.provenance,
                verification: .verified, excerptIDs: speakerExcerptIDs, review: review),
            party: old.party, topics: old.topics,
            metadata: RevisionMetadata(number: old.metadata.number + 1, reason: reason,
                author: .human(review.reviewerID), createdAt: date))
        // Only the validation inputs needed for these revisions; the store validates the complete result too.
        let validationGraph = DomainContext(reviewers: graph.reviewers, actors: graph.actors,
            promises: graph.promises, promiseRevisions: graph.promiseRevisions + [next], criteria: graph.criteria,
            sources: graph.sources, sourceVersions: graph.sourceVersions, excerpts: graph.excerpts)
        try DomainValidator.validate(next, in: validationGraph).requireValid()
        var criteria: [EvaluationCriterion] = []
        var revisions: [CriterionRevision] = []
        for id in politicalCase.activeCriterionRevisionIDs {
            guard let previous = graph.find(id), let criterion = graph.find(previous.criterionID),
                  criterion.promiseID == promise.id, criterion.currentRevisionID == previous.id,
                  previous.state != .superseded else {
                throw DomainValidationError.relationshipMismatch(ObjectReference(kind: .criterionRevision, id: id))
            }
            let rebound = CriterionRevision(criterionID: previous.criterionID, promiseRevisionID: next.id,
                goal: previous.goal, targetGroup: previous.targetGroup, baseline: previous.baseline,
                deadline: previous.deadline, conditions: previous.conditions, isCore: previous.isCore,
                materialityRule: previous.materialityRule, weight: previous.weight, weightReason: previous.weightReason,
                metadata: RevisionMetadata(number: previous.metadata.number + 1, reason: reason,
                    author: .human(review.reviewerID), createdAt: date))
            try RevisionRules.validateReplacement(previous, with: rebound)
            try DomainValidator.validate(rebound, in: validationGraph).requireValid()
            revisions.append(rebound)
            criteria.append(EvaluationCriterion(id: criterion.id, promiseID: criterion.promiseID,
                currentRevisionID: rebound.id, createdAt: criterion.createdAt))
        }
        let updated = Case(id: politicalCase.id, title: politicalCase.title, promiseID: politicalCase.promiseID,
            currentPromiseRevisionID: next.id, activeCriterionRevisionIDs: revisions.map(\.id),
            currentActionRevisionIDs: politicalCase.currentActionRevisionIDs, workflowState: politicalCase.workflowState,
            createdAt: politicalCase.createdAt, modifiedAt: date)
        return PromiseReadinessChange(politicalCase: updated,
            promise: Promise(id: promise.id, caseID: promise.caseID, currentRevisionID: next.id, createdAt: promise.createdAt),
            revision: next, criteria: criteria, criterionRevisions: revisions)
    }

    private static func readinessExcerpts(_ ids: [EntityID<SourceExcerpt>], in graph: DomainContext) throws {
        try DomainValidator.excerpts(ids, required: true, in: graph).requireValid()
        var seen = Set<EntityID<SourceExcerpt>>()
        for id in ids {
            guard seen.insert(id).inserted else { throw DomainValidationError.duplicateReference(ObjectReference(kind: .excerpt, id: id)) }
            // Live readiness must not use the historical/superseded-source allowance of snapshots.
            if let excerpt = graph.find(id) { try DomainValidator.validate(excerpt, in: graph).requireValid() }
        }
    }
}
