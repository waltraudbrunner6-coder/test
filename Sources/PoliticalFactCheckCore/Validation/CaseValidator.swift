extension DomainValidator {
    public static func validate(_ politicalCase: Case, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        guard let promise = context.find(politicalCase.promiseID), let revision = context.find(politicalCase.currentPromiseRevisionID) else {
            if context.find(politicalCase.promiseID) == nil { result.add(.missingReference(ObjectReference(kind: .promise, id: politicalCase.promiseID))) }
            if context.find(politicalCase.currentPromiseRevisionID) == nil { result.add(.missingReference(ObjectReference(kind: .promiseRevision, id: politicalCase.currentPromiseRevisionID))) }
            return result
        }
        if promise.caseID != politicalCase.id || revision.promiseID != promise.id || promise.currentRevisionID != revision.id ||
            context.promises.filter({ $0.caseID == politicalCase.id }).count != 1 {
            result.add(.relationshipMismatch(ObjectReference(kind: .politicalCase, id: politicalCase.id)))
        }
        result.merge(validate(revision, in: context))
        result.merge(checkReferences(politicalCase.activeCriterionRevisionIDs, kind: .criterionRevision) { context.find($0) != nil })
        result.merge(checkReferences(politicalCase.currentActionRevisionIDs, kind: .actionRevision) { context.find($0) != nil })
        for id in politicalCase.activeCriterionRevisionIDs {
            if let criterion = context.find(id), context.find(criterion.criterionID)?.promiseID != promise.id {
                result.add(.relationshipMismatch(ObjectReference(kind: .criterionRevision, id: id)))
            }
        }
        for id in politicalCase.currentActionRevisionIDs {
            if let action = context.find(id), context.find(action.actionID)?.caseID != politicalCase.id {
                result.add(.relationshipMismatch(ObjectReference(kind: .actionRevision, id: id)))
            }
        }
        if [CaseWorkflowState.documented, .verified, .readyForEvaluation].contains(politicalCase.workflowState) && revision.quote.excerptIDs.isEmpty {
            result.add(.missingOriginalExcerpt)
        }
        switch politicalCase.workflowState {
        case .verified, .readyForEvaluation:
            if revision.quote.verification != .verified || revision.context.verification != .verified || revision.speaker.verification != .verified {
                result.add(.relationshipMismatch(ObjectReference(kind: .promiseRevision, id: revision.id)))
            }
        default: break
        }
        switch politicalCase.workflowState {
        case .readyForEvaluation:
            if politicalCase.activeCriterionRevisionIDs.isEmpty { result.add(.missingCriteria) }
            result.merge(checkReferences(politicalCase.activeCriterionRevisionIDs, kind: .criterionRevision) { context.find($0) != nil })
            for id in politicalCase.activeCriterionRevisionIDs {
                guard let criterion = context.find(id) else { continue }
                if criterion.state != .confirmed { result.add(.criterionNotConfirmed(id)) }
                if criterion.promiseRevisionID != revision.id { result.add(.relationshipMismatch(ObjectReference(kind: .criterionRevision, id: id))) }
                result.merge(validate(criterion, in: context))
            }
        default: break
        }
        if politicalCase.workflowState == .evaluated || politicalCase.workflowState == .approved {
            // Workflow records milestones. Current working heads may already have newer drafts.
            let available = context.caseEvaluations.filter { evaluation in
                evaluation.caseID == politicalCase.id && validate(evaluation, in: context).isValid
            }
            if available.isEmpty || (politicalCase.workflowState == .approved && !available.contains(where: { $0.hasHistoricalApproval })) {
                result.add(.relationshipMismatch(ObjectReference(kind: .politicalCase, id: politicalCase.id)))
            }
        }
        return result
    }

    public static func validate(_ script: ScriptDraft, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if context.find(script.caseEvaluationID) == nil { result.add(.missingReference(ObjectReference(kind: .caseEvaluation, id: script.caseEvaluationID))) }
        if script.status == .approved, context.find(script.caseEvaluationID)?.status != .approved {
            result.add(.relationshipMismatch(ObjectReference(kind: .caseEvaluation, id: script.caseEvaluationID)))
        }
        if script.status == .approved || script.status == .superseded { result.merge(review(script.approval, in: context)) }
        result.merge(checkReferences(script.statementIDs, kind: .statement) { context.find($0) != nil })
        let evaluation = context.find(script.caseEvaluationID)
        let snapshot = evaluation.flatMap { context.find($0.caseRevisionID) }
        if let evaluation, snapshot == nil {
            result.add(.missingReference(ObjectReference(kind: .caseRevision, id: evaluation.caseRevisionID)))
        }
        if let evaluation { result.merge(validate(evaluation, in: context)) }
        if let snapshot { result.merge(validate(snapshot, in: context)) }
        if script.version < 1 { result.add(.invalidRevisionNumber) }
        if script.statementIDs.isEmpty { result.add(.relationshipMismatch(ObjectReference(kind: .script, id: script.id))) }
        let used = evaluation.map { ScriptReferences.usedEvidence(in: $0, graph: context) } ?? []
        var positions = Set<Int>()
        for id in script.statementIDs {
            guard let statement = context.find(id) else { continue }
            if statement.scriptDraftID != script.id || statement.position < 0 || !positions.insert(statement.position).inserted {
                result.add(.relationshipMismatch(ObjectReference(kind: .statement, id: id)))
            }
            if let review = statement.review { result.merge(DomainValidator.review(review, in: context)) }
            if script.status == .approved || script.status == .superseded {
                result.merge(review(statement.review, in: context))
            }
            if statement.kind == .fact && statement.excerptIDs.isEmpty { result.add(.scriptFactWithoutExcerpt) }
            result.merge(excerpts(statement.excerptIDs, required: statement.kind == .fact || !statement.excerptIDs.isEmpty,
                                  in: context, snapshot: snapshot))
            for excerptID in statement.excerptIDs {
                if let excerpt = context.find(excerptID), let snapshot,
                   !snapshot.sourceVersions.contains(where: { $0.id == excerpt.sourceVersionID && $0.state == .verified }) {
                    result.add(.sourceVersionNotVerified(excerpt.sourceVersionID))
                }
            }
            result.merge(checkReferences(statement.evidenceLinkIDs, kind: .evidenceLink) { context.find($0) != nil })
            for linkID in statement.evidenceLinkIDs {
                guard let link = context.find(linkID) else { continue }
                if !used.contains(linkID) || snapshot?.evidenceLinks.contains(where: { $0.id == linkID && $0.state == .verified }) != true {
                    result.add(.snapshotMismatch(ObjectReference(kind: .evidenceLink, id: linkID)))
                }
                if !link.excerptIDs.allSatisfy({ statement.excerptIDs.contains($0) }) {
                    result.add(.relationshipMismatch(ObjectReference(kind: .evidenceLink, id: linkID)))
                }
            }
        }
        return result
    }

    public static func validate(_ task: ResearchTask, in context: DomainContext) -> ValidationResult {
        var result = ValidationResult()
        if context.find(task.caseID) == nil { result.add(.missingReference(ObjectReference(kind: .politicalCase, id: task.caseID))) }
        result.merge(checkReferences(task.criterionRevisionIDs, kind: .criterionRevision) { context.find($0) != nil })
        result.merge(checkReferences(task.sourceIDs, kind: .source) { context.find($0) != nil })
        result.merge(checkReferences(task.excerptIDs, kind: .excerpt) { context.find($0) != nil })
        return result
    }

    public static func validate(_ affiliation: ActorAffiliation, in context: DomainContext) -> ValidationResult {
        var result = role(affiliation.validity, expected: .validity)
        if context.find(affiliation.actorID) == nil { result.add(.missingReference(ObjectReference(kind: .actor, id: affiliation.actorID))) }
        if let id = affiliation.associatedActorID, context.find(id) == nil { result.add(.missingReference(ObjectReference(kind: .actor, id: id))) }
        if affiliation.verification == .verified {
            result.merge(review(affiliation.review, in: context))
            result.merge(excerpts(affiliation.excerptIDs, required: true, in: context))
        }
        return result
    }
}
