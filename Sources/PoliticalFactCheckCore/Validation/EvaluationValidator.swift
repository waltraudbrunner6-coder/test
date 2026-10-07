import Foundation

extension DomainValidator {
    static func checkReferences<Entity>(_ ids: [EntityID<Entity>], kind: EntityKind,
                                        exists: (EntityID<Entity>) -> Bool) -> ValidationResult {
        var result = ValidationResult()
        var seen = Set<EntityID<Entity>>()
        for id in ids {
            if !seen.insert(id).inserted { result.add(.duplicateReference(ObjectReference(kind: kind, id: id))) }
            if !exists(id) { result.add(.missingReference(ObjectReference(kind: kind, id: id))) }
        }
        return result
    }

    public static func validate(_ snapshot: CaseRevision, in context: DomainContext) -> ValidationResult {
        var result = metadata(snapshot.metadata, in: context)
        guard let politicalCase = context.find(snapshot.caseID), let promise = context.find(snapshot.promiseRevisionID) else {
            if context.find(snapshot.caseID) == nil { result.add(.missingReference(ObjectReference(kind: .politicalCase, id: snapshot.caseID))) }
            if context.find(snapshot.promiseRevisionID) == nil { result.add(.missingReference(ObjectReference(kind: .promiseRevision, id: snapshot.promiseRevisionID))) }
            return result
        }
        if promise.promiseID != politicalCase.promiseID { result.add(.relationshipMismatch(ObjectReference(kind: .promiseRevision, id: promise.id))) }
        if snapshot.criteria.isEmpty { result.add(.missingCriteria) }
        result.merge(checkReferences(snapshot.criteria.map { $0.id }, kind: .criterionRevision) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.actionRevisionIDs, kind: .actionRevision) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.excerpts.map { $0.id }, kind: .excerpt) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.sourceVersions.map { $0.id }, kind: .sourceVersion) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.evidenceLinks.map { $0.id }, kind: .evidenceLink) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.researchTasks.map { $0.id }, kind: .researchTask) { context.find($0) != nil })
        result.merge(checkReferences(snapshot.participations.map { $0.id }, kind: .participation) { context.find($0) != nil })
        var criterionIdentities = Set<EntityID<EvaluationCriterion>>()
        for entry in snapshot.criteria {
            guard let criterion = context.find(entry.id) else { continue }
            if !criterionIdentities.insert(criterion.criterionID).inserted { result.add(.duplicateReference(ObjectReference(kind: .criterion, id: criterion.criterionID))) }
            if criterion.promiseRevisionID != promise.id { result.add(.snapshotMismatch(ObjectReference(kind: .criterionRevision, id: entry.id))) }
            if entry.state != .confirmed || criterion.confirmation == nil ||
                (criterion.state != .confirmed && criterion.state != .superseded) {
                result.add(.criterionNotConfirmed(entry.id))
            }
            result.merge(validate(criterion, in: context))
            if let confirmation = criterion.confirmation, confirmation.reviewedAt > snapshot.metadata.createdAt { result.add(.invalidReviewTime) }
        }
        for entry in snapshot.sourceVersions {
            guard let version = context.find(entry.id) else { continue }
            result.merge(validate(version, in: context))
            if entry.state == .verified {
                result.merge(review(version.review, in: context))
                if version.verification != .verified && version.verification != .superseded { result.add(.snapshotMismatch(ObjectReference(kind: .sourceVersion, id: entry.id))) }
            }
        }
        for entry in snapshot.excerpts {
            guard let excerpt = context.find(entry.id) else { continue }
            if !snapshot.sourceVersions.contains(where: { $0.id == excerpt.sourceVersionID }) { result.add(.snapshotMismatch(ObjectReference(kind: .sourceVersion, id: excerpt.sourceVersionID))) }
            if entry.state == .verified && excerpt.state != .verified && excerpt.state != .superseded {
                result.add(.snapshotMismatch(ObjectReference(kind: .excerpt, id: excerpt.id)))
            }
            if entry.state == .verified && !snapshot.sourceVersions.contains(where: { $0.id == excerpt.sourceVersionID && $0.state == .verified }) {
                result.add(.snapshotMismatch(ObjectReference(kind: .sourceVersion, id: excerpt.sourceVersionID)))
            }
            result.merge(validate(excerpt, in: context, verifiedAtSnapshot: entry.state == .verified))
            if let review = excerpt.review, review.reviewedAt > snapshot.metadata.createdAt { result.add(.invalidReviewTime) }
        }
        for entry in snapshot.evidenceLinks {
            guard let link = context.find(entry.id) else { continue }
            if entry.state != .verified || (link.status != .verified && link.status != .superseded) { result.add(.evidenceLinkNotVerified(link.id)) }
            if !snapshot.criteria.contains(where: { $0.id == link.criterionRevisionID }) { result.add(.snapshotMismatch(ObjectReference(kind: .criterionRevision, id: link.criterionRevisionID))) }
            if let id = link.actionRevisionID, !snapshot.actionRevisionIDs.contains(id) { result.add(.snapshotMismatch(ObjectReference(kind: .actionRevision, id: id))) }
            result.merge(validate(link, in: context, snapshot: snapshot))
            if let review = link.review, review.reviewedAt > snapshot.metadata.createdAt { result.add(.invalidReviewTime) }
        }
        for id in snapshot.actionRevisionIDs {
            guard let action = context.find(id) else { continue }
            result.merge(validate(action, in: context, snapshot: snapshot))
            if let root = context.find(action.actionID), root.caseID != snapshot.caseID { result.add(.relationshipMismatch(ObjectReference(kind: .actionRevision, id: id))) }
            for participationID in action.participationIDs {
                if !snapshot.participations.contains(where: { $0.id == participationID }) { result.add(.snapshotMismatch(ObjectReference(kind: .participation, id: participationID))) }
            }
        }
        for entry in snapshot.participations {
            guard let participation = context.find(entry.id) else { continue }
            if entry.state == .verified && participation.verification != .verified && participation.verification != .superseded {
                result.add(.snapshotMismatch(ObjectReference(kind: .participation, id: entry.id)))
            }
            if !snapshot.actionRevisionIDs.contains(participation.actionRevisionID) { result.add(.snapshotMismatch(ObjectReference(kind: .participation, id: entry.id))) }
            result.merge(validate(participation, in: context, snapshot: snapshot))
        }
        for entry in snapshot.researchTasks {
            if let task = context.find(entry.id), task.caseID != snapshot.caseID { result.add(.relationshipMismatch(ObjectReference(kind: .researchTask, id: entry.id))) }
        }
        return result
    }

    static func category(_ category: EvaluationCategory, confidence: EvidenceConfidence,
                         reasons: [NotVerifiableReason], links: [EvidenceLink], final: Bool) -> ValidationResult {
        var result = ValidationResult()
        let relevant = links.filter { $0.relationship != .contextualizes }
        if category == .notVerifiable && reasons.isEmpty { result.add(.missingNotVerifiableReason) }
        if category == .notFulfilled && relevant.isEmpty { result.add(.emptyEvidenceForNegativeJudgment) }
        if final && (category == .fulfilled || category == .mostlyFulfilled || category == .partiallyFulfilled) &&
            !links.contains(where: { $0.relationship == .supports }) {
            result.add(.positiveJudgmentRequiresSupportingEvidence)
        }
        if category == .contraryAction && !links.contains(where: { $0.relationship == .contradicts }) {
            result.add(.contraryActionRequiresContradictingEvidence)
        }
        if final && confidence == .low && (category == .notFulfilled || category == .contraryAction) {
            result.add(.lowConfidenceNegativeJudgment)
        }
        return result
    }

    static func time(_ date: DatedValue, cutoff: DatedValue) -> ValidationResult {
        var result = ValidationResult()
        switch date.eligibility(at: cutoff) {
        case .afterCutoff: result.add(.eventAfterCutoff)
        case .requiresHumanReview: result.warn(.temporalInterpretationRequired)
        case .atOrBeforeCutoff: break
        }
        return result
    }

    public static func validate(_ evaluation: CriterionEvaluation, snapshot: CaseRevision,
                                cutoff: DatedValue, final: Bool, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if !snapshot.criteria.contains(where: { $0.id == evaluation.criterionRevisionID }) {
            result.add(.snapshotMismatch(ObjectReference(kind: .criterionRevision, id: evaluation.criterionRevisionID)))
        }
        if context.find(evaluation.criterionRevisionID) == nil { result.add(.missingReference(ObjectReference(kind: .criterionRevision, id: evaluation.criterionRevisionID))) }
        result.merge(checkReferences(evaluation.evidenceLinkIDs, kind: .evidenceLink) { context.find($0) != nil })
        for id in evaluation.counterEvidenceLinkIDs where !evaluation.evidenceLinkIDs.contains(id) {
            result.add(.relationshipMismatch(ObjectReference(kind: .evidenceLink, id: id)))
        }
        var links: [EvidenceLink] = []
        for id in evaluation.evidenceLinkIDs {
            guard let link = context.find(id) else { continue }
            if link.criterionRevisionID != evaluation.criterionRevisionID { result.add(.relationshipMismatch(ObjectReference(kind: .evidenceLink, id: id))) }
            if !snapshot.evidenceLinks.contains(where: { $0.id == id && $0.state == .verified }) {
                result.add(.evidenceLinkNotVerified(id))
            } else { links.append(link) }
            result.merge(validate(link, in: context, snapshot: snapshot))
            result.merge(time(link.temporalReference, cutoff: cutoff))
            if let actionID = link.actionRevisionID, let action = context.find(actionID) {
                if let date = action.eventDate.content.knownValue { result.merge(time(date, cutoff: cutoff)) }
                else if let validity = action.validity { result.merge(time(validity, cutoff: cutoff)) }
                else { result.warn(.temporalInterpretationRequired) }
            }
            for excerptID in link.excerptIDs {
                if let excerpt = context.find(excerptID), let version = context.find(excerpt.sourceVersionID),
                   version.publicationDate.eligibility(at: cutoff) == .afterCutoff {
                    result.warn(.retrospectivePublication(version.id))
                }
            }
        }
        result.merge(category(evaluation.category, confidence: evaluation.confidence, reasons: evaluation.notVerifiableReasons, links: links, final: final))
        if final && evaluation.reviewState != .reviewed { result.add(.unreviewedCriterionEvaluation) }
        if evaluation.reviewState == .reviewed { result.merge(review(evaluation.review, in: context)) }
        if evaluation.category == .notFulfilled, let criterion = context.find(evaluation.criterionRevisionID) {
            if criterion.deadline.eligibility(at: cutoff) == .afterCutoff { result.add(.deadlineNotPassed) }
            if criterion.deadline.eligibility(at: cutoff) == .requiresHumanReview { result.warn(.temporalInterpretationRequired) }
        }
        return result
    }

    public static func validate(_ evaluation: CaseEvaluation, in context: DomainContext) -> ValidationResult {
        var result = metadata(evaluation.metadata, in: context)
        result.merge(role(evaluation.cutoff, expected: .evaluationCutoff))
        if evaluation.cutoff.content.knownValue?.end == nil { result.add(.missingCutoff) }
        if context.find(evaluation.methodologyVersionID) == nil { result.add(.missingReference(ObjectReference(kind: .methodology, id: evaluation.methodologyVersionID))) }
        if let replacedID = evaluation.replacesEvaluationID {
            if let previous = context.find(replacedID) {
                if previous.caseID != evaluation.caseID || !previous.hasHistoricalApproval ||
                    previous.metadata.createdAt > evaluation.metadata.createdAt {
                    result.add(.relationshipMismatch(ObjectReference(kind: .caseEvaluation, id: replacedID)))
                }
                result.merge(review(previous.approval, in: context))
            } else { result.add(.missingReference(ObjectReference(kind: .caseEvaluation, id: replacedID))) }
            var visited: Set<EntityID<CaseEvaluation>> = [evaluation.id]
            var next: EntityID<CaseEvaluation>? = replacedID
            while let id = next {
                guard visited.insert(id).inserted else {
                    result.add(.relationshipMismatch(ObjectReference(kind: .caseEvaluation, id: id))); break
                }
                next = context.find(id)?.replacesEvaluationID
            }
        }
        guard let snapshot = context.find(evaluation.caseRevisionID) else {
            result.add(.missingReference(ObjectReference(kind: .caseRevision, id: evaluation.caseRevisionID))); return result
        }
        result.merge(validate(snapshot, in: context))
        if snapshot.caseID != evaluation.caseID { result.add(.relationshipMismatch(ObjectReference(kind: .caseRevision, id: snapshot.id))) }
        let final = evaluation.status == .approved || evaluation.status == .reviewRequired || evaluation.status == .superseded
        if final { result.merge(review(evaluation.approval, in: context)) }
        if final && evaluation.category != .notVerifiable, let promise = context.find(snapshot.promiseRevisionID) {
            if promise.quote.verification != .verified || promise.context.verification != .verified || promise.speaker.verification != .verified {
                result.add(.relationshipMismatch(ObjectReference(kind: .promiseRevision, id: promise.id)))
            }
            result.merge(review(promise.quote.review, in: context))
            result.merge(excerpts(promise.quote.excerptIDs, required: true, in: context, snapshot: snapshot))
        }
        if evaluation.status == .reviewRequired && evaluation.reviewReason == nil { result.add(.missingReviewReason) }
        if let approval = evaluation.approval, approval.reviewedAt < evaluation.metadata.createdAt { result.add(.invalidReviewTime) }
        var children: [CriterionEvaluation] = []
        result.merge(checkReferences(evaluation.criterionEvaluationIDs, kind: .criterionEvaluation) { context.find($0) != nil })
        for id in evaluation.criterionEvaluationIDs {
            guard let child = context.find(id) else { continue }
            children.append(child)
            if child.caseEvaluationID != evaluation.id { result.add(.relationshipMismatch(ObjectReference(kind: .criterionEvaluation, id: id))) }
            result.merge(validate(child, snapshot: snapshot, cutoff: evaluation.cutoff, final: final, in: context))
        }
        let actual = children.map { $0.criterionRevisionID }
        if Set(actual) != Set(snapshot.criteria.map { $0.id }) || Set(actual).count != actual.count {
            result.add(.snapshotMismatch(ObjectReference(kind: .caseEvaluation, id: evaluation.id)))
        }
        for entry in snapshot.criteria {
            if let criterion = context.find(entry.id), let confirmation = criterion.confirmation,
               confirmation.reviewedAt > evaluation.metadata.createdAt { result.add(.invalidReviewTime) }
        }
        let links = children.flatMap { $0.evidenceLinkIDs }.compactMap { context.find($0) }.filter { link in
            snapshot.evidenceLinks.contains(where: { $0.id == link.id && $0.state == .verified })
        }
        result.merge(category(evaluation.category, confidence: evaluation.confidence, reasons: evaluation.notVerifiableReasons, links: links, final: final))
        // Consistency/materiality and attribution remain a human decision, not arithmetic aggregation.
        return result
    }
}
