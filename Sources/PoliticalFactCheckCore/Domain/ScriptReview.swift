import Foundation

/// Available material is limited to this immutable manifest and the evidence actually used in its assessment.
enum ScriptReferences {
    static func usedEvidence(in evaluation: CaseEvaluation, graph: DomainContext) -> [EntityID<EvidenceLink>] {
        evaluation.criterionEvaluationIDs.compactMap { graph.find($0) }.flatMap { $0.evidenceLinkIDs }
    }
}

extension DomainContext {
    public func withScripts(_ scripts: [ScriptDraft], statements: [ScriptStatement]) -> DomainContext {
        DomainContext(reviewers: reviewers, cases: cases, actors: actors, affiliations: affiliations,
            promises: promises, promiseRevisions: promiseRevisions, criteria: criteria, criterionRevisions: criterionRevisions,
            sources: sources, sourceVersions: sourceVersions, excerpts: excerpts, actions: actions,
            actionRevisions: actionRevisions, participations: participations, evidenceLinks: evidenceLinks,
            caseRevisions: caseRevisions, criterionEvaluations: criterionEvaluations, caseEvaluations: caseEvaluations,
            methodologies: methodologies, researchTasks: researchTasks, auditEntries: auditEntries,
            scripts: scripts, statements: statements)
    }
}

extension ScriptStatement {
    func withReview(_ review: HumanReview?) -> ScriptStatement {
        ScriptStatement(id: id, scriptDraftID: scriptDraftID, position: position, text: text, kind: kind,
            excerptIDs: excerptIDs, evidenceLinkIDs: evidenceLinkIDs, uncertainty: uncertainty, review: review)
    }
}

extension DomainChanges {
    public static func reviewScriptStatement(_ statement: ScriptStatement, review: HumanReview,
                                            in graph: DomainContext) throws -> ScriptStatement {
        guard graph.find(statement.id) == statement,
              let script = graph.find(statement.scriptDraftID), script.statementIDs.contains(statement.id),
              script.status == .draft || script.status == .needsReview,
              graph.find(script.caseEvaluationID)?.status == .approved, statement.review == nil else {
            throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .statement, id: statement.id))
        }
        try DomainValidator.review(review, in: graph).requireValid()
        guard review.reviewedAt >= script.createdAt else { throw DomainValidationError.invalidReviewTime }
        let next = statement.withReview(review)
        try DomainValidator.validate(script, in: graph.withScripts(graph.scripts,
            statements: graph.statements.map { $0.id == next.id ? next : $0 })).requireValid()
        return next
    }
}

extension RevisionRules {
    public static func validateReplacement(_ old: ScriptStatement, with new: ScriptStatement) throws {
        guard old.id == new.id, new.withReview(old.review) == old,
              old.review == new.review || (old.review == nil && new.review != nil) else {
            throw DomainValidationError.immutableContentChanged(ObjectReference(kind: .statement, id: old.id))
        }
    }
}
