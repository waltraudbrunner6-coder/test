import Foundation

public struct ReviewerIdentity: Equatable {
    public let id: EntityID<ReviewerIdentity>
    public let displayName: NonEmptyText
    public let note: String?
    public init(
        id: EntityID<ReviewerIdentity> = .init(),
        displayName: NonEmptyText,
        note: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.note = note
    }
}

public struct Actor: Equatable {
    public let id: EntityID<Actor>
    public let name: NonEmptyText
    public let type: ActorType
    public let description: String?
    public let affiliationIDs: [EntityID<ActorAffiliation>]
    public init(
        id: EntityID<Actor> = .init(),
        name: NonEmptyText,
        type: ActorType,
        description: String? = nil,
        affiliationIDs: [EntityID<ActorAffiliation>] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.affiliationIDs = affiliationIDs
    }
}

public struct ActorAffiliation: Equatable {
    public let id: EntityID<ActorAffiliation>
    public let actorID: EntityID<Actor>
    public let associatedActorID: EntityID<Actor>?
    public let role: NonEmptyText
    public let validity: DatedValue
    public let verification: FactVerificationState
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let review: HumanReview?
    public init(
        id: EntityID<ActorAffiliation> = .init(),
        actorID: EntityID<Actor>,
        associatedActorID: EntityID<Actor>? = nil,
        role: NonEmptyText,
        validity: DatedValue,
        verification: FactVerificationState = .unreviewed,
        excerptIDs: [EntityID<SourceExcerpt>] = [],
        review: HumanReview? = nil
    ) {
        self.id = id
        self.actorID = actorID
        self.associatedActorID = associatedActorID
        self.role = role
        self.validity = validity
        self.verification = verification
        self.excerptIDs = excerptIDs
        self.review = review
    }
}
