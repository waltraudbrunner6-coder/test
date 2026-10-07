import Foundation

public struct ResearchTask: Equatable {
    public let id: EntityID<ResearchTask>
    public let caseID: EntityID<Case>
    public let goal: NonEmptyText
    public let criterionRevisionIDs: [EntityID<CriterionRevision>]
    public let query: String?
    public let status: ResearchTaskStatus
    public let result: String?
    public let failureKind: String?
    public let attemptedAt: Date?
    public let nextStep: String?
    public let sourceIDs: [EntityID<Source>]
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let author: Authorship
    public let createdAt: Date
    public init(
        id: EntityID<ResearchTask> = .init(),
        caseID: EntityID<Case>,
        goal: NonEmptyText,
        criterionRevisionIDs: [EntityID<CriterionRevision>] = [],
        query: String? = nil,
        status: ResearchTaskStatus = .open,
        result: String? = nil,
        failureKind: String? = nil,
        attemptedAt: Date? = nil,
        nextStep: String? = nil,
        sourceIDs: [EntityID<Source>] = [],
        excerptIDs: [EntityID<SourceExcerpt>] = [],
        author: Authorship,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.caseID = caseID
        self.goal = goal
        self.criterionRevisionIDs = criterionRevisionIDs
        self.query = query
        self.status = status
        self.result = result
        self.failureKind = failureKind
        self.attemptedAt = attemptedAt
        self.nextStep = nextStep
        self.sourceIDs = sourceIDs
        self.excerptIDs = excerptIDs
        self.author = author
        self.createdAt = createdAt
    }
}

public struct AuditEntry: Equatable {
    public let id: EntityID<AuditEntry>
    public let caseID: EntityID<Case>
    public let target: ObjectReference
    public let operation: NonEmptyText
    public let before: ObjectReference?
    public let after: ObjectReference?
    public let author: Authorship
    public let humanRequesterID: EntityID<ReviewerIdentity>?
    public let occurredAt: Date
    public let reason: NonEmptyText
    public init(
        id: EntityID<AuditEntry> = .init(),
        caseID: EntityID<Case>,
        target: ObjectReference,
        operation: NonEmptyText,
        before: ObjectReference? = nil,
        after: ObjectReference? = nil,
        author: Authorship,
        humanRequesterID: EntityID<ReviewerIdentity>? = nil,
        occurredAt: Date,
        reason: NonEmptyText
    ) {
        self.id = id
        self.caseID = caseID
        self.target = target
        self.operation = operation
        self.before = before
        self.after = after
        self.author = author
        self.humanRequesterID = humanRequesterID
        self.occurredAt = occurredAt
        self.reason = reason
    }
}

public struct ScriptDraft: Equatable {
    public let id: EntityID<ScriptDraft>
    public let caseEvaluationID: EntityID<CaseEvaluation>
    public let version: Int
    public let targetDurationSeconds: Double
    public let statementIDs: [EntityID<ScriptStatement>]
    public let status: ScriptStatus
    public let author: Authorship
    public let createdAt: Date
    public let approval: HumanReview?
    public init(
        id: EntityID<ScriptDraft> = .init(),
        caseEvaluationID: EntityID<CaseEvaluation>,
        version: Int,
        targetDurationSeconds: Double,
        statementIDs: [EntityID<ScriptStatement>] = [],
        status: ScriptStatus = .draft,
        author: Authorship,
        createdAt: Date = Date(),
        approval: HumanReview? = nil
    ) {
        self.id = id
        self.caseEvaluationID = caseEvaluationID
        self.version = version
        self.targetDurationSeconds = targetDurationSeconds
        self.statementIDs = statementIDs
        self.status = status
        self.author = author
        self.createdAt = createdAt
        self.approval = approval
    }
}

public struct ScriptStatement: Equatable {
    public let id: EntityID<ScriptStatement>
    public let scriptDraftID: EntityID<ScriptDraft>
    public let position: Int
    public let text: NonEmptyText
    public let kind: ScriptStatementKind
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let evidenceLinkIDs: [EntityID<EvidenceLink>]
    public let uncertainty: NonEmptyText?
    public let review: HumanReview?
    public init(
        id: EntityID<ScriptStatement> = .init(),
        scriptDraftID: EntityID<ScriptDraft>,
        position: Int,
        text: NonEmptyText,
        kind: ScriptStatementKind,
        excerptIDs: [EntityID<SourceExcerpt>] = [],
        evidenceLinkIDs: [EntityID<EvidenceLink>] = [],
        uncertainty: NonEmptyText? = nil,
        review: HumanReview? = nil
    ) {
        self.id = id
        self.scriptDraftID = scriptDraftID
        self.position = position
        self.text = text
        self.kind = kind
        self.excerptIDs = excerptIDs
        self.evidenceLinkIDs = evidenceLinkIDs
        self.uncertainty = uncertainty
        self.review = review
    }
}
