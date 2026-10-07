import PoliticalFactCheckCore

/// Complete-graph saves cannot bypass the domain's operational review requests.
func validateReviewUpdates(from old: DomainContext, to new: DomainContext) throws {
    var affected = Set<EntityID<CaseEvaluation>>()
    for link in new.evidenceLinks where link.status == .verified && old.find(link.id)?.status != .verified {
        let requests = try domainChange {
            try DomainChanges.reviewImpact(of: link, reason: link.rationale, in: new)
        }
        affected.formUnion(requests.map { $0.evaluationID })
    }
    for criterion in new.criteria {
        guard let previous = old.find(criterion.id), previous.currentRevisionID != criterion.currentRevisionID else { continue }
        for evaluation in old.caseEvaluations {
            if old.find(evaluation.caseRevisionID)?.criteria.contains(where: { $0.id == previous.currentRevisionID }) == true {
                affected.insert(evaluation.id)
            }
        }
    }
    for id in affected {
        guard let previous = old.find(id), previous.status != .superseded, let next = new.find(id) else { continue }
        let request = ReviewRequest(evaluationID: id, reason: previous.rationale)
        let expected = try domainChange { try DomainChanges.apply(request, to: previous, in: old) }
        if expected.status != previous.status && next.status != expected.status {
            throw PersistenceError.reviewUpdateRequired(id.rawValue)
        }
    }
}
