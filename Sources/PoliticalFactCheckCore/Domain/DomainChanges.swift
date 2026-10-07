import Foundation

public enum ReviewerKind: Equatable { case human }
extension ReviewerIdentity { public var kind: ReviewerKind { .human } }

public struct ReviewRequest: Equatable {
    public let evaluationID: EntityID<CaseEvaluation>
    public let reason: NonEmptyText
    public init(evaluationID: EntityID<CaseEvaluation>, reason: NonEmptyText) {
        self.evaluationID = evaluationID; self.reason = reason
    }
}

public struct CriterionChange: Equatable {
    public let revision: CriterionRevision
    public let reviewRequests: [ReviewRequest]
    public let evaluationUpdates: [CaseEvaluation]
    public init(revision: CriterionRevision, reviewRequests: [ReviewRequest], evaluationUpdates: [CaseEvaluation]) {
        self.revision = revision; self.reviewRequests = reviewRequests; self.evaluationUpdates = evaluationUpdates
    }
}

public struct EvidenceChange: Equatable {
    public let link: EvidenceLink
    public let reviewRequests: [ReviewRequest]
    public let evaluationUpdates: [CaseEvaluation]
    public init(link: EvidenceLink, reviewRequests: [ReviewRequest], evaluationUpdates: [CaseEvaluation]) {
        self.link = link; self.reviewRequests = reviewRequests; self.evaluationUpdates = evaluationUpdates
    }
}

public enum DomainChanges {
    public static func transition(_ script: ScriptDraft, to status: ScriptStatus,
                                  approval: HumanReview? = nil, in context: DomainContext) throws -> ScriptDraft {
        try TransitionRules.validate(script.status, to: status)
        let next = script.replacingLifecycle(status: status, approval: status == .approved ? approval : script.approval)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }
    public static func transition(_ link: EvidenceLink, to status: EvidenceLinkStatus,
                                  review: HumanReview? = nil, in context: DomainContext) throws -> EvidenceLink {
        try TransitionRules.validate(link.status, to: status)
        let next = link.replacingLifecycle(status: status, review: status == .verified ? review : link.review)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }
    public static func transition(_ politicalCase: Case, to state: CaseWorkflowState,
                                  at time: Date, in context: DomainContext) throws -> Case {
        try TransitionRules.validate(politicalCase.workflowState, to: state)
        let next = politicalCase.replacingLifecycle(workflowState: state, modifiedAt: time)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }

    public static func transition(_ criterion: CriterionRevision, to state: CriterionRevisionState,
                                  review: HumanReview? = nil, in context: DomainContext) throws -> CriterionRevision {
        try TransitionRules.validate(criterion.state, to: state)
        let next = criterion.replacingLifecycle(state: state, confirmation: state == .confirmed ? review : criterion.confirmation)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }

    public static func transition(_ excerpt: SourceExcerpt, to state: ExcerptVerificationState,
                                  review: HumanReview? = nil, in context: DomainContext) throws -> SourceExcerpt {
        try TransitionRules.validate(excerpt.state, to: state)
        let next = excerpt.replacingLifecycle(state: state, review: state == .verified ? review : excerpt.review)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }

    public static func transition(_ evaluation: CaseEvaluation, to status: EvaluationStatus,
                                  approval: HumanReview? = nil, reason: NonEmptyText? = nil,
                                  in context: DomainContext) throws -> CaseEvaluation {
        try TransitionRules.validate(evaluation.status, to: status)
        let next = evaluation.replacingLifecycle(status: status,
            approval: status == .approved ? approval : evaluation.approval,
            reviewReason: status == .reviewRequired ? reason : evaluation.reviewReason)
        try DomainValidator.validate(next, in: context).requireValid()
        return next
    }

    /// Content changes always allocate a new ID and reset confirmation; previous value is untouched.
    public static func revise(_ criterion: CriterionRevision, goal: NonEmptyText,
                              materialityRule: NonEmptyText? = nil, reason: NonEmptyText,
                              author: Authorship, at date: Date, in context: DomainContext) throws -> CriterionChange {
        let next = CriterionRevision(criterionID: criterion.criterionID, promiseRevisionID: criterion.promiseRevisionID,
            goal: goal, targetGroup: criterion.targetGroup, baseline: criterion.baseline,
            deadline: criterion.deadline, conditions: criterion.conditions, isCore: criterion.isCore,
            materialityRule: materialityRule ?? criterion.materialityRule, weight: criterion.weight,
            weightReason: criterion.weightReason,
            metadata: RevisionMetadata(number: criterion.metadata.number + 1, reason: reason, author: author, createdAt: date))
        try DomainValidator.validate(next, in: context).requireValid()
        let requests = context.caseEvaluations.compactMap { evaluation -> ReviewRequest? in
            guard evaluation.status != .superseded, let snapshot = context.find(evaluation.caseRevisionID),
                  snapshot.criteria.contains(where: { $0.id == criterion.id }) else { return nil }
            return ReviewRequest(evaluationID: evaluation.id, reason: reason)
        }
        let updates = try requests.compactMap { request -> CaseEvaluation? in
            guard let evaluation = context.find(request.evaluationID) else { return nil }
            return try apply(request, to: evaluation, in: context)
        }
        return CriterionChange(revision: next, reviewRequests: requests, evaluationUpdates: updates)
    }

    /// Emits review requests without choosing a new result or modifying the historical evaluation.
    public static func reviewImpact(of link: EvidenceLink, reason: NonEmptyText,
                                    in context: DomainContext) throws -> [ReviewRequest] {
        guard link.status == .verified else { throw DomainValidationError.evidenceLinkNotVerified(link.id) }
        try DomainValidator.validate(link, in: context).requireValid()
        return context.caseEvaluations.compactMap { evaluation -> ReviewRequest? in
            guard evaluation.status != .superseded, let snapshot = context.find(evaluation.caseRevisionID),
                  snapshot.criteria.contains(where: { $0.id == link.criterionRevisionID }),
                  !snapshot.evidenceLinks.contains(where: { $0.id == link.id }) else { return nil }
            return ReviewRequest(evaluationID: evaluation.id, reason: reason)
        }
    }

    public static func addingEvidence(_ link: EvidenceLink, reason: NonEmptyText,
                                      in context: DomainContext) throws -> EvidenceChange {
        let requests = try reviewImpact(of: link, reason: reason, in: context)
        let updates = try requests.compactMap { request -> CaseEvaluation? in
            guard let evaluation = context.find(request.evaluationID) else { return nil }
            return try apply(request, to: evaluation, in: context)
        }
        return EvidenceChange(link: link, reviewRequests: requests, evaluationUpdates: updates)
    }

    public static func apply(_ request: ReviewRequest, to evaluation: CaseEvaluation,
                             in context: DomainContext) throws -> CaseEvaluation {
        guard request.evaluationID == evaluation.id else {
            throw DomainValidationError.relationshipMismatch(ObjectReference(kind: .caseEvaluation, id: request.evaluationID))
        }
        switch evaluation.status {
        case .approved:
            try TransitionRules.validate(evaluation.status, to: .reviewRequired)
            return evaluation.replacingLifecycle(status: .reviewRequired, approval: evaluation.approval, reviewReason: request.reason)
        case .draft:
            try TransitionRules.validate(evaluation.status, to: .needsReview)
            return evaluation.replacingLifecycle(status: .needsReview, approval: evaluation.approval, reviewReason: request.reason)
        case .needsReview, .reviewRequired: return evaluation
        case .superseded: throw DomainValidationError.invalidEvaluationTransition(.superseded, .reviewRequired)
        }
    }
}

/// Boundary checks for callers attempting to insert another value under a historical ID.
public enum RevisionRules {
    public static func validateReplacement(_ old: CriterionRevision, with new: CriterionRevision) throws {
        if old.id == new.id {
            let normalized = new.replacingLifecycle(state: old.state, confirmation: old.confirmation)
            guard normalized == old else { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .criterionRevision, id: old.id)) }
            if old.state != new.state { try TransitionRules.validate(old.state, to: new.state) }
            if (old.state == new.state || old.confirmation != nil) && old.confirmation != new.confirmation {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .criterionRevision, id: old.id))
            }
        } else {
            guard old.criterionID == new.criterionID, new.metadata.number == old.metadata.number + 1, new.state == .draft, new.confirmation == nil else {
                throw DomainValidationError.relationshipMismatch(ObjectReference(kind: .criterionRevision, id: new.id))
            }
        }
    }

    public static func validateReplacement(_ old: CaseEvaluation, with new: CaseEvaluation) throws {
        if old.id == new.id {
            let normalized = new.replacingLifecycle(status: old.status, approval: old.approval, reviewReason: old.reviewReason)
            guard normalized == old else { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .caseEvaluation, id: old.id)) }
            if old.status != new.status { try TransitionRules.validate(old.status, to: new.status) }
            if old.status == new.status && (old.approval != new.approval || old.reviewReason != new.reviewReason) {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .caseEvaluation, id: old.id))
            }
            if old.approval != nil && old.approval != new.approval {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .caseEvaluation, id: old.id))
            }
        }
    }

    public static func validateReplacement(_ old: PromiseRevision, with new: PromiseRevision) throws {
        if old.id == new.id && old != new { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .promiseRevision, id: old.id)) }
    }
    public static func validateReplacement(_ old: SourceVersion, with new: SourceVersion) throws {
        if old.id == new.id && old != new { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .sourceVersion, id: old.id)) }
    }
    public static func validateReplacement(_ old: ActionRevision, with new: ActionRevision) throws {
        if old.id == new.id && old != new { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .actionRevision, id: old.id)) }
    }
    public static func validateReplacement(_ old: CaseRevision, with new: CaseRevision) throws {
        if old.id == new.id && old != new { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .caseRevision, id: old.id)) }
    }
    public static func validateReplacement(_ old: CriterionEvaluation, with new: CriterionEvaluation) throws {
        if old.id == new.id && old != new { throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .criterionEvaluation, id: old.id)) }
    }
    public static func validateReplacement(_ old: SourceExcerpt, with new: SourceExcerpt) throws {
        if old.id == new.id {
            guard new.replacingLifecycle(state: old.state, review: old.review) == old else {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .excerpt, id: old.id))
            }
            if old.state != new.state { try TransitionRules.validate(old.state, to: new.state) }
            if old.review != nil && old.review != new.review {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .excerpt, id: old.id))
            }
        }
    }
    public static func validateReplacement(_ old: EvidenceLink, with new: EvidenceLink) throws {
        if old.id == new.id {
            guard new.replacingLifecycle(status: old.status, review: old.review) == old else {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .evidenceLink, id: old.id))
            }
            if old.status != new.status { try TransitionRules.validate(old.status, to: new.status) }
            if old.review != nil && old.review != new.review {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .evidenceLink, id: old.id))
            }
        }
    }
    public static func validateReplacement(_ old: ScriptDraft, with new: ScriptDraft) throws {
        if old.id == new.id {
            guard new.replacingLifecycle(status: old.status, approval: old.approval) == old else {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .script, id: old.id))
            }
            if old.status != new.status { try TransitionRules.validate(old.status, to: new.status) }
            if old.approval != nil && old.approval != new.approval {
                throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .script, id: old.id))
            }
        }
    }
}
