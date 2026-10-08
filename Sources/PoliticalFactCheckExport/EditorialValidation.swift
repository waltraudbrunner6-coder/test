import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

public enum EditorialValidation {
    public static func validateGraph(_ graph: DomainContext) throws {
        guard graph.cases.count == 1, graph.promises.count == 1, let root = graph.cases.first,
              graph.promises[0].id == root.promiseID,
              graph.promises.allSatisfy({ $0.caseID == root.id }),
              graph.actions.allSatisfy({ $0.caseID == root.id }),
              graph.caseRevisions.allSatisfy({ $0.caseID == root.id }),
              graph.caseEvaluations.allSatisfy({ $0.caseID == root.id }),
              graph.researchTasks.allSatisfy({ $0.caseID == root.id }),
              graph.auditEntries.allSatisfy({ $0.caseID == root.id }),
              graph.criteria.allSatisfy({ $0.promiseID == root.promiseID }) else { throw EditorialPackageError.invalidReference }
        guard DomainValidator.validate(graph).isValid else { throw EditorialPackageError.invalidDomain }
        // GraphValidator validates current promises; portable history must also resolve old revisions.
        for revision in graph.promiseRevisions {
            let snapshots = graph.caseRevisions.filter { $0.promiseRevisionID == revision.id }
            // Core snapshots preserve formerly verified sources even after operational superseding.
            // Accept only those two status diagnostics when an already validated snapshot proves verification.
            let errors = DomainValidator.validate(revision, in: graph).errors.filter { error in
                switch error {
                case .excerptNotVerified(let id):
                    return !snapshots.contains { $0.excerpts.contains { $0.id == id && $0.state == .verified } }
                case .sourceVersionNotVerified(let id):
                    return !snapshots.contains { $0.sourceVersions.contains { $0.id == id && $0.state == .verified } }
                default: return true
                }
            }
            guard errors.isEmpty else { throw EditorialPackageError.invalidDomain }
        }
        for child in graph.criterionEvaluations {
            guard graph.find(child.caseEvaluationID)?.criterionEvaluationIDs.contains(child.id) == true else { throw EditorialPackageError.invalidReference }
        }
        for statement in graph.statements {
            guard graph.find(statement.scriptDraftID)?.statementIDs.contains(statement.id) == true else { throw EditorialPackageError.invalidReference }
        }
        for audit in graph.auditEntries {
            for ref in [audit.target, audit.before, audit.after].compactMap({ $0 }) {
                guard contains(ref, in: graph) else { throw EditorialPackageError.invalidReference }
            }
            if case .human(let id) = audit.author, graph.find(id) == nil { throw EditorialPackageError.invalidReference }
            if let id = audit.humanRequesterID, graph.find(id) == nil { throw EditorialPackageError.invalidReference }
        }
        for version in graph.sourceVersions {
            guard version.localCopyReference == nil else { throw EditorialPackageError.nonPortableAttachment }
            for url in [version.requestedURL, version.finalURL, version.archiveURL].compactMap({ $0 }) where url.isFileURL || (url.scheme == nil && url.path.hasPrefix("/")) {
                throw EditorialPackageError.nonPortableAttachment
            }
        }
        guard !graph.sources.contains(where: { $0.canonicalURL.map { $0.isFileURL || ($0.scheme == nil && $0.path.hasPrefix("/")) } == true }) else { throw EditorialPackageError.nonPortableAttachment }
    }
    public static func publicationInput(graph: DomainContext, evaluationID: EntityID<CaseEvaluation>, scriptID: EntityID<ScriptDraft>) throws -> ScriptGenerationInput {
        guard let evaluation = graph.find(evaluationID) else { throw EditorialPackageError.evaluationNotApproved }
        if evaluation.status == .reviewRequired { throw EditorialPackageError.evaluationNeedsReview }
        guard evaluation.status == .approved, evaluation.approval != nil else { throw EditorialPackageError.evaluationNotApproved }
        guard let script = graph.find(scriptID), script.status == .approved, script.approval != nil else { throw EditorialPackageError.scriptNotApproved }
        guard script.caseEvaluationID == evaluationID else { throw EditorialPackageError.scriptEvaluationMismatch }
        guard DomainValidator.validate(script, in: graph).isValid else { throw EditorialPackageError.invalidScript }
        try validateGraph(graph)
        if try CaseReviews.state(of: graph.cases[0], in: graph) == .reviewRequired { throw EditorialPackageError.evaluationNeedsReview }
        do { return try ScriptInputBuilder.build(evaluationID: evaluationID, targetDurationSeconds: script.targetDurationSeconds, in: graph) }
        catch { throw EditorialPackageError.invalidDomain }
    }
    private static func contains(_ reference: ObjectReference, in graph: DomainContext) -> Bool {
        switch reference.kind {
        case .reviewer: return graph.find(EntityID<ReviewerIdentity>(reference.id)) != nil
        case .politicalCase: return graph.find(EntityID<Case>(reference.id)) != nil
        case .actor: return graph.find(EntityID<Actor>(reference.id)) != nil
        case .affiliation: return graph.find(EntityID<ActorAffiliation>(reference.id)) != nil
        case .promise: return graph.find(EntityID<Promise>(reference.id)) != nil
        case .promiseRevision: return graph.find(EntityID<PromiseRevision>(reference.id)) != nil
        case .criterion: return graph.find(EntityID<EvaluationCriterion>(reference.id)) != nil
        case .criterionRevision: return graph.find(EntityID<CriterionRevision>(reference.id)) != nil
        case .source: return graph.find(EntityID<Source>(reference.id)) != nil
        case .sourceVersion: return graph.find(EntityID<SourceVersion>(reference.id)) != nil
        case .excerpt: return graph.find(EntityID<SourceExcerpt>(reference.id)) != nil
        case .action: return graph.find(EntityID<ActionOrDevelopment>(reference.id)) != nil
        case .actionRevision: return graph.find(EntityID<ActionRevision>(reference.id)) != nil
        case .participation: return graph.find(EntityID<ActionParticipation>(reference.id)) != nil
        case .evidenceLink: return graph.find(EntityID<EvidenceLink>(reference.id)) != nil
        case .caseRevision: return graph.find(EntityID<CaseRevision>(reference.id)) != nil
        case .criterionEvaluation: return graph.find(EntityID<CriterionEvaluation>(reference.id)) != nil
        case .caseEvaluation: return graph.find(EntityID<CaseEvaluation>(reference.id)) != nil
        case .methodology: return graph.find(EntityID<MethodologyVersion>(reference.id)) != nil
        case .researchTask: return graph.find(EntityID<ResearchTask>(reference.id)) != nil
        case .auditEntry: return graph.find(EntityID<AuditEntry>(reference.id)) != nil
        case .script: return graph.find(EntityID<ScriptDraft>(reference.id)) != nil
        case .statement: return graph.find(EntityID<ScriptStatement>(reference.id)) != nil
        }
    }
}
