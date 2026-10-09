import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

public struct ResearchManualAssessment {
    public let criteria: [ManualCriterionAssessment]
    public let overall: ManualAssessment
    public let facts: [NonEmptyText]
    public let interpretations: [NonEmptyText]
    public let cutoff: DatedValue
}
public enum ResearchAssessmentMapping {
    public static func category(_ value: ResearchCategory) -> EvaluationCategory {
        switch value {
        case .fulfilled: return .fulfilled
        case .mostlyFulfilled: return .mostlyFulfilled
        case .partiallyFulfilled: return .partiallyFulfilled
        case .notFulfilled: return .notFulfilled
        case .contraryAction: return .contraryAction
        case .notVerifiable: return .notVerifiable
        }
    }
    public static func confidence(_ value: ResearchConfidence) -> EvidenceConfidence {
        switch value { case .high: return .high; case .medium: return .medium; case .low: return .low }
    }
    public static func reason(_ reason: ResearchNotVerifiableReason) -> NotVerifiableReason {
        switch reason {
        case .unclearPromise: return .unclearPromise
        case .openDeadline: return .openDeadline
        case .conditionNotMet: return .conditionNotMet
        case .missingEvidence: return .missingEvidence
        case .unclearAttribution: return .unclearAttribution
        case .conflictingSources: return .conflictingSources
        case .researchBlocked: return .researchBlocked
        }
    }
    public static func assessment(category: ResearchCategory?, confidence: ResearchConfidence, rationale: String,
        uncertainties: [String], reasons: [ResearchNotVerifiableReason]) throws -> ManualAssessment {
        guard let category else { throw ResearchReviewError.noRecommendation }
        return try ManualAssessment(category: self.category(category), rationale: NonEmptyText(rationale), confidence: self.confidence(confidence),
            uncertainties: uncertainties.map { try NonEmptyText($0) }, notVerifiableReasons: reasons.map(reason))
    }
    public static func materialize(plan: ResearchReviewPlan, graph: DomainContext) throws -> ResearchManualAssessment {
        guard plan.blockingIssues.isEmpty else { throw ResearchReviewError.missingDecision }
        try CaseResearchValidation.validate(plan.record.result, request: plan.record.request)
        let rows = try plan.record.result.criterionAssessmentDrafts.compactMap { row -> ManualCriterionAssessment? in
            guard let id = plan.criterionIDs[row.criterionKey] else { return nil }
            guard let criterion = graph.find(id), criterion.state == .confirmed,
                  graph.find(criterion.criterionID)?.currentRevisionID == id else { throw ResearchReviewError.unconfirmedCriteria }
            func links(_ keys: [String]) throws -> [EntityID<EvidenceLink>] {
                try keys.compactMap { key -> EntityID<EvidenceLink>? in
                    guard let id = plan.evidenceIDs[key] else {
                        if row.suggestedCategory == .notVerifiable { return nil }
                        throw ResearchReviewError.incompleteSources
                    }
                    guard let link = graph.find(id), link.status == .verified, link.review != nil,
                          link.criterionRevisionID == criterion.id,
                          DomainValidator.validate(link, in: graph).isValid else { throw ResearchReviewError.incompleteSources }
                    return id
                }
            }
            return try ManualCriterionAssessment(criterionRevisionID: id,
                assessment: assessment(category: row.suggestedCategory, confidence: row.confidence, rationale: row.rationale, uncertainties: row.uncertainties, reasons: row.notVerifiableReasons),
                evidenceLinkIDs: Array(Set(try links(row.supportingEvidenceKeys + row.counterEvidenceKeys))), counterEvidenceLinkIDs: links(row.counterEvidenceKeys))
        }
        let overall = plan.record.result.overallAssessmentDraft
        return try ResearchManualAssessment(criteria: rows,
            overall: assessment(category: overall.suggestedCategory, confidence: overall.confidence, rationale: overall.rationale, uncertainties: overall.uncertainties, reasons: overall.notVerifiableReasons),
            facts: overall.facts.map { try NonEmptyText($0) }, interpretations: overall.interpretations.map { try NonEmptyText($0) },
            cutoff: .instant(plan.record.researchCutoff, role: .evaluationCutoff))
    }
}
