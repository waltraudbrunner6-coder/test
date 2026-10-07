public enum Provenance: Equatable { case humanEntered, aiExtracted, imported }
public enum ActorType: Equatable { case person, party, faction, government, authority, institution }
public enum FactVerificationState: Equatable { case unreviewed, verified, rejected, superseded }
public enum CaseWorkflowState: Equatable { case candidate, documented, verified, readyForEvaluation, evaluated, approved }
public enum CriterionRevisionState: Equatable { case draft, confirmed, superseded }
public enum EvaluationStatus: Equatable { case draft, needsReview, approved, reviewRequired, superseded }
public enum ExcerptVerificationState: Equatable { case unverified, verified, rejected, superseded }
public enum ScriptStatus: Equatable { case draft, needsReview, approved, superseded }
public enum EvidenceRelationship: Equatable { case supports, contradicts, contextualizes }
public enum EvidenceDirectness: Equatable { case direct, indirect }
public enum EvidenceConfidence: Equatable { case high, medium, low }
public enum EvaluationCategory: Equatable {
    case fulfilled, mostlyFulfilled, partiallyFulfilled, notFulfilled, contraryAction, notVerifiable
}
public enum ResearchTaskStatus: Equatable { case open, attempted, blocked, completed, cancelled }
public enum EvidenceLinkStatus: Equatable { case draft, needsReview, verified, rejected, superseded }
public enum SourceVersionKind: Equatable { case original, archived, mirror, unknown }
public enum SourceAvailability: Equatable { case available, unavailable, blocked, unknown }
public enum ActionType: Equatable { case vote, initiative, resolution, implementation, development, other }
public enum ParticipationKind: Equatable { case ownAction, institutionalResult, politicalSupport, causalResponsibility }
public enum HumanReviewState: Equatable { case unreviewed, reviewed }
public enum ScriptStatementKind: Equatable { case fact, interpretation, question, qualification }
public enum NotVerifiableReason: Equatable {
    case unclearPromise, openDeadline, conditionNotMet, missingEvidence, unclearAttribution, conflictingSources, researchBlocked
}
public enum DatePrecision: Equatable { case instant, day, month, year, interval }
public enum DateRole: Equatable {
    case statement, event, publication, retrieval, validity, evaluationCutoff, deadline, creation, review, approval
}
public enum TemporalEligibility: Equatable { case atOrBeforeCutoff, afterCutoff, requiresHumanReview }
public enum EntityKind: Equatable {
    case reviewer, politicalCase, actor, affiliation, promise, promiseRevision, criterion, criterionRevision
    case source, sourceVersion, excerpt, action, actionRevision, participation, evidenceLink
    case caseRevision, criterionEvaluation, caseEvaluation, methodology, researchTask, auditEntry, script, statement
}
