public enum TransitionRules {
    public static func validate(_ from: FactVerificationState, to: FactVerificationState) throws {
        switch (from, to) {
        case (.unreviewed, .verified), (.unreviewed, .rejected), (.verified, .superseded): return
        default: throw DomainValidationError.invalidFactTransition(from, to)
        }
    }
    public static func validate(_ from: ScriptStatus, to: ScriptStatus) throws {
        switch (from, to) {
        case (.draft, .needsReview), (.needsReview, .approved), (.approved, .superseded): return
        default: throw DomainValidationError.invalidScriptTransition(from, to)
        }
    }
    public static func validate(_ from: EvidenceLinkStatus, to: EvidenceLinkStatus) throws {
        switch (from, to) {
        case (.draft, .needsReview), (.needsReview, .verified), (.needsReview, .rejected), (.verified, .superseded): return
        default: throw DomainValidationError.invalidEvidenceTransition(from, to)
        }
    }
    public static func validate(_ from: CaseWorkflowState, to: CaseWorkflowState) throws {
        let allowed: Bool
        switch (from, to) {
        case (.candidate, .documented), (.documented, .verified), (.verified, .readyForEvaluation),
             (.readyForEvaluation, .evaluated), (.evaluated, .approved): allowed = true
        default: allowed = false
        }
        if !allowed { throw DomainValidationError.invalidCaseTransition(from, to) }
    }
    public static func validate(_ from: CriterionRevisionState, to: CriterionRevisionState) throws {
        switch (from, to) {
        case (.draft, .confirmed), (.confirmed, .superseded): return
        default: throw DomainValidationError.invalidCriterionTransition(from, to)
        }
    }
    public static func validate(_ from: ExcerptVerificationState, to: ExcerptVerificationState) throws {
        switch (from, to) {
        case (.unverified, .verified), (.verified, .superseded), (.unverified, .rejected): return
        default: throw DomainValidationError.invalidExcerptTransition(from, to)
        }
    }
    public static func validate(_ from: EvaluationStatus, to: EvaluationStatus) throws {
        switch (from, to) {
        case (.draft, .needsReview), (.needsReview, .approved), (.approved, .reviewRequired), (.reviewRequired, .superseded): return
        default: throw DomainValidationError.invalidEvaluationTransition(from, to)
        }
    }
}
