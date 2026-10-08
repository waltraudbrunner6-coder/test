import PoliticalFactCheckCore

func checkReplacement(_ old: Case, _ new: Case) throws {
    guard old.promiseID == new.promiseID, old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "Case", id: old.id.rawValue) }
    if old.workflowState != new.workflowState { try TransitionRules.validate(old.workflowState, to: new.workflowState) }
}

func checkReplacement(_ old: Promise, _ new: Promise) throws {
    guard old.caseID == new.caseID, old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "Promise", id: old.id.rawValue) }
}

func checkReplacement(_ old: PromiseRevision, _ new: PromiseRevision) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: EvaluationCriterion, _ new: EvaluationCriterion) throws {
    guard old.promiseID == new.promiseID, old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "EvaluationCriterion", id: old.id.rawValue) }
}

func checkReplacement(_ old: CriterionRevision, _ new: CriterionRevision) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: ActionOrDevelopment, _ new: ActionOrDevelopment) throws {
    guard old.caseID == new.caseID, old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "ActionOrDevelopment", id: old.id.rawValue) }
}

func checkReplacement(_ old: ActionRevision, _ new: ActionRevision) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: ActionParticipation, _ new: ActionParticipation) throws {
    if old.verification == .verified || old.verification == .superseded {
        var normalized = ActionParticipationDTO(new); normalized.verification = write(old.verification)
        guard normalized == ActionParticipationDTO(old) else { throw PersistenceError.immutableRecord(kind: "ActionParticipation", id: old.id.rawValue) }
        if old.verification != new.verification { try TransitionRules.validate(old.verification, to: new.verification) }
    }
}

func checkReplacement(_ old: EvidenceLink, _ new: EvidenceLink) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: ResearchTask, _ new: ResearchTask) throws {
    guard old.caseID == new.caseID, old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "ResearchTask", id: old.id.rawValue) }
}

func checkReplacement(_ old: AuditEntry, _ new: AuditEntry) throws {
    guard old == new else { throw PersistenceError.immutableRecord(kind: "AuditEntry", id: old.id.rawValue) }
}

func checkReplacement(_ old: ScriptDraft, _ new: ScriptDraft) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: ScriptStatement, _ new: ScriptStatement) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: CaseRevision, _ new: CaseRevision) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: CriterionEvaluation, _ new: CriterionEvaluation) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: CaseEvaluation, _ new: CaseEvaluation) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: MethodologyVersion, _ new: MethodologyVersion) throws {
    guard old == new else { throw PersistenceError.immutableRecord(kind: "MethodologyVersion", id: old.id.rawValue) }
}

func checkReplacement(_ old: ReviewerIdentity, _ new: ReviewerIdentity) throws {
}

func checkReplacement(_ old: Actor, _ new: Actor) throws {
}

func checkReplacement(_ old: ActorAffiliation, _ new: ActorAffiliation) throws {
    if old.verification == .verified || old.verification == .superseded {
        var normalized = ActorAffiliationDTO(new); normalized.verification = write(old.verification)
        guard normalized == ActorAffiliationDTO(old) else { throw PersistenceError.immutableRecord(kind: "ActorAffiliation", id: old.id.rawValue) }
        if old.verification != new.verification { try TransitionRules.validate(old.verification, to: new.verification) }
    }
}

func checkReplacement(_ old: Source, _ new: Source) throws {
    guard old.createdAt == new.createdAt else { throw PersistenceError.immutableRecord(kind: "Source", id: old.id.rawValue) }
}

func checkReplacement(_ old: SourceVersion, _ new: SourceVersion) throws {
    try RevisionRules.validateReplacement(old, with: new)
}

func checkReplacement(_ old: SourceExcerpt, _ new: SourceExcerpt) throws {
    try RevisionRules.validateReplacement(old, with: new)
}
