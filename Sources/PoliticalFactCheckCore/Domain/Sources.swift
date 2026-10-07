import Foundation

public struct Source: Equatable {
    public let id: EntityID<Source>
    public let canonicalURL: URL?
    public let documentIdentifier: NonEmptyText?
    public let originSourceID: EntityID<Source>?
    public let createdAt: Date
    public init(
        id: EntityID<Source> = .init(),
        canonicalURL: URL? = nil,
        documentIdentifier: NonEmptyText? = nil,
        originSourceID: EntityID<Source>? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.canonicalURL = canonicalURL
        self.documentIdentifier = documentIdentifier
        self.originSourceID = originSourceID
        self.createdAt = createdAt
    }
}

public struct SourceVersion: Equatable {
    public let id: EntityID<SourceVersion>
    public let sourceID: EntityID<Source>
    public let kind: SourceVersionKind
    public let requestedURL: URL?
    public let finalURL: URL?
    public let archiveURL: URL?
    public let title: NonEmptyText?
    public let publisher: NonEmptyText?
    public let author: NonEmptyText?
    public let publicationDate: DatedValue
    public let retrievedAt: DatedValue
    public let eventDate: DatedValue?
    public let validity: DatedValue?
    public let availability: SourceAvailability
    public let verification: FactVerificationState
    public let review: HumanReview?
    public let contentType: NonEmptyText
    public let language: NonEmptyText
    public let localCopyReference: NonEmptyText?
    public let hash: ContentHash?
    public init(
        id: EntityID<SourceVersion> = .init(),
        sourceID: EntityID<Source>,
        kind: SourceVersionKind = .unknown,
        requestedURL: URL? = nil,
        finalURL: URL? = nil,
        archiveURL: URL? = nil,
        title: NonEmptyText? = nil,
        publisher: NonEmptyText? = nil,
        author: NonEmptyText? = nil,
        publicationDate: DatedValue,
        retrievedAt: DatedValue,
        eventDate: DatedValue? = nil,
        validity: DatedValue? = nil,
        availability: SourceAvailability = .unknown,
        verification: FactVerificationState = .unreviewed,
        review: HumanReview? = nil,
        contentType: NonEmptyText,
        language: NonEmptyText,
        localCopyReference: NonEmptyText? = nil,
        hash: ContentHash? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.kind = kind
        self.requestedURL = requestedURL
        self.finalURL = finalURL
        self.archiveURL = archiveURL
        self.title = title
        self.publisher = publisher
        self.author = author
        self.publicationDate = publicationDate
        self.retrievedAt = retrievedAt
        self.eventDate = eventDate
        self.validity = validity
        self.availability = availability
        self.verification = verification
        self.review = review
        self.contentType = contentType
        self.language = language
        self.localCopyReference = localCopyReference
        self.hash = hash
    }
}

public struct SourceExcerpt: Equatable {
    public let id: EntityID<SourceExcerpt>
    public let sourceVersionID: EntityID<SourceVersion>
    public let locator: NonEmptyText
    public let text: NonEmptyText
    public let context: NonEmptyText
    public let language: NonEmptyText
    public let translationOfExcerptID: EntityID<SourceExcerpt>?
    public let provenance: Provenance
    public let state: ExcerptVerificationState
    public let review: HumanReview?
    public let createdAt: Date
    public init(
        id: EntityID<SourceExcerpt> = .init(),
        sourceVersionID: EntityID<SourceVersion>,
        locator: NonEmptyText,
        text: NonEmptyText,
        context: NonEmptyText,
        language: NonEmptyText,
        translationOfExcerptID: EntityID<SourceExcerpt>? = nil,
        provenance: Provenance = .humanEntered,
        state: ExcerptVerificationState = .unverified,
        review: HumanReview? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceVersionID = sourceVersionID
        self.locator = locator
        self.text = text
        self.context = context
        self.language = language
        self.translationOfExcerptID = translationOfExcerptID
        self.provenance = provenance
        self.state = state
        self.review = review
        self.createdAt = createdAt
    }
}
