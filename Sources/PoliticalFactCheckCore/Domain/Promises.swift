import Foundation

public struct Case: Equatable {
    public let id: EntityID<Case>
    public let title: NonEmptyText
    public let promiseID: EntityID<Promise>
    public let currentPromiseRevisionID: EntityID<PromiseRevision>
    public let activeCriterionRevisionIDs: [EntityID<CriterionRevision>]
    public let currentActionRevisionIDs: [EntityID<ActionRevision>]
    public let workflowState: CaseWorkflowState
    public let createdAt: Date
    public let modifiedAt: Date
    public init(
        id: EntityID<Case> = .init(),
        title: NonEmptyText,
        promiseID: EntityID<Promise>,
        currentPromiseRevisionID: EntityID<PromiseRevision>,
        activeCriterionRevisionIDs: [EntityID<CriterionRevision>] = [],
        currentActionRevisionIDs: [EntityID<ActionRevision>] = [],
        workflowState: CaseWorkflowState = .candidate,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.promiseID = promiseID
        self.currentPromiseRevisionID = currentPromiseRevisionID
        self.activeCriterionRevisionIDs = activeCriterionRevisionIDs
        self.currentActionRevisionIDs = currentActionRevisionIDs
        self.workflowState = workflowState
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public struct Promise: Equatable {
    public let id: EntityID<Promise>
    public let caseID: EntityID<Case>
    public let currentRevisionID: EntityID<PromiseRevision>
    public let createdAt: Date
    public init(
        id: EntityID<Promise> = .init(),
        caseID: EntityID<Case>,
        currentRevisionID: EntityID<PromiseRevision>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.caseID = caseID
        self.currentRevisionID = currentRevisionID
        self.createdAt = createdAt
    }
}

public struct PromiseRevision: Equatable {
    public let id: EntityID<PromiseRevision>
    public let promiseID: EntityID<Promise>
    public let quote: AssertedValue<NonEmptyText>
    public let thesis: NonEmptyText
    public let statementDate: AssertedValue<DatedValue>
    public let context: AssertedValue<NonEmptyText>
    public let targetGroup: AssertedValue<NonEmptyText>
    public let conditions: AssertedValue<[NonEmptyText]>
    public let responsibility: AssertedValue<NonEmptyText>
    public let speaker: AssertedValue<EntityID<Actor>>
    public let party: AssertedValue<EntityID<Actor>>
    public let topics: [NonEmptyText]
    public let metadata: RevisionMetadata
    public init(
        id: EntityID<PromiseRevision> = .init(),
        promiseID: EntityID<Promise>,
        quote: AssertedValue<NonEmptyText>,
        thesis: NonEmptyText,
        statementDate: AssertedValue<DatedValue>,
        context: AssertedValue<NonEmptyText>,
        targetGroup: AssertedValue<NonEmptyText>,
        conditions: AssertedValue<[NonEmptyText]>,
        responsibility: AssertedValue<NonEmptyText>,
        speaker: AssertedValue<EntityID<Actor>>,
        party: AssertedValue<EntityID<Actor>>,
        topics: [NonEmptyText] = [],
        metadata: RevisionMetadata
    ) {
        self.id = id
        self.promiseID = promiseID
        self.quote = quote
        self.thesis = thesis
        self.statementDate = statementDate
        self.context = context
        self.targetGroup = targetGroup
        self.conditions = conditions
        self.responsibility = responsibility
        self.speaker = speaker
        self.party = party
        self.topics = topics
        self.metadata = metadata
    }
}

public struct EvaluationCriterion: Equatable {
    public let id: EntityID<EvaluationCriterion>
    public let promiseID: EntityID<Promise>
    public let currentRevisionID: EntityID<CriterionRevision>
    public let createdAt: Date
    public init(
        id: EntityID<EvaluationCriterion> = .init(),
        promiseID: EntityID<Promise>,
        currentRevisionID: EntityID<CriterionRevision>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.promiseID = promiseID
        self.currentRevisionID = currentRevisionID
        self.createdAt = createdAt
    }
}

public struct CriterionRevision: Equatable {
    public let id: EntityID<CriterionRevision>
    public let criterionID: EntityID<EvaluationCriterion>
    public let promiseRevisionID: EntityID<PromiseRevision>
    public let goal: NonEmptyText
    public let targetGroup: NonEmptyText
    public let baseline: FieldValue<NonEmptyText>
    public let deadline: DatedValue
    public let conditions: FieldValue<[NonEmptyText]>
    public let isCore: Bool
    public let materialityRule: NonEmptyText
    public let weight: Double?
    public let weightReason: NonEmptyText?
    public let metadata: RevisionMetadata
    public let state: CriterionRevisionState
    public let confirmation: HumanReview?
    public init(
        id: EntityID<CriterionRevision> = .init(),
        criterionID: EntityID<EvaluationCriterion>,
        promiseRevisionID: EntityID<PromiseRevision>,
        goal: NonEmptyText,
        targetGroup: NonEmptyText,
        baseline: FieldValue<NonEmptyText>,
        deadline: DatedValue,
        conditions: FieldValue<[NonEmptyText]>,
        isCore: Bool,
        materialityRule: NonEmptyText,
        weight: Double? = nil,
        weightReason: NonEmptyText? = nil,
        metadata: RevisionMetadata,
        state: CriterionRevisionState = .draft,
        confirmation: HumanReview? = nil
    ) {
        self.id = id
        self.criterionID = criterionID
        self.promiseRevisionID = promiseRevisionID
        self.goal = goal
        self.targetGroup = targetGroup
        self.baseline = baseline
        self.deadline = deadline
        self.conditions = conditions
        self.isCore = isCore
        self.materialityRule = materialityRule
        self.weight = weight
        self.weightReason = weightReason
        self.metadata = metadata
        self.state = state
        self.confirmation = confirmation
    }
}
