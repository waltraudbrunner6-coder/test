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

struct CaseManifest: Codable, Equatable {
    var reviewers: [StoredID]
    var actors: [StoredID]
    var affiliations: [StoredID]
    var promises: [StoredID]
    var promiseRevisions: [StoredID]
    var criteria: [StoredID]
    var criterionRevisions: [StoredID]
    var sources: [StoredID]
    var sourceVersions: [StoredID]
    var excerpts: [StoredID]
    var actions: [StoredID]
    var actionRevisions: [StoredID]
    var participations: [StoredID]
    var evidenceLinks: [StoredID]
    var caseRevisions: [StoredID]
    var criterionEvaluations: [StoredID]
    var caseEvaluations: [StoredID]
    var methodologies: [StoredID]
    var researchTasks: [StoredID]
    var auditEntries: [StoredID]
    var scripts: [StoredID]
    var statements: [StoredID]
    init(_ graph: CaseGraphDTO) {
        reviewers = graph.reviewers.map { $0.id }
        actors = graph.actors.map { $0.id }
        affiliations = graph.affiliations.map { $0.id }
        promises = graph.promises.map { $0.id }
        promiseRevisions = graph.promiseRevisions.map { $0.id }
        criteria = graph.criteria.map { $0.id }
        criterionRevisions = graph.criterionRevisions.map { $0.id }
        sources = graph.sources.map { $0.id }
        sourceVersions = graph.sourceVersions.map { $0.id }
        excerpts = graph.excerpts.map { $0.id }
        actions = graph.actions.map { $0.id }
        actionRevisions = graph.actionRevisions.map { $0.id }
        participations = graph.participations.map { $0.id }
        evidenceLinks = graph.evidenceLinks.map { $0.id }
        caseRevisions = graph.caseRevisions.map { $0.id }
        criterionEvaluations = graph.criterionEvaluations.map { $0.id }
        caseEvaluations = graph.caseEvaluations.map { $0.id }
        methodologies = graph.methodologies.map { $0.id }
        researchTasks = graph.researchTasks.map { $0.id }
        auditEntries = graph.auditEntries.map { $0.id }
        scripts = graph.scripts.map { $0.id }
        statements = graph.statements.map { $0.id }
    }
    func retaining(_ older: CaseManifest) throws {
        for id in older.reviewers where !reviewers.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.actors where !actors.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.affiliations where !affiliations.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.promises where !promises.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.promiseRevisions where !promiseRevisions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.criteria where !criteria.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.criterionRevisions where !criterionRevisions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.sources where !sources.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.sourceVersions where !sourceVersions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.excerpts where !excerpts.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.actions where !actions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.actionRevisions where !actionRevisions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.participations where !participations.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.evidenceLinks where !evidenceLinks.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.caseRevisions where !caseRevisions.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.criterionEvaluations where !criterionEvaluations.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.caseEvaluations where !caseEvaluations.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.methodologies where !methodologies.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.researchTasks where !researchTasks.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.auditEntries where !auditEntries.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.scripts where !scripts.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
        for id in older.statements where !statements.contains(id) { throw PersistenceError.historyRemovalDenied(kind: id.kind, id: id.value) }
    }
}
