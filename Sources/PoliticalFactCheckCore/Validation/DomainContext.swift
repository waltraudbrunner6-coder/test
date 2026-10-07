/// Explicit in-memory validation input. No storage, I/O, or service abstraction.
public struct DomainContext {
    public let reviewers: [ReviewerIdentity]
    public let cases: [Case]
    public let actors: [Actor]
    public let affiliations: [ActorAffiliation]
    public let promises: [Promise]
    public let promiseRevisions: [PromiseRevision]
    public let criteria: [EvaluationCriterion]
    public let criterionRevisions: [CriterionRevision]
    public let sources: [Source]
    public let sourceVersions: [SourceVersion]
    public let excerpts: [SourceExcerpt]
    public let actions: [ActionOrDevelopment]
    public let actionRevisions: [ActionRevision]
    public let participations: [ActionParticipation]
    public let evidenceLinks: [EvidenceLink]
    public let caseRevisions: [CaseRevision]
    public let criterionEvaluations: [CriterionEvaluation]
    public let caseEvaluations: [CaseEvaluation]
    public let methodologies: [MethodologyVersion]
    public let researchTasks: [ResearchTask]
    public let auditEntries: [AuditEntry]
    public let scripts: [ScriptDraft]
    public let statements: [ScriptStatement]
    public init(
        reviewers: [ReviewerIdentity] = [],
        cases: [Case] = [],
        actors: [Actor] = [],
        affiliations: [ActorAffiliation] = [],
        promises: [Promise] = [],
        promiseRevisions: [PromiseRevision] = [],
        criteria: [EvaluationCriterion] = [],
        criterionRevisions: [CriterionRevision] = [],
        sources: [Source] = [],
        sourceVersions: [SourceVersion] = [],
        excerpts: [SourceExcerpt] = [],
        actions: [ActionOrDevelopment] = [],
        actionRevisions: [ActionRevision] = [],
        participations: [ActionParticipation] = [],
        evidenceLinks: [EvidenceLink] = [],
        caseRevisions: [CaseRevision] = [],
        criterionEvaluations: [CriterionEvaluation] = [],
        caseEvaluations: [CaseEvaluation] = [],
        methodologies: [MethodologyVersion] = [],
        researchTasks: [ResearchTask] = [],
        auditEntries: [AuditEntry] = [],
        scripts: [ScriptDraft] = [],
        statements: [ScriptStatement] = []
    ) {
        self.reviewers = reviewers
        self.cases = cases
        self.actors = actors
        self.affiliations = affiliations
        self.promises = promises
        self.promiseRevisions = promiseRevisions
        self.criteria = criteria
        self.criterionRevisions = criterionRevisions
        self.sources = sources
        self.sourceVersions = sourceVersions
        self.excerpts = excerpts
        self.actions = actions
        self.actionRevisions = actionRevisions
        self.participations = participations
        self.evidenceLinks = evidenceLinks
        self.caseRevisions = caseRevisions
        self.criterionEvaluations = criterionEvaluations
        self.caseEvaluations = caseEvaluations
        self.methodologies = methodologies
        self.researchTasks = researchTasks
        self.auditEntries = auditEntries
        self.scripts = scripts
        self.statements = statements
    }
    public func find(_ id: EntityID<ReviewerIdentity>) -> ReviewerIdentity? {
        reviewers.first { $0.id == id }
    }
    public func find(_ id: EntityID<Case>) -> Case? {
        cases.first { $0.id == id }
    }
    public func find(_ id: EntityID<Actor>) -> Actor? {
        actors.first { $0.id == id }
    }
    public func find(_ id: EntityID<ActorAffiliation>) -> ActorAffiliation? {
        affiliations.first { $0.id == id }
    }
    public func find(_ id: EntityID<Promise>) -> Promise? {
        promises.first { $0.id == id }
    }
    public func find(_ id: EntityID<PromiseRevision>) -> PromiseRevision? {
        promiseRevisions.first { $0.id == id }
    }
    public func find(_ id: EntityID<EvaluationCriterion>) -> EvaluationCriterion? {
        criteria.first { $0.id == id }
    }
    public func find(_ id: EntityID<CriterionRevision>) -> CriterionRevision? {
        criterionRevisions.first { $0.id == id }
    }
    public func find(_ id: EntityID<Source>) -> Source? {
        sources.first { $0.id == id }
    }
    public func find(_ id: EntityID<SourceVersion>) -> SourceVersion? {
        sourceVersions.first { $0.id == id }
    }
    public func find(_ id: EntityID<SourceExcerpt>) -> SourceExcerpt? {
        excerpts.first { $0.id == id }
    }
    public func find(_ id: EntityID<ActionOrDevelopment>) -> ActionOrDevelopment? {
        actions.first { $0.id == id }
    }
    public func find(_ id: EntityID<ActionRevision>) -> ActionRevision? {
        actionRevisions.first { $0.id == id }
    }
    public func find(_ id: EntityID<ActionParticipation>) -> ActionParticipation? {
        participations.first { $0.id == id }
    }
    public func find(_ id: EntityID<EvidenceLink>) -> EvidenceLink? {
        evidenceLinks.first { $0.id == id }
    }
    public func find(_ id: EntityID<CaseRevision>) -> CaseRevision? {
        caseRevisions.first { $0.id == id }
    }
    public func find(_ id: EntityID<CriterionEvaluation>) -> CriterionEvaluation? {
        criterionEvaluations.first { $0.id == id }
    }
    public func find(_ id: EntityID<CaseEvaluation>) -> CaseEvaluation? {
        caseEvaluations.first { $0.id == id }
    }
    public func find(_ id: EntityID<MethodologyVersion>) -> MethodologyVersion? {
        methodologies.first { $0.id == id }
    }
    public func find(_ id: EntityID<ResearchTask>) -> ResearchTask? {
        researchTasks.first { $0.id == id }
    }
    public func find(_ id: EntityID<AuditEntry>) -> AuditEntry? {
        auditEntries.first { $0.id == id }
    }
    public func find(_ id: EntityID<ScriptDraft>) -> ScriptDraft? {
        scripts.first { $0.id == id }
    }
    public func find(_ id: EntityID<ScriptStatement>) -> ScriptStatement? {
        statements.first { $0.id == id }
    }
}
