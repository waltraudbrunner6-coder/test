import Foundation

extension Case {
    func replacingLifecycle(workflowState: CaseWorkflowState, modifiedAt: Date) -> Case {
        Case(
            id: self.id,
            title: self.title,
            promiseID: self.promiseID,
            currentPromiseRevisionID: self.currentPromiseRevisionID,
            activeCriterionRevisionIDs: self.activeCriterionRevisionIDs,
            currentActionRevisionIDs: self.currentActionRevisionIDs,
            workflowState: workflowState,
            createdAt: self.createdAt,
            modifiedAt: modifiedAt
        )
    }
}

extension CriterionRevision {
    func replacingLifecycle(state: CriterionRevisionState, confirmation: HumanReview?) -> CriterionRevision {
        CriterionRevision(
            id: self.id,
            criterionID: self.criterionID,
            promiseRevisionID: self.promiseRevisionID,
            goal: self.goal,
            targetGroup: self.targetGroup,
            baseline: self.baseline,
            deadline: self.deadline,
            conditions: self.conditions,
            isCore: self.isCore,
            materialityRule: self.materialityRule,
            weight: self.weight,
            weightReason: self.weightReason,
            metadata: self.metadata,
            state: state,
            confirmation: confirmation
        )
    }
}

extension SourceExcerpt {
    func replacingLifecycle(state: ExcerptVerificationState, review: HumanReview?) -> SourceExcerpt {
        SourceExcerpt(
            id: self.id,
            sourceVersionID: self.sourceVersionID,
            locator: self.locator,
            text: self.text,
            context: self.context,
            language: self.language,
            translationOfExcerptID: self.translationOfExcerptID,
            provenance: self.provenance,
            state: state,
            review: review,
            createdAt: self.createdAt
        )
    }
}

extension CaseEvaluation {
    func replacingLifecycle(status: EvaluationStatus, approval: HumanReview?, reviewReason: NonEmptyText?) -> CaseEvaluation {
        CaseEvaluation(
            id: self.id,
            caseID: self.caseID,
            caseRevisionID: self.caseRevisionID,
            cutoff: self.cutoff,
            methodologyVersionID: self.methodologyVersionID,
            criterionEvaluationIDs: self.criterionEvaluationIDs,
            category: self.category,
            rationale: self.rationale,
            confidence: self.confidence,
            facts: self.facts,
            interpretations: self.interpretations,
            uncertainties: self.uncertainties,
            notVerifiableReasons: self.notVerifiableReasons,
            metadata: self.metadata,
            status: status,
            approval: approval,
            reviewReason: reviewReason,
            replacesEvaluationID: self.replacesEvaluationID
        )
    }
}

extension EvidenceLink {
    func replacingLifecycle(status: EvidenceLinkStatus, review: HumanReview?) -> EvidenceLink {
        EvidenceLink(
            id: self.id,
            criterionRevisionID: self.criterionRevisionID,
            excerptIDs: self.excerptIDs,
            actionRevisionID: self.actionRevisionID,
            relationship: self.relationship,
            directness: self.directness,
            rationale: self.rationale,
            temporalReference: self.temporalReference,
            status: status,
            review: review,
            metadata: self.metadata
        )
    }
}

extension ScriptDraft {
    func replacingLifecycle(status: ScriptStatus, approval: HumanReview?) -> ScriptDraft {
        ScriptDraft(id: id, caseEvaluationID: caseEvaluationID, version: version,
            targetDurationSeconds: targetDurationSeconds, statementIDs: statementIDs, status: status,
            author: author, createdAt: createdAt, approval: approval)
    }
}
