import Foundation

public enum DomainValidationError: Error, Equatable {
    case missingReference(ObjectReference)
    case duplicateReference(ObjectReference)
    case relationshipMismatch(ObjectReference)
    case originalQuoteNotVerified
    case speakerAssignmentUnavailable
    case historicalReadinessChangeDenied
    case readinessRequiresDocumentedCase
    case missingHumanReview
    case unknownVerifiedValue
    case missingSourceIdentity
    case invalidRevisionNumber
    case invalidReviewTime
    case missingOriginalExcerpt
    case missingEvidenceExcerpt
    case excerptNotVerified(EntityID<SourceExcerpt>)
    case sourceVersionNotVerified(EntityID<SourceVersion>)
    case missingCriteria
    case criterionNotConfirmed(EntityID<CriterionRevision>)
    case weightWithoutJustification
    case snapshotMismatch(ObjectReference)
    case immutableContentChanged(ObjectReference)
    case emptyEvidenceForNegativeJudgment
    case positiveJudgmentRequiresSupportingEvidence
    case evidenceLinkNotVerified(EntityID<EvidenceLink>)
    case contraryActionRequiresContradictingEvidence
    case missingNotVerifiableReason
    case lowConfidenceNegativeJudgment
    case unreviewedCriterionEvaluation
    case invalidDateRole(expected: DateRole, actual: DateRole)
    case missingCutoff
    case eventAfterCutoff
    case deadlineNotPassed
    case missingReviewReason
    case scriptFactWithoutExcerpt
    case causalAttributionWithoutEvidence
    case invalidCaseTransition(CaseWorkflowState, CaseWorkflowState)
    case invalidCriterionTransition(CriterionRevisionState, CriterionRevisionState)
    case invalidExcerptTransition(ExcerptVerificationState, ExcerptVerificationState)
    case invalidEvaluationTransition(EvaluationStatus, EvaluationStatus)
    case invalidFactTransition(FactVerificationState, FactVerificationState)
    case invalidScriptTransition(ScriptStatus, ScriptStatus)
    case invalidEvidenceTransition(EvidenceLinkStatus, EvidenceLinkStatus)
}

public enum DomainValidationWarning: Equatable {
    case temporalInterpretationRequired
    case retrospectivePublication(EntityID<SourceVersion>)
}

public struct ValidationResult: Equatable {
    public private(set) var errors: [DomainValidationError] = []
    public private(set) var warnings: [DomainValidationWarning] = []
    public var isValid: Bool { errors.isEmpty }
    public init() {}
    mutating func add(_ error: DomainValidationError) { errors.append(error) }
    mutating func warn(_ warning: DomainValidationWarning) { warnings.append(warning) }
    mutating func merge(_ other: ValidationResult) {
        errors.append(contentsOf: other.errors); warnings.append(contentsOf: other.warnings)
    }
    public func requireValid() throws {
        if let error = errors.first { throw error }
    }
}
