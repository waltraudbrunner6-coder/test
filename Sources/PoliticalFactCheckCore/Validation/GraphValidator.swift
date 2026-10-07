extension DomainValidator {
    /// Whole graph structural checks. Historical snapshots are checked independently of current heads.
    public static func validate(_ context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        result.merge(checkReferences(context.reviewers.map { $0.id }, kind: .reviewer) { context.find($0) != nil })
        result.merge(checkReferences(context.cases.map { $0.id }, kind: .politicalCase) { context.find($0) != nil })
        result.merge(checkReferences(context.actors.map { $0.id }, kind: .actor) { context.find($0) != nil })
        result.merge(checkReferences(context.affiliations.map { $0.id }, kind: .affiliation) { context.find($0) != nil })
        result.merge(checkReferences(context.promises.map { $0.id }, kind: .promise) { context.find($0) != nil })
        result.merge(checkReferences(context.criteria.map { $0.id }, kind: .criterion) { context.find($0) != nil })
        result.merge(checkReferences(context.sources.map { $0.id }, kind: .source) { context.find($0) != nil })
        result.merge(checkReferences(context.actions.map { $0.id }, kind: .action) { context.find($0) != nil })
        result.merge(checkReferences(context.actionRevisions.map { $0.id }, kind: .actionRevision) { context.find($0) != nil })
        result.merge(checkReferences(context.participations.map { $0.id }, kind: .participation) { context.find($0) != nil })
        result.merge(checkReferences(context.methodologies.map { $0.id }, kind: .methodology) { context.find($0) != nil })
        result.merge(checkReferences(context.researchTasks.map { $0.id }, kind: .researchTask) { context.find($0) != nil })
        result.merge(checkReferences(context.auditEntries.map { $0.id }, kind: .auditEntry) { context.find($0) != nil })
        result.merge(checkReferences(context.scripts.map { $0.id }, kind: .script) { context.find($0) != nil })
        result.merge(checkReferences(context.statements.map { $0.id }, kind: .statement) { context.find($0) != nil })
        result.merge(checkReferences(context.promiseRevisions.map { $0.id }, kind: .promiseRevision) { context.find($0) != nil })
        result.merge(checkReferences(context.criterionRevisions.map { $0.id }, kind: .criterionRevision) { context.find($0) != nil })
        result.merge(checkReferences(context.sourceVersions.map { $0.id }, kind: .sourceVersion) { context.find($0) != nil })
        result.merge(checkReferences(context.excerpts.map { $0.id }, kind: .excerpt) { context.find($0) != nil })
        result.merge(checkReferences(context.evidenceLinks.map { $0.id }, kind: .evidenceLink) { context.find($0) != nil })
        result.merge(checkReferences(context.caseRevisions.map { $0.id }, kind: .caseRevision) { context.find($0) != nil })
        result.merge(checkReferences(context.caseEvaluations.map { $0.id }, kind: .caseEvaluation) { context.find($0) != nil })
        result.merge(checkReferences(context.criterionEvaluations.map { $0.id }, kind: .criterionEvaluation) { context.find($0) != nil })
        for politicalCase in context.cases { result.merge(validate(politicalCase, in: context)) }
        for source in context.sources {
            result.merge(validate(source, in: context))
            if !context.sourceVersions.contains(where: { $0.sourceID == source.id }) {
                result.add(.relationshipMismatch(ObjectReference(kind: .source, id: source.id)))
            }
        }
        for version in context.sourceVersions { result.merge(validate(version, in: context)) }
        for excerpt in context.excerpts { result.merge(validate(excerpt, in: context)) }
        for affiliation in context.affiliations { result.merge(validate(affiliation, in: context)) }
        for actor in context.actors {
            for id in actor.affiliationIDs {
                if let affiliation = context.find(id) {
                    if affiliation.actorID != actor.id { result.add(.relationshipMismatch(ObjectReference(kind: .affiliation, id: id))) }
                } else { result.add(.missingReference(ObjectReference(kind: .affiliation, id: id))) }
            }
        }
        for promise in context.promises {
            if context.find(promise.caseID) == nil { result.add(.missingReference(ObjectReference(kind: .politicalCase, id: promise.caseID))) }
            if context.find(promise.currentRevisionID)?.promiseID != promise.id { result.add(.relationshipMismatch(ObjectReference(kind: .promise, id: promise.id))) }
        }
        for revision in context.promiseRevisions where context.find(revision.promiseID)?.currentRevisionID == revision.id {
            result.merge(validate(revision, in: context))
        }
        for criterion in context.criteria {
            if context.find(criterion.promiseID) == nil { result.add(.missingReference(ObjectReference(kind: .promise, id: criterion.promiseID))) }
            if context.find(criterion.currentRevisionID)?.criterionID != criterion.id { result.add(.relationshipMismatch(ObjectReference(kind: .criterion, id: criterion.id))) }
        }
        for revision in context.criterionRevisions { result.merge(validate(revision, in: context)) }
        for action in context.actions {
            if context.find(action.caseID) == nil { result.add(.missingReference(ObjectReference(kind: .politicalCase, id: action.caseID))) }
            if context.find(action.currentRevisionID)?.actionID != action.id { result.add(.relationshipMismatch(ObjectReference(kind: .action, id: action.id))) }
        }
        for action in context.actionRevisions { result.merge(validate(action, in: context)) }
        for participation in context.participations { result.merge(validate(participation, in: context)) }
        for link in context.evidenceLinks { result.merge(validate(link, in: context)) }
        for snapshot in context.caseRevisions { result.merge(validate(snapshot, in: context)) }
        for evaluation in context.caseEvaluations { result.merge(validate(evaluation, in: context)) }
        for task in context.researchTasks { result.merge(validate(task, in: context)) }
        for script in context.scripts { result.merge(validate(script, in: context)) }
        return result
    }
}
