import Foundation

/// Checks structural prerequisites, never decides political truth or assigns a category.
public enum DomainValidator {
    static func review(_ review: HumanReview?, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        guard let review = review else { result.add(.missingHumanReview); return result }
        if context.find(review.reviewerID) == nil {
            result.add(.missingReference(ObjectReference(kind: .reviewer, id: review.reviewerID)))
        }
        return result
    }

    static func metadata(_ metadata: RevisionMetadata, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if metadata.number < 1 { result.add(.invalidRevisionNumber) }
        if case .human(let id) = metadata.author, context.find(id) == nil {
            result.add(.missingReference(ObjectReference(kind: .reviewer, id: id)))
        }
        return result
    }

    static func role(_ date: DatedValue, expected: DateRole) -> ValidationResult {
        var result = ValidationResult()
        if date.role != expected { result.add(.invalidDateRole(expected: expected, actual: date.role)) }
        return result
    }

    static func excerpts(_ ids: [EntityID<SourceExcerpt>], required: Bool, in context: DomainContext,
                         snapshot: CaseRevision? = nil) -> ValidationResult {
        var result = ValidationResult()
        if required && ids.isEmpty { result.add(.missingEvidenceExcerpt) }
        for id in ids {
            guard let excerpt = context.find(id) else {
                result.add(.missingReference(ObjectReference(kind: .excerpt, id: id))); continue
            }
            let state = snapshot?.excerpts.first(where: { $0.id == id })?.state ?? excerpt.state
            if snapshot != nil && !snapshot!.excerpts.contains(where: { $0.id == id }) {
                result.add(.snapshotMismatch(ObjectReference(kind: .excerpt, id: id)))
            }
            if required && state != .verified { result.add(.excerptNotVerified(id)) }
            result.merge(validate(excerpt, in: context, verifiedAtSnapshot: required && state == .verified))
        }
        return result
    }

    static func assertion<Value>(_ value: AssertedValue<Value>, in context: DomainContext,
                                 snapshot: CaseRevision? = nil) -> ValidationResult {
        var result = ValidationResult()
        if value.verification == .verified {
            if value.content.knownValue == nil { result.add(.unknownVerifiedValue) }
            if let date = value.content.knownValue as? DatedValue, date.content.knownValue == nil {
                result.add(.unknownVerifiedValue)
            }
            result.merge(review(value.review, in: context))
            result.merge(excerpts(value.excerptIDs, required: true, in: context, snapshot: snapshot))
        }
        return result
    }

    public static func validate(_ source: Source, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if source.canonicalURL == nil && source.documentIdentifier == nil { result.add(.missingSourceIdentity) }
        if let origin = source.originSourceID, context.find(origin) == nil {
            result.add(.missingReference(ObjectReference(kind: .source, id: origin)))
        }
        return result
    }

    public static func validate(_ source: SourceVersion, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if let parent = context.find(source.sourceID) { result.merge(validate(parent, in: context)) }
        else { result.add(.missingReference(ObjectReference(kind: .source, id: source.sourceID))) }
        result.merge(role(source.publicationDate, expected: .publication))
        result.merge(role(source.retrievedAt, expected: .retrieval))
        if let event = source.eventDate { result.merge(role(event, expected: .event)) }
        if let validity = source.validity { result.merge(role(validity, expected: .validity)) }
        if source.verification == .verified { result.merge(review(source.review, in: context)) }
        return result
    }

    public static func validate(_ excerpt: SourceExcerpt, in context: DomainContext,
                                verifiedAtSnapshot: Bool = false) -> ValidationResult {
        var result = ValidationResult()
        guard let version = context.find(excerpt.sourceVersionID) else {
            result.add(.missingReference(ObjectReference(kind: .sourceVersion, id: excerpt.sourceVersionID))); return result
        }
        result.merge(validate(version, in: context))
        if excerpt.state == .verified || verifiedAtSnapshot {
            result.merge(review(excerpt.review, in: context))
            // A superseded but formerly checked version remains usable in a historical snapshot.
            if version.verification != .verified && !(verifiedAtSnapshot && version.verification == .superseded) {
                result.add(.sourceVersionNotVerified(version.id))
            }
        }
        if let original = excerpt.translationOfExcerptID, context.find(original) == nil {
            result.add(.missingReference(ObjectReference(kind: .excerpt, id: original)))
        }
        return result
    }

    public static func validate(_ promise: PromiseRevision, in context: DomainContext) -> ValidationResult {
        var result = metadata(promise.metadata, in: context)
        if context.find(promise.promiseID) == nil {
            result.add(.missingReference(ObjectReference(kind: .promise, id: promise.promiseID)))
        }
        result.merge(assertion(promise.quote, in: context))
        if promise.quote.verification == .verified && promise.quote.excerptIDs.isEmpty { result.add(.missingOriginalExcerpt) }
        if let quote = promise.quote.content.knownValue, promise.quote.verification == .verified {
            if !promise.quote.excerptIDs.contains(where: { context.find($0)?.text == quote }) {
                result.add(.relationshipMismatch(ObjectReference(kind: .promiseRevision, id: promise.id)))
            }
        }
        result.merge(assertion(promise.statementDate, in: context))
        if let date = promise.statementDate.content.knownValue { result.merge(role(date, expected: .statement)) }
        result.merge(assertion(promise.context, in: context)); result.merge(assertion(promise.targetGroup, in: context))
        result.merge(assertion(promise.conditions, in: context)); result.merge(assertion(promise.responsibility, in: context))
        result.merge(assertion(promise.speaker, in: context)); result.merge(assertion(promise.party, in: context))
        for id in [promise.speaker.content.knownValue, promise.party.content.knownValue].compactMap({ $0 }) {
            if context.find(id) == nil { result.add(.missingReference(ObjectReference(kind: .actor, id: id))) }
        }
        return result
    }

    public static func validate(_ criterion: CriterionRevision, in context: DomainContext) -> ValidationResult {
        var result = metadata(criterion.metadata, in: context)
        if let parent = context.find(criterion.criterionID), let promise = context.find(criterion.promiseRevisionID) {
            if parent.promiseID != promise.promiseID { result.add(.relationshipMismatch(ObjectReference(kind: .criterionRevision, id: criterion.id))) }
        } else {
            if context.find(criterion.criterionID) == nil { result.add(.missingReference(ObjectReference(kind: .criterion, id: criterion.criterionID))) }
            if context.find(criterion.promiseRevisionID) == nil { result.add(.missingReference(ObjectReference(kind: .promiseRevision, id: criterion.promiseRevisionID))) }
        }
        result.merge(role(criterion.deadline, expected: .deadline))
        if criterion.state == .confirmed || criterion.state == .superseded {
            result.merge(review(criterion.confirmation, in: context))
            if let confirmation = criterion.confirmation, confirmation.reviewedAt < criterion.metadata.createdAt {
                result.add(.invalidReviewTime)
            }
        }
        if let weight = criterion.weight, !weight.isFinite || weight <= 0 || criterion.weightReason == nil {
            result.add(.weightWithoutJustification)
        }
        return result
    }

    public static func validate(_ action: ActionRevision, in context: DomainContext,
                                snapshot: CaseRevision? = nil) -> ValidationResult {
        var result = metadata(action.metadata, in: context)
        if context.find(action.actionID) == nil { result.add(.missingReference(ObjectReference(kind: .action, id: action.actionID))) }
        result.merge(assertion(action.description, in: context, snapshot: snapshot)); result.merge(assertion(action.eventDate, in: context, snapshot: snapshot))
        result.merge(assertion(action.scope, in: context, snapshot: snapshot))
        if let date = action.eventDate.content.knownValue { result.merge(role(date, expected: .event)) }
        if let validity = action.validity { result.merge(role(validity, expected: .validity)) }
        result.merge(excerpts(action.excerptIDs, required: false, in: context, snapshot: snapshot))
        for id in action.participationIDs {
            guard let participation = context.find(id) else {
                result.add(.missingReference(ObjectReference(kind: .participation, id: id))); continue
            }
            if participation.actionRevisionID != action.id { result.add(.relationshipMismatch(ObjectReference(kind: .participation, id: id))) }
            result.merge(validate(participation, in: context, snapshot: snapshot))
        }
        return result
    }

    public static func validate(_ participation: ActionParticipation, in context: DomainContext,
                                snapshot: CaseRevision? = nil) -> ValidationResult {
        var result = ValidationResult()
        if context.find(participation.actorID) == nil { result.add(.missingReference(ObjectReference(kind: .actor, id: participation.actorID))) }
        if context.find(participation.actionRevisionID) == nil { result.add(.missingReference(ObjectReference(kind: .actionRevision, id: participation.actionRevisionID))) }
        if participation.verification == .verified || snapshot?.participations.contains(where: { $0.id == participation.id && $0.state == .verified }) == true {
            result.merge(review(participation.review, in: context))
            result.merge(excerpts(participation.excerptIDs, required: true, in: context, snapshot: snapshot))
        }
        if participation.kind == .causalResponsibility && (participation.excerptIDs.isEmpty || participation.review == nil) {
            result.add(.causalAttributionWithoutEvidence)
        }
        return result
    }

    public static func validate(_ link: EvidenceLink, in context: DomainContext,
                                snapshot: CaseRevision? = nil) -> ValidationResult {
        var result = metadata(link.metadata, in: context)
        if context.find(link.criterionRevisionID) == nil {
            result.add(.missingReference(ObjectReference(kind: .criterionRevision, id: link.criterionRevisionID)))
        }
        // Draft links also need real excerpt references; tasks/actions cannot stand in for them.
        if link.excerptIDs.isEmpty { result.add(.missingEvidenceExcerpt) }
        let verified = link.status == .verified || snapshot?.evidenceLinks.contains(where: { $0.id == link.id && $0.state == .verified }) == true
        result.merge(excerpts(link.excerptIDs, required: verified, in: context, snapshot: snapshot))
        if verified { result.merge(review(link.review, in: context)) }
        if link.temporalReference.role != .event && link.temporalReference.role != .validity {
            result.add(.invalidDateRole(expected: .event, actual: link.temporalReference.role))
        }
        if let id = link.actionRevisionID {
            if context.find(id) == nil { result.add(.missingReference(ObjectReference(kind: .actionRevision, id: id))) }
        }
        return result
    }
}
