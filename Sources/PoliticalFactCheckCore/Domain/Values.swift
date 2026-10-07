import Foundation

/// Phantom type prevents, for example, an Actor ID being used as a Reviewer ID.
public struct EntityID<Entity>: Hashable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum ValueError: Error, Equatable {
    case blankText, invalidDateInterval, invalidDatePrecision, invalidTimeZone, invalidHash
}

public struct NonEmptyText: Equatable, Hashable {
    public let value: String
    public init(_ value: String) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ValueError.blankText }
        self.value = value
    }
}

public enum FieldValue<Value> {
    case known(Value)
    case unknown(reason: NonEmptyText)
    case notApplicable(reason: NonEmptyText)
    public var knownValue: Value? {
        if case .known(let value) = self { return value }
        return nil
    }
}
extension FieldValue: Equatable where Value: Equatable {}

public struct HumanReview: Equatable {
    public let reviewerID: EntityID<ReviewerIdentity>
    public let reviewedAt: Date
    public init(reviewerID: EntityID<ReviewerIdentity>, reviewedAt: Date) {
        self.reviewerID = reviewerID
        self.reviewedAt = reviewedAt
    }
}

public enum Authorship: Equatable {
    case human(EntityID<ReviewerIdentity>)
    case ai(model: NonEmptyText, templateVersion: String?)
    case system
}

public struct AssertedValue<Value> {
    public let content: FieldValue<Value>
    public let provenance: Provenance
    public let verification: FactVerificationState
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let review: HumanReview?
    public init(content: FieldValue<Value>, provenance: Provenance,
                verification: FactVerificationState = .unreviewed,
                excerptIDs: [EntityID<SourceExcerpt>] = [], review: HumanReview? = nil) throws {
        if case .known(let value) = content, let text = value as? String {
            _ = try NonEmptyText(text)
        }
        self.content = content; self.provenance = provenance; self.verification = verification
        self.excerptIDs = excerptIDs; self.review = review
    }
}
extension AssertedValue: Equatable where Value: Equatable {}

/// Domain interval, including open bounds; distinct from Foundation.DateInterval.
public struct DateInterval: Equatable {
    public let start: Date?
    public let end: Date?
    public let endInclusive: Bool
    public init(start: Date?, end: Date?, endInclusive: Bool = false) throws {
        guard start != nil || end != nil else { throw ValueError.invalidDateInterval }
        if let start = start, let end = end {
            guard start < end || (start == end && endInclusive) else { throw ValueError.invalidDateInterval }
        }
        self.start = start; self.end = end; self.endInclusive = endInclusive
    }
}

public struct DatedValue: Equatable {
    public let role: DateRole
    public let precision: DatePrecision
    public let content: FieldValue<DateInterval>
    public let timeZoneIdentifier: String?
    public init(role: DateRole, precision: DatePrecision, content: FieldValue<DateInterval>,
                timeZoneIdentifier: String? = nil) throws {
        if let zone = timeZoneIdentifier, TimeZone(identifier: zone) == nil { throw ValueError.invalidTimeZone }
        if let interval = content.knownValue {
            if precision == .instant {
                guard interval.start != nil, interval.start == interval.end, interval.endInclusive else {
                    throw ValueError.invalidDatePrecision
                }
            } else if precision != .interval {
                guard let start = interval.start, let end = interval.end, start < end else {
                    throw ValueError.invalidDatePrecision
                }
            }
        }
        self.role = role; self.precision = precision; self.content = content
        self.timeZoneIdentifier = timeZoneIdentifier
    }
    public static func instant(_ date: Date, role: DateRole) throws -> DatedValue {
        try DatedValue(role: role, precision: .instant,
                       content: .known(DateInterval(start: date, end: date, endInclusive: true)))
    }
    public static func unknown(role: DateRole, reason: NonEmptyText) throws -> DatedValue {
        try DatedValue(role: role, precision: .interval, content: .unknown(reason: reason))
    }
    public func eligibility(at cutoff: DatedValue) -> TemporalEligibility {
        guard let event = content.knownValue, let limit = cutoff.content.knownValue,
              let cutoffEnd = limit.end else { return .requiresHumanReview }
        if let start = event.start, start > cutoffEnd || (start == cutoffEnd && !limit.endInclusive) {
            return .afterCutoff
        }
        if let end = event.end, end < cutoffEnd || (end == cutoffEnd && (!event.endInclusive || limit.endInclusive)) {
            return .atOrBeforeCutoff
        }
        return .requiresHumanReview
    }
}

public struct RevisionMetadata: Equatable {
    public let number: Int
    public let reason: NonEmptyText
    public let author: Authorship
    public let createdAt: Date
    public init(number: Int, reason: NonEmptyText, author: Authorship, createdAt: Date) {
        self.number = number; self.reason = reason; self.author = author; self.createdAt = createdAt
    }
}

public struct StateSnapshot<Entity, State: Equatable>: Equatable {
    public let id: EntityID<Entity>
    public let state: State
    public init(id: EntityID<Entity>, state: State) { self.id = id; self.state = state }
}

public struct ObjectReference: Equatable {
    public let kind: EntityKind
    public let id: UUID
    public init<Entity>(kind: EntityKind, id: EntityID<Entity>) { self.kind = kind; self.id = id.rawValue }
}

public struct ContentHash: Equatable {
    public let sha256: String
    public init(sha256: String) throws {
        guard sha256.count == 64, sha256.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) else {
            throw ValueError.invalidHash
        }
        self.sha256 = sha256.lowercased()
    }
}
