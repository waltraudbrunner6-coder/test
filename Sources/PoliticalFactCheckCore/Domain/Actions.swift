import Foundation

public struct ActionOrDevelopment: Equatable {
    public let id: EntityID<ActionOrDevelopment>
    public let caseID: EntityID<Case>
    public let currentRevisionID: EntityID<ActionRevision>
    public let createdAt: Date
    public init(
        id: EntityID<ActionOrDevelopment> = .init(),
        caseID: EntityID<Case>,
        currentRevisionID: EntityID<ActionRevision>,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.caseID = caseID
        self.currentRevisionID = currentRevisionID
        self.createdAt = createdAt
    }
}

public struct ActionRevision: Equatable {
    public let id: EntityID<ActionRevision>
    public let actionID: EntityID<ActionOrDevelopment>
    public let type: ActionType
    public let title: NonEmptyText
    public let description: AssertedValue<NonEmptyText>
    public let eventDate: AssertedValue<DatedValue>
    public let validity: DatedValue?
    public let institutionalLevel: NonEmptyText?
    public let objectIdentifier: NonEmptyText?
    public let proceduralState: NonEmptyText
    public let scope: AssertedValue<NonEmptyText>
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let participationIDs: [EntityID<ActionParticipation>]
    public let metadata: RevisionMetadata
    public init(
        id: EntityID<ActionRevision> = .init(),
        actionID: EntityID<ActionOrDevelopment>,
        type: ActionType,
        title: NonEmptyText,
        description: AssertedValue<NonEmptyText>,
        eventDate: AssertedValue<DatedValue>,
        validity: DatedValue? = nil,
        institutionalLevel: NonEmptyText? = nil,
        objectIdentifier: NonEmptyText? = nil,
        proceduralState: NonEmptyText,
        scope: AssertedValue<NonEmptyText>,
        excerptIDs: [EntityID<SourceExcerpt>] = [],
        participationIDs: [EntityID<ActionParticipation>] = [],
        metadata: RevisionMetadata
    ) {
        self.id = id
        self.actionID = actionID
        self.type = type
        self.title = title
        self.description = description
        self.eventDate = eventDate
        self.validity = validity
        self.institutionalLevel = institutionalLevel
        self.objectIdentifier = objectIdentifier
        self.proceduralState = proceduralState
        self.scope = scope
        self.excerptIDs = excerptIDs
        self.participationIDs = participationIDs
        self.metadata = metadata
    }
}

public struct ActionParticipation: Equatable {
    public let id: EntityID<ActionParticipation>
    public let actionRevisionID: EntityID<ActionRevision>
    public let actorID: EntityID<Actor>
    public let role: NonEmptyText
    public let kind: ParticipationKind
    public let rationale: NonEmptyText?
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let verification: FactVerificationState
    public let review: HumanReview?
    public init(
        id: EntityID<ActionParticipation> = .init(),
        actionRevisionID: EntityID<ActionRevision>,
        actorID: EntityID<Actor>,
        role: NonEmptyText,
        kind: ParticipationKind,
        rationale: NonEmptyText? = nil,
        excerptIDs: [EntityID<SourceExcerpt>] = [],
        verification: FactVerificationState = .unreviewed,
        review: HumanReview? = nil
    ) {
        self.id = id
        self.actionRevisionID = actionRevisionID
        self.actorID = actorID
        self.role = role
        self.kind = kind
        self.rationale = rationale
        self.excerptIDs = excerptIDs
        self.verification = verification
        self.review = review
    }
}

public struct EvidenceLink: Equatable {
    public let id: EntityID<EvidenceLink>
    public let criterionRevisionID: EntityID<CriterionRevision>
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let actionRevisionID: EntityID<ActionRevision>?
    public let relationship: EvidenceRelationship
    public let directness: EvidenceDirectness
    public let rationale: NonEmptyText
    public let temporalReference: DatedValue
    public let status: EvidenceLinkStatus
    public let review: HumanReview?
    public let metadata: RevisionMetadata
    public init(
        id: EntityID<EvidenceLink> = .init(),
        criterionRevisionID: EntityID<CriterionRevision>,
        excerptIDs: [EntityID<SourceExcerpt>],
        actionRevisionID: EntityID<ActionRevision>? = nil,
        relationship: EvidenceRelationship,
        directness: EvidenceDirectness,
        rationale: NonEmptyText,
        temporalReference: DatedValue,
        status: EvidenceLinkStatus = .draft,
        review: HumanReview? = nil,
        metadata: RevisionMetadata
    ) {
        self.id = id
        self.criterionRevisionID = criterionRevisionID
        self.excerptIDs = excerptIDs
        self.actionRevisionID = actionRevisionID
        self.relationship = relationship
        self.directness = directness
        self.rationale = rationale
        self.temporalReference = temporalReference
        self.status = status
        self.review = review
        self.metadata = metadata
    }
}
