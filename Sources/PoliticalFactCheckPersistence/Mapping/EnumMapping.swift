import PoliticalFactCheckCore

func write(_ value: Provenance) -> String {
    switch value {
    case .humanEntered: return "humanEntered"
    case .aiExtracted: return "aiExtracted"
    case .imported: return "imported"
    }
}
func readProvenance(_ value: String) throws -> Provenance {
    switch value {
    case "humanEntered": return .humanEntered
    case "aiExtracted": return .aiExtracted
    case "imported": return .imported
    default: throw PersistenceError.invalidEnum(type: "Provenance", value: value)
    }
}

func write(_ value: ActorType) -> String {
    switch value {
    case .person: return "person"
    case .party: return "party"
    case .faction: return "faction"
    case .government: return "government"
    case .authority: return "authority"
    case .institution: return "institution"
    }
}
func readActorType(_ value: String) throws -> ActorType {
    switch value {
    case "person": return .person
    case "party": return .party
    case "faction": return .faction
    case "government": return .government
    case "authority": return .authority
    case "institution": return .institution
    default: throw PersistenceError.invalidEnum(type: "ActorType", value: value)
    }
}

func write(_ value: FactVerificationState) -> String {
    switch value {
    case .unreviewed: return "unreviewed"
    case .verified: return "verified"
    case .rejected: return "rejected"
    case .superseded: return "superseded"
    }
}
func readFactVerificationState(_ value: String) throws -> FactVerificationState {
    switch value {
    case "unreviewed": return .unreviewed
    case "verified": return .verified
    case "rejected": return .rejected
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "FactVerificationState", value: value)
    }
}

func write(_ value: CaseWorkflowState) -> String {
    switch value {
    case .candidate: return "candidate"
    case .documented: return "documented"
    case .verified: return "verified"
    case .readyForEvaluation: return "readyForEvaluation"
    case .evaluated: return "evaluated"
    case .approved: return "approved"
    }
}
func readCaseWorkflowState(_ value: String) throws -> CaseWorkflowState {
    switch value {
    case "candidate": return .candidate
    case "documented": return .documented
    case "verified": return .verified
    case "readyForEvaluation": return .readyForEvaluation
    case "evaluated": return .evaluated
    case "approved": return .approved
    default: throw PersistenceError.invalidEnum(type: "CaseWorkflowState", value: value)
    }
}

func write(_ value: CriterionRevisionState) -> String {
    switch value {
    case .draft: return "draft"
    case .confirmed: return "confirmed"
    case .superseded: return "superseded"
    }
}
func readCriterionRevisionState(_ value: String) throws -> CriterionRevisionState {
    switch value {
    case "draft": return .draft
    case "confirmed": return .confirmed
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "CriterionRevisionState", value: value)
    }
}

func write(_ value: EvaluationStatus) -> String {
    switch value {
    case .draft: return "draft"
    case .needsReview: return "needsReview"
    case .approved: return "approved"
    case .reviewRequired: return "reviewRequired"
    case .superseded: return "superseded"
    }
}
func readEvaluationStatus(_ value: String) throws -> EvaluationStatus {
    switch value {
    case "draft": return .draft
    case "needsReview": return .needsReview
    case "approved": return .approved
    case "reviewRequired": return .reviewRequired
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "EvaluationStatus", value: value)
    }
}

func write(_ value: ExcerptVerificationState) -> String {
    switch value {
    case .unverified: return "unverified"
    case .verified: return "verified"
    case .rejected: return "rejected"
    case .superseded: return "superseded"
    }
}
func readExcerptVerificationState(_ value: String) throws -> ExcerptVerificationState {
    switch value {
    case "unverified": return .unverified
    case "verified": return .verified
    case "rejected": return .rejected
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "ExcerptVerificationState", value: value)
    }
}

func write(_ value: ScriptStatus) -> String {
    switch value {
    case .draft: return "draft"
    case .needsReview: return "needsReview"
    case .approved: return "approved"
    case .superseded: return "superseded"
    }
}
func readScriptStatus(_ value: String) throws -> ScriptStatus {
    switch value {
    case "draft": return .draft
    case "needsReview": return .needsReview
    case "approved": return .approved
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "ScriptStatus", value: value)
    }
}

func write(_ value: EvidenceRelationship) -> String {
    switch value {
    case .supports: return "supports"
    case .contradicts: return "contradicts"
    case .contextualizes: return "contextualizes"
    }
}
func readEvidenceRelationship(_ value: String) throws -> EvidenceRelationship {
    switch value {
    case "supports": return .supports
    case "contradicts": return .contradicts
    case "contextualizes": return .contextualizes
    default: throw PersistenceError.invalidEnum(type: "EvidenceRelationship", value: value)
    }
}

func write(_ value: EvidenceDirectness) -> String {
    switch value {
    case .direct: return "direct"
    case .indirect: return "indirect"
    }
}
func readEvidenceDirectness(_ value: String) throws -> EvidenceDirectness {
    switch value {
    case "direct": return .direct
    case "indirect": return .indirect
    default: throw PersistenceError.invalidEnum(type: "EvidenceDirectness", value: value)
    }
}

func write(_ value: EvidenceConfidence) -> String {
    switch value {
    case .high: return "high"
    case .medium: return "medium"
    case .low: return "low"
    }
}
func readEvidenceConfidence(_ value: String) throws -> EvidenceConfidence {
    switch value {
    case "high": return .high
    case "medium": return .medium
    case "low": return .low
    default: throw PersistenceError.invalidEnum(type: "EvidenceConfidence", value: value)
    }
}

func write(_ value: EvaluationCategory) -> String {
    switch value {
    case .fulfilled: return "fulfilled"
    case .mostlyFulfilled: return "mostlyFulfilled"
    case .partiallyFulfilled: return "partiallyFulfilled"
    case .notFulfilled: return "notFulfilled"
    case .contraryAction: return "contraryAction"
    case .notVerifiable: return "notVerifiable"
    }
}
func readEvaluationCategory(_ value: String) throws -> EvaluationCategory {
    switch value {
    case "fulfilled": return .fulfilled
    case "mostlyFulfilled": return .mostlyFulfilled
    case "partiallyFulfilled": return .partiallyFulfilled
    case "notFulfilled": return .notFulfilled
    case "contraryAction": return .contraryAction
    case "notVerifiable": return .notVerifiable
    default: throw PersistenceError.invalidEnum(type: "EvaluationCategory", value: value)
    }
}

func write(_ value: ResearchTaskStatus) -> String {
    switch value {
    case .open: return "open"
    case .attempted: return "attempted"
    case .blocked: return "blocked"
    case .completed: return "completed"
    case .cancelled: return "cancelled"
    }
}
func readResearchTaskStatus(_ value: String) throws -> ResearchTaskStatus {
    switch value {
    case "open": return .open
    case "attempted": return .attempted
    case "blocked": return .blocked
    case "completed": return .completed
    case "cancelled": return .cancelled
    default: throw PersistenceError.invalidEnum(type: "ResearchTaskStatus", value: value)
    }
}

func write(_ value: EvidenceLinkStatus) -> String {
    switch value {
    case .draft: return "draft"
    case .needsReview: return "needsReview"
    case .verified: return "verified"
    case .rejected: return "rejected"
    case .superseded: return "superseded"
    }
}
func readEvidenceLinkStatus(_ value: String) throws -> EvidenceLinkStatus {
    switch value {
    case "draft": return .draft
    case "needsReview": return .needsReview
    case "verified": return .verified
    case "rejected": return .rejected
    case "superseded": return .superseded
    default: throw PersistenceError.invalidEnum(type: "EvidenceLinkStatus", value: value)
    }
}

func write(_ value: SourceVersionKind) -> String {
    switch value {
    case .original: return "original"
    case .archived: return "archived"
    case .mirror: return "mirror"
    case .unknown: return "unknown"
    }
}
func readSourceVersionKind(_ value: String) throws -> SourceVersionKind {
    switch value {
    case "original": return .original
    case "archived": return .archived
    case "mirror": return .mirror
    case "unknown": return .unknown
    default: throw PersistenceError.invalidEnum(type: "SourceVersionKind", value: value)
    }
}

func write(_ value: SourceAvailability) -> String {
    switch value {
    case .available: return "available"
    case .unavailable: return "unavailable"
    case .blocked: return "blocked"
    case .unknown: return "unknown"
    }
}
func readSourceAvailability(_ value: String) throws -> SourceAvailability {
    switch value {
    case "available": return .available
    case "unavailable": return .unavailable
    case "blocked": return .blocked
    case "unknown": return .unknown
    default: throw PersistenceError.invalidEnum(type: "SourceAvailability", value: value)
    }
}

func write(_ value: ActionType) -> String {
    switch value {
    case .vote: return "vote"
    case .initiative: return "initiative"
    case .resolution: return "resolution"
    case .implementation: return "implementation"
    case .development: return "development"
    case .other: return "other"
    }
}
func readActionType(_ value: String) throws -> ActionType {
    switch value {
    case "vote": return .vote
    case "initiative": return .initiative
    case "resolution": return .resolution
    case "implementation": return .implementation
    case "development": return .development
    case "other": return .other
    default: throw PersistenceError.invalidEnum(type: "ActionType", value: value)
    }
}

func write(_ value: ParticipationKind) -> String {
    switch value {
    case .ownAction: return "ownAction"
    case .institutionalResult: return "institutionalResult"
    case .politicalSupport: return "politicalSupport"
    case .causalResponsibility: return "causalResponsibility"
    }
}
func readParticipationKind(_ value: String) throws -> ParticipationKind {
    switch value {
    case "ownAction": return .ownAction
    case "institutionalResult": return .institutionalResult
    case "politicalSupport": return .politicalSupport
    case "causalResponsibility": return .causalResponsibility
    default: throw PersistenceError.invalidEnum(type: "ParticipationKind", value: value)
    }
}

func write(_ value: HumanReviewState) -> String {
    switch value {
    case .unreviewed: return "unreviewed"
    case .reviewed: return "reviewed"
    }
}
func readHumanReviewState(_ value: String) throws -> HumanReviewState {
    switch value {
    case "unreviewed": return .unreviewed
    case "reviewed": return .reviewed
    default: throw PersistenceError.invalidEnum(type: "HumanReviewState", value: value)
    }
}

func write(_ value: ScriptStatementKind) -> String {
    switch value {
    case .fact: return "fact"
    case .interpretation: return "interpretation"
    case .question: return "question"
    case .qualification: return "qualification"
    }
}
func readScriptStatementKind(_ value: String) throws -> ScriptStatementKind {
    switch value {
    case "fact": return .fact
    case "interpretation": return .interpretation
    case "question": return .question
    case "qualification": return .qualification
    default: throw PersistenceError.invalidEnum(type: "ScriptStatementKind", value: value)
    }
}

func write(_ value: NotVerifiableReason) -> String {
    switch value {
    case .unclearPromise: return "unclearPromise"
    case .openDeadline: return "openDeadline"
    case .conditionNotMet: return "conditionNotMet"
    case .missingEvidence: return "missingEvidence"
    case .unclearAttribution: return "unclearAttribution"
    case .conflictingSources: return "conflictingSources"
    case .researchBlocked: return "researchBlocked"
    }
}
func readNotVerifiableReason(_ value: String) throws -> NotVerifiableReason {
    switch value {
    case "unclearPromise": return .unclearPromise
    case "openDeadline": return .openDeadline
    case "conditionNotMet": return .conditionNotMet
    case "missingEvidence": return .missingEvidence
    case "unclearAttribution": return .unclearAttribution
    case "conflictingSources": return .conflictingSources
    case "researchBlocked": return .researchBlocked
    default: throw PersistenceError.invalidEnum(type: "NotVerifiableReason", value: value)
    }
}

func write(_ value: DatePrecision) -> String {
    switch value {
    case .instant: return "instant"
    case .day: return "day"
    case .month: return "month"
    case .year: return "year"
    case .interval: return "interval"
    }
}
func readDatePrecision(_ value: String) throws -> DatePrecision {
    switch value {
    case "instant": return .instant
    case "day": return .day
    case "month": return .month
    case "year": return .year
    case "interval": return .interval
    default: throw PersistenceError.invalidEnum(type: "DatePrecision", value: value)
    }
}

func write(_ value: DateRole) -> String {
    switch value {
    case .statement: return "statement"
    case .event: return "event"
    case .publication: return "publication"
    case .retrieval: return "retrieval"
    case .validity: return "validity"
    case .evaluationCutoff: return "evaluationCutoff"
    case .deadline: return "deadline"
    case .creation: return "creation"
    case .review: return "review"
    case .approval: return "approval"
    }
}
func readDateRole(_ value: String) throws -> DateRole {
    switch value {
    case "statement": return .statement
    case "event": return .event
    case "publication": return .publication
    case "retrieval": return .retrieval
    case "validity": return .validity
    case "evaluationCutoff": return .evaluationCutoff
    case "deadline": return .deadline
    case "creation": return .creation
    case "review": return .review
    case "approval": return .approval
    default: throw PersistenceError.invalidEnum(type: "DateRole", value: value)
    }
}

func write(_ value: TemporalEligibility) -> String {
    switch value {
    case .atOrBeforeCutoff: return "atOrBeforeCutoff"
    case .afterCutoff: return "afterCutoff"
    case .requiresHumanReview: return "requiresHumanReview"
    }
}
func readTemporalEligibility(_ value: String) throws -> TemporalEligibility {
    switch value {
    case "atOrBeforeCutoff": return .atOrBeforeCutoff
    case "afterCutoff": return .afterCutoff
    case "requiresHumanReview": return .requiresHumanReview
    default: throw PersistenceError.invalidEnum(type: "TemporalEligibility", value: value)
    }
}

func write(_ value: EntityKind) -> String {
    switch value {
    case .reviewer: return "reviewer"
    case .politicalCase: return "politicalCase"
    case .actor: return "actor"
    case .affiliation: return "affiliation"
    case .promise: return "promise"
    case .promiseRevision: return "promiseRevision"
    case .criterion: return "criterion"
    case .criterionRevision: return "criterionRevision"
    case .source: return "source"
    case .sourceVersion: return "sourceVersion"
    case .excerpt: return "excerpt"
    case .action: return "action"
    case .actionRevision: return "actionRevision"
    case .participation: return "participation"
    case .evidenceLink: return "evidenceLink"
    case .caseRevision: return "caseRevision"
    case .criterionEvaluation: return "criterionEvaluation"
    case .caseEvaluation: return "caseEvaluation"
    case .methodology: return "methodology"
    case .researchTask: return "researchTask"
    case .auditEntry: return "auditEntry"
    case .script: return "script"
    case .statement: return "statement"
    }
}
func readEntityKind(_ value: String) throws -> EntityKind {
    switch value {
    case "reviewer": return .reviewer
    case "politicalCase": return .politicalCase
    case "actor": return .actor
    case "affiliation": return .affiliation
    case "promise": return .promise
    case "promiseRevision": return .promiseRevision
    case "criterion": return .criterion
    case "criterionRevision": return .criterionRevision
    case "source": return .source
    case "sourceVersion": return .sourceVersion
    case "excerpt": return .excerpt
    case "action": return .action
    case "actionRevision": return .actionRevision
    case "participation": return .participation
    case "evidenceLink": return .evidenceLink
    case "caseRevision": return .caseRevision
    case "criterionEvaluation": return .criterionEvaluation
    case "caseEvaluation": return .caseEvaluation
    case "methodology": return .methodology
    case "researchTask": return .researchTask
    case "auditEntry": return .auditEntry
    case "script": return .script
    case "statement": return .statement
    default: throw PersistenceError.invalidEnum(type: "EntityKind", value: value)
    }
}

func write(_ value: ReviewerKind) -> String {
    switch value {
    case .human: return "human"
    }
}
func readReviewerKind(_ value: String) throws -> ReviewerKind {
    switch value {
    case "human": return .human
    default: throw PersistenceError.invalidEnum(type: "ReviewerKind", value: value)
    }
}

func write(_ value: CaseReviewState) -> String {
    switch value {
    case .notYetApproved: return "notYetApproved"
    case .upToDate: return "upToDate"
    case .reviewRequired: return "reviewRequired"
    }
}
func readCaseReviewState(_ value: String) throws -> CaseReviewState {
    switch value {
    case "notYetApproved": return .notYetApproved
    case "upToDate": return .upToDate
    case "reviewRequired": return .reviewRequired
    default: throw PersistenceError.invalidEnum(type: "CaseReviewState", value: value)
    }
}
