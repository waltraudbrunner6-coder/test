/// Derived only; never stored alongside the monotone workflow milestone.
public enum CaseReviewState: Equatable {
    case notYetApproved
    case upToDate
    case reviewRequired
}

extension CaseEvaluation {
    /// Reference validity and authenticity of the human act are separate validation concerns.
    public var hasHistoricalApproval: Bool {
        approval != nil && (status == .approved || status == .reviewRequired || status == .superseded)
    }
}

public enum CaseReviews {
    /// No evaluation is selected by timestamp alone; an approved replacement must explicitly
    /// cover an outstanding review. Invalid input throws rather than suggesting upToDate.
    public static func state(of politicalCase: Case, in context: DomainContext) throws -> CaseReviewState {
        try DomainValidator.validate(politicalCase, in: context).requireValid()
        let evaluations = context.caseEvaluations.filter { $0.caseID == politicalCase.id }
        for evaluation in evaluations { try DomainValidator.validate(evaluation, in: context).requireValid() }
        guard evaluations.contains(where: { $0.hasHistoricalApproval }) else { return .notYetApproved }

        let approved = evaluations.filter { $0.status == .approved }
        for pending in evaluations where pending.status == .reviewRequired || pending.status == .superseded {
            if !approved.contains(where: { replaces($0, evaluationID: pending.id, in: context) }) {
                return .reviewRequired
            }
        }
        // The approved manifest must cover today's working revisions and available verified links.
        let relevantLinks = context.evidenceLinks.filter {
            $0.status == .verified && politicalCase.activeCriterionRevisionIDs.contains($0.criterionRevisionID)
        }
        let currentApproval = approved.contains { evaluation in
            guard let snapshot = context.find(evaluation.caseRevisionID) else { return false }
            return snapshot.promiseRevisionID == politicalCase.currentPromiseRevisionID &&
                Set(snapshot.criteria.map { $0.id }) == Set(politicalCase.activeCriterionRevisionIDs) &&
                Set(snapshot.actionRevisionIDs) == Set(politicalCase.currentActionRevisionIDs) &&
                relevantLinks.allSatisfy { link in
                    snapshot.evidenceLinks.contains(where: { $0.id == link.id && $0.state == .verified })
                }
        }
        return currentApproval ? .upToDate : .reviewRequired
    }

    private static func replaces(_ evaluation: CaseEvaluation, evaluationID: EntityID<CaseEvaluation>,
                                 in context: DomainContext) -> Bool {
        var next = evaluation.replacesEvaluationID
        var visited = Set<EntityID<CaseEvaluation>>()
        while let id = next, visited.insert(id).inserted {
            if id == evaluationID { return true }
            next = context.find(id)?.replacesEvaluationID
        }
        return false
    }
}
