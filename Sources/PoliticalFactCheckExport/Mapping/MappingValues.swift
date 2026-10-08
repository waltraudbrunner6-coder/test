// Frozen portable v1 DTO mapping. Independent of SwiftData/store payloads.
import Foundation
import PoliticalFactCheckCore

struct StoredID: Codable, Equatable, Hashable {
    var kind: String
    var value: UUID
    init<Entity>(_ id: EntityID<Entity>, kind: String) { self.kind = kind; value = id.rawValue }
    func domain<Entity>(_ type: Entity.Type, kind expected: String) throws -> EntityID<Entity> {
        guard kind == expected else { throw ArchiveMappingError.wrongIDType(expected: expected, actual: kind, id: value) }
        return EntityID<Entity>(value)
    }
}

enum FieldDTO<Value: Codable & Equatable>: Codable, Equatable {
    case known(Value)
    case unknown(String)
    case notApplicable(String)
    init<Domain>(_ value: FieldValue<Domain>, map: (Domain) -> Value) {
        switch value {
        case .known(let value): self = .known(map(value))
        case .unknown(let reason): self = .unknown(reason.value)
        case .notApplicable(let reason): self = .notApplicable(reason.value)
        }
    }
    func domain<Domain>(_ map: (Value) throws -> Domain) throws -> FieldValue<Domain> {
        switch self {
        case .known(let value): return .known(try map(value))
        case .unknown(let reason): return .unknown(reason: try NonEmptyText(reason))
        case .notApplicable(let reason): return .notApplicable(reason: try NonEmptyText(reason))
        }
    }
}

struct ReviewDTO: Codable, Equatable {
    var reviewerID: StoredID
    var reviewedAt: Date
    init(_ value: HumanReview) {
        reviewerID = StoredID(value.reviewerID, kind: "ReviewerIdentity"); reviewedAt = value.reviewedAt
    }
    func domain() throws -> HumanReview {
        HumanReview(reviewerID: try reviewerID.domain(ReviewerIdentity.self, kind: "ReviewerIdentity"), reviewedAt: reviewedAt)
    }
}

enum AuthorshipDTO: Codable, Equatable {
    case human(StoredID)
    case ai(model: String, templateVersion: String?)
    case system
    init(_ value: Authorship) {
        switch value {
        case .human(let id): self = .human(StoredID(id, kind: "ReviewerIdentity"))
        case .ai(let model, let version): self = .ai(model: model.value, templateVersion: version)
        case .system: self = .system
        }
    }
    func domain() throws -> Authorship {
        switch self {
        case .human(let id): return .human(try id.domain(ReviewerIdentity.self, kind: "ReviewerIdentity"))
        case .ai(let model, let version): return .ai(model: try NonEmptyText(model), templateVersion: version)
        case .system: return .system
        }
    }
}

struct AssertedDTO<Value: Codable & Equatable>: Codable, Equatable {
    var content: FieldDTO<Value>
    var provenance: String
    var verification: String
    var excerptIDs: [StoredID]
    var review: ReviewDTO?
    init<Domain>(_ value: AssertedValue<Domain>, map: (Domain) -> Value) {
        content = FieldDTO(value.content, map: map); provenance = write(value.provenance)
        verification = write(value.verification)
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        review = value.review.map(ReviewDTO.init)
    }
    func domain<Domain>(_ map: (Value) throws -> Domain) throws -> AssertedValue<Domain> {
        try AssertedValue(content: content.domain(map), provenance: readProvenance(provenance),
            verification: readFactVerificationState(verification),
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            review: review.map { try $0.domain() })
    }
}

struct IntervalDTO: Codable, Equatable {
    var start: Date?
    var end: Date?
    var endInclusive: Bool
    init(_ value: PoliticalFactCheckCore.DateInterval) {
        start = value.start; end = value.end; endInclusive = value.endInclusive
    }
    func domain() throws -> PoliticalFactCheckCore.DateInterval {
        try PoliticalFactCheckCore.DateInterval(start: start, end: end, endInclusive: endInclusive)
    }
}

struct DatedDTO: Codable, Equatable {
    var role: String
    var precision: String
    var content: FieldDTO<IntervalDTO>
    var timeZoneIdentifier: String?
    init(_ value: DatedValue) {
        role = write(value.role); precision = write(value.precision)
        content = FieldDTO(value.content, map: IntervalDTO.init); timeZoneIdentifier = value.timeZoneIdentifier
    }
    func domain() throws -> DatedValue {
        try DatedValue(role: readDateRole(role), precision: readDatePrecision(precision),
            content: content.domain { try $0.domain() }, timeZoneIdentifier: timeZoneIdentifier)
    }
}

struct MetadataDTO: Codable, Equatable {
    var number: Int
    var reason: String
    var author: AuthorshipDTO
    var createdAt: Date
    init(_ value: RevisionMetadata) {
        number = value.number; reason = value.reason.value; author = AuthorshipDTO(value.author); createdAt = value.createdAt
    }
    func domain() throws -> RevisionMetadata {
        try RevisionMetadata(number: number, reason: NonEmptyText(reason), author: author.domain(), createdAt: createdAt)
    }
}

struct StateDTO: Codable, Equatable {
    var id: StoredID
    var state: String
}

struct ReferenceDTO: Codable, Equatable {
    var kind: String
    var id: UUID
    init(_ value: ObjectReference) { kind = write(value.kind); id = value.id }
    func domain() throws -> ObjectReference { try readReference(kind: readEntityKind(kind), id: id) }
}

func readURL(_ value: String) throws -> URL {
    guard let url = URL(string: value) else { throw ArchiveMappingError.invalidValue(detail: "Invalid stored URL") }
    return url
}

func readReference(kind: EntityKind, id: UUID) throws -> ObjectReference {
    switch kind {
    case .reviewer: return ObjectReference(kind: kind, id: EntityID<ReviewerIdentity>(id))
    case .politicalCase: return ObjectReference(kind: kind, id: EntityID<Case>(id))
    case .actor: return ObjectReference(kind: kind, id: EntityID<Actor>(id))
    case .affiliation: return ObjectReference(kind: kind, id: EntityID<ActorAffiliation>(id))
    case .promise: return ObjectReference(kind: kind, id: EntityID<Promise>(id))
    case .promiseRevision: return ObjectReference(kind: kind, id: EntityID<PromiseRevision>(id))
    case .criterion: return ObjectReference(kind: kind, id: EntityID<EvaluationCriterion>(id))
    case .criterionRevision: return ObjectReference(kind: kind, id: EntityID<CriterionRevision>(id))
    case .source: return ObjectReference(kind: kind, id: EntityID<Source>(id))
    case .sourceVersion: return ObjectReference(kind: kind, id: EntityID<SourceVersion>(id))
    case .excerpt: return ObjectReference(kind: kind, id: EntityID<SourceExcerpt>(id))
    case .action: return ObjectReference(kind: kind, id: EntityID<ActionOrDevelopment>(id))
    case .actionRevision: return ObjectReference(kind: kind, id: EntityID<ActionRevision>(id))
    case .participation: return ObjectReference(kind: kind, id: EntityID<ActionParticipation>(id))
    case .evidenceLink: return ObjectReference(kind: kind, id: EntityID<EvidenceLink>(id))
    case .caseRevision: return ObjectReference(kind: kind, id: EntityID<CaseRevision>(id))
    case .criterionEvaluation: return ObjectReference(kind: kind, id: EntityID<CriterionEvaluation>(id))
    case .caseEvaluation: return ObjectReference(kind: kind, id: EntityID<CaseEvaluation>(id))
    case .methodology: return ObjectReference(kind: kind, id: EntityID<MethodologyVersion>(id))
    case .researchTask: return ObjectReference(kind: kind, id: EntityID<ResearchTask>(id))
    case .auditEntry: return ObjectReference(kind: kind, id: EntityID<AuditEntry>(id))
    case .script: return ObjectReference(kind: kind, id: EntityID<ScriptDraft>(id))
    case .statement: return ObjectReference(kind: kind, id: EntityID<ScriptStatement>(id))
    }
}
