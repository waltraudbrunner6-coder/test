import Foundation

public struct CaseRevision: Equatable {
    public let id: EntityID<CaseRevision>
    public let caseID: EntityID<Case>
    public let promiseRevisionID: EntityID<PromiseRevision>
    public let criteria: [StateSnapshot<CriterionRevision, CriterionRevisionState>]
    public let actionRevisionIDs: [EntityID<ActionRevision>]
    public let participations: [StateSnapshot<ActionParticipation, FactVerificationState>]
    public let sourceVersions: [StateSnapshot<SourceVersion, FactVerificationState>]
    public let excerpts: [StateSnapshot<SourceExcerpt, ExcerptVerificationState>]
    public let evidenceLinks: [StateSnapshot<EvidenceLink, EvidenceLinkStatus>]
    public let researchTasks: [StateSnapshot<ResearchTask, ResearchTaskStatus>]
    public let metadata: RevisionMetadata
    public init(
        id: EntityID<CaseRevision> = .init(),
        caseID: EntityID<Case>,
        promiseRevisionID: EntityID<PromiseRevision>,
        criteria: [StateSnapshot<CriterionRevision, CriterionRevisionState>],
        actionRevisionIDs: [EntityID<ActionRevision>] = [],
        participations: [StateSnapshot<ActionParticipation, FactVerificationState>] = [],
        sourceVersions: [StateSnapshot<SourceVersion, FactVerificationState>] = [],
        excerpts: [StateSnapshot<SourceExcerpt, ExcerptVerificationState>] = [],
        evidenceLinks: [StateSnapshot<EvidenceLink, EvidenceLinkStatus>] = [],
        researchTasks: [StateSnapshot<ResearchTask, ResearchTaskStatus>] = [],
        metadata: RevisionMetadata
    ) {
        self.id = id
        self.caseID = caseID
        self.promiseRevisionID = promiseRevisionID
        self.criteria = criteria
        self.actionRevisionIDs = actionRevisionIDs
        self.participations = participations
        self.sourceVersions = sourceVersions
        self.excerpts = excerpts
        self.evidenceLinks = evidenceLinks
        self.researchTasks = researchTasks
        self.metadata = metadata
    }
}

public struct CriterionEvaluation: Equatable {
    public let id: EntityID<CriterionEvaluation>
    public let caseEvaluationID: EntityID<CaseEvaluation>
    public let criterionRevisionID: EntityID<CriterionRevision>
    public let category: EvaluationCategory
    public let rationale: NonEmptyText
    public let evidenceLinkIDs: [EntityID<EvidenceLink>]
    public let counterEvidenceLinkIDs: [EntityID<EvidenceLink>]
    public let confidence: EvidenceConfidence
    public let uncertainties: [NonEmptyText]
    public let notVerifiableReasons: [NotVerifiableReason]
    public let reviewState: HumanReviewState
    public let review: HumanReview?
    public init(
        id: EntityID<CriterionEvaluation> = .init(),
        caseEvaluationID: EntityID<CaseEvaluation>,
        criterionRevisionID: EntityID<CriterionRevision>,
        category: EvaluationCategory,
        rationale: NonEmptyText,
        evidenceLinkIDs: [EntityID<EvidenceLink>] = [],
        counterEvidenceLinkIDs: [EntityID<EvidenceLink>] = [],
        confidence: EvidenceConfidence,
        uncertainties: [NonEmptyText] = [],
        notVerifiableReasons: [NotVerifiableReason] = [],
        reviewState: HumanReviewState = .unreviewed,
        review: HumanReview? = nil
    ) {
        self.id = id
        self.caseEvaluationID = caseEvaluationID
        self.criterionRevisionID = criterionRevisionID
        self.category = category
        self.rationale = rationale
        self.evidenceLinkIDs = evidenceLinkIDs
        self.counterEvidenceLinkIDs = counterEvidenceLinkIDs
        self.confidence = confidence
        self.uncertainties = uncertainties
        self.notVerifiableReasons = notVerifiableReasons
        self.reviewState = reviewState
        self.review = review
    }
}

public struct CaseEvaluation: Equatable {
    public let id: EntityID<CaseEvaluation>
    public let caseID: EntityID<Case>
    public let caseRevisionID: EntityID<CaseRevision>
    public let cutoff: DatedValue
    public let methodologyVersionID: EntityID<MethodologyVersion>
    public let criterionEvaluationIDs: [EntityID<CriterionEvaluation>]
    public let category: EvaluationCategory
    public let rationale: NonEmptyText
    public let confidence: EvidenceConfidence
    public let facts: [NonEmptyText]
    public let interpretations: [NonEmptyText]
    public let uncertainties: [NonEmptyText]
    public let notVerifiableReasons: [NotVerifiableReason]
    public let metadata: RevisionMetadata
    public let status: EvaluationStatus
    public let approval: HumanReview?
    public let reviewReason: NonEmptyText?
    public let replacesEvaluationID: EntityID<CaseEvaluation>?
    public init(
        id: EntityID<CaseEvaluation> = .init(),
        caseID: EntityID<Case>,
        caseRevisionID: EntityID<CaseRevision>,
        cutoff: DatedValue,
        methodologyVersionID: EntityID<MethodologyVersion>,
        criterionEvaluationIDs: [EntityID<CriterionEvaluation>],
        category: EvaluationCategory,
        rationale: NonEmptyText,
        confidence: EvidenceConfidence,
        facts: [NonEmptyText] = [],
        interpretations: [NonEmptyText] = [],
        uncertainties: [NonEmptyText] = [],
        notVerifiableReasons: [NotVerifiableReason] = [],
        metadata: RevisionMetadata,
        status: EvaluationStatus = .draft,
        approval: HumanReview? = nil,
        reviewReason: NonEmptyText? = nil,
        replacesEvaluationID: EntityID<CaseEvaluation>? = nil
    ) {
        self.id = id
        self.caseID = caseID
        self.caseRevisionID = caseRevisionID
        self.cutoff = cutoff
        self.methodologyVersionID = methodologyVersionID
        self.criterionEvaluationIDs = criterionEvaluationIDs
        self.category = category
        self.rationale = rationale
        self.confidence = confidence
        self.facts = facts
        self.interpretations = interpretations
        self.uncertainties = uncertainties
        self.notVerifiableReasons = notVerifiableReasons
        self.metadata = metadata
        self.status = status
        self.approval = approval
        self.reviewReason = reviewReason
        self.replacesEvaluationID = replacesEvaluationID
    }
}

public struct MethodologyVersion: Equatable {
    public let id: EntityID<MethodologyVersion>
    public let version: NonEmptyText
    public let title: NonEmptyText
    public let contentReference: NonEmptyText
    public let hash: ContentHash?
    public let changeNote: NonEmptyText
    public let createdAt: Date
    public init(
        id: EntityID<MethodologyVersion> = .init(),
        version: NonEmptyText,
        title: NonEmptyText,
        contentReference: NonEmptyText,
        hash: ContentHash? = nil,
        changeNote: NonEmptyText,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.version = version
        self.title = title
        self.contentReference = contentReference
        self.hash = hash
        self.changeNote = changeNote
        self.createdAt = createdAt
    }
}
