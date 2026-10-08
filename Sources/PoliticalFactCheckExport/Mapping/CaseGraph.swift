// Frozen portable v1 DTO mapping. Independent of SwiftData/store payloads.
import Foundation
import PoliticalFactCheckCore

struct CaseGraphDTO: Codable, Equatable {
    var reviewers: [ReviewerIdentityDTO]
    var cases: [CaseDTO]
    var actors: [ActorDTO]
    var affiliations: [ActorAffiliationDTO]
    var promises: [PromiseDTO]
    var promiseRevisions: [PromiseRevisionDTO]
    var criteria: [EvaluationCriterionDTO]
    var criterionRevisions: [CriterionRevisionDTO]
    var sources: [SourceDTO]
    var sourceVersions: [SourceVersionDTO]
    var excerpts: [SourceExcerptDTO]
    var actions: [ActionOrDevelopmentDTO]
    var actionRevisions: [ActionRevisionDTO]
    var participations: [ActionParticipationDTO]
    var evidenceLinks: [EvidenceLinkDTO]
    var caseRevisions: [CaseRevisionDTO]
    var criterionEvaluations: [CriterionEvaluationDTO]
    var caseEvaluations: [CaseEvaluationDTO]
    var methodologies: [MethodologyVersionDTO]
    var researchTasks: [ResearchTaskDTO]
    var auditEntries: [AuditEntryDTO]
    var scripts: [ScriptDraftDTO]
    var statements: [ScriptStatementDTO]
    init(_ graph: DomainContext) {
        reviewers = graph.reviewers.map(ReviewerIdentityDTO.init)
        cases = graph.cases.map(CaseDTO.init)
        actors = graph.actors.map(ActorDTO.init)
        affiliations = graph.affiliations.map(ActorAffiliationDTO.init)
        promises = graph.promises.map(PromiseDTO.init)
        promiseRevisions = graph.promiseRevisions.map(PromiseRevisionDTO.init)
        criteria = graph.criteria.map(EvaluationCriterionDTO.init)
        criterionRevisions = graph.criterionRevisions.map(CriterionRevisionDTO.init)
        sources = graph.sources.map(SourceDTO.init)
        sourceVersions = graph.sourceVersions.map(SourceVersionDTO.init)
        excerpts = graph.excerpts.map(SourceExcerptDTO.init)
        actions = graph.actions.map(ActionOrDevelopmentDTO.init)
        actionRevisions = graph.actionRevisions.map(ActionRevisionDTO.init)
        participations = graph.participations.map(ActionParticipationDTO.init)
        evidenceLinks = graph.evidenceLinks.map(EvidenceLinkDTO.init)
        caseRevisions = graph.caseRevisions.map(CaseRevisionDTO.init)
        criterionEvaluations = graph.criterionEvaluations.map(CriterionEvaluationDTO.init)
        caseEvaluations = graph.caseEvaluations.map(CaseEvaluationDTO.init)
        methodologies = graph.methodologies.map(MethodologyVersionDTO.init)
        researchTasks = graph.researchTasks.map(ResearchTaskDTO.init)
        auditEntries = graph.auditEntries.map(AuditEntryDTO.init)
        scripts = graph.scripts.map(ScriptDraftDTO.init)
        statements = graph.statements.map(ScriptStatementDTO.init)
    }
    func domain() throws -> DomainContext {
        try DomainContext(
            reviewers: reviewers.map { try $0.domain() },
            cases: cases.map { try $0.domain() },
            actors: actors.map { try $0.domain() },
            affiliations: affiliations.map { try $0.domain() },
            promises: promises.map { try $0.domain() },
            promiseRevisions: promiseRevisions.map { try $0.domain() },
            criteria: criteria.map { try $0.domain() },
            criterionRevisions: criterionRevisions.map { try $0.domain() },
            sources: sources.map { try $0.domain() },
            sourceVersions: sourceVersions.map { try $0.domain() },
            excerpts: excerpts.map { try $0.domain() },
            actions: actions.map { try $0.domain() },
            actionRevisions: actionRevisions.map { try $0.domain() },
            participations: participations.map { try $0.domain() },
            evidenceLinks: evidenceLinks.map { try $0.domain() },
            caseRevisions: caseRevisions.map { try $0.domain() },
            criterionEvaluations: criterionEvaluations.map { try $0.domain() },
            caseEvaluations: caseEvaluations.map { try $0.domain() },
            methodologies: methodologies.map { try $0.domain() },
            researchTasks: researchTasks.map { try $0.domain() },
            auditEntries: auditEntries.map { try $0.domain() },
            scripts: scripts.map { try $0.domain() },
            statements: statements.map { try $0.domain() }
        )
    }
}
