import Foundation
import PoliticalFactCheckCore

public enum ResearchIntent: String, Codable, CaseIterable { case original, support, contradiction, context, assessment }
public enum ResearchCategory: String, Codable { case fulfilled, mostlyFulfilled, partiallyFulfilled, notFulfilled, contraryAction, notVerifiable }
public enum ResearchConfidence: String, Codable { case high, medium, low }
public enum ResearchNotVerifiableReason: String, Codable { case unclearPromise, openDeadline, conditionNotMet, missingEvidence, unclearAttribution, conflictingSources, researchBlocked }
public enum ResearchRelationship: String, Codable {
    case supports, contradicts, contextualizes
    public var domain: EvidenceRelationship { switch self { case .supports: return .supports; case .contradicts: return .contradicts; case .contextualizes: return .contextualizes } }
}
public enum ResearchDirectness: String, Codable {
    case direct, indirect
    public var domain: EvidenceDirectness { self == .direct ? .direct : .indirect }
}
public enum ResearchTemporalRole: String, Codable { case event, validity }
public enum ResearchActionType: String, Codable {
    case vote, initiative, resolution, implementation, development, other
    public var domain: ActionType { switch self { case .vote: return .vote; case .initiative: return .initiative; case .resolution: return .resolution; case .implementation: return .implementation; case .development: return .development; case .other: return .other } }
}
public enum CaseResearchError: String, Error, Codable {
    case invalidRequest, invalidResult, invalidReference, outsidePolicy, missingSearchSource, unsafeAssessment, staleCandidate, alreadyResearched, invalidStoredRecord
    public var displayMessage: String {
        switch self {
        case .alreadyResearched: return "Bereits vertieft recherchiert"
        case .staleCandidate: return "Der Kandidat wurde während der Recherche verändert; Ergebnis nicht übernommen."
        case .unsafeAssessment: return "Der KI-Bewertungsvorschlag erfüllt die Methodik-Gates nicht."
        case .missingSearchSource: return "Recherchequelle fehlt in den tatsächlichen Search-Sources."
        case .outsidePolicy: return "Recherchequelle liegt außerhalb der Evidenzquellenpolitik."
        case .invalidReference: return "Der Rechercheentwurf enthält eine ungültige Referenz."
        case .invalidStoredRecord: return "Das gespeicherte Recherche-Dossier ist beschädigt."
        case .invalidRequest: return "Der Fall ist kein geeigneter ungeprüfter Recherchekandidat."
        case .invalidResult: return "Der Rechercheentwurf ist strukturell ungültig."
        }
    }
}
public struct CaseResearchRequest {
    public let caseID: EntityID<PoliticalFactCheckCore.Case>
    public let promiseRevisionID: EntityID<PromiseRevision>
    public let discovery: DiscoveryCandidateRecord
    public let policy: EvidenceSourcePolicy
    public let currentDate: Date // assessment cutoff
    public let startedAt: Date // actual research start, separate from historical cutoff
    public let maxCriteria: Int
    public let searchBudget: Int
    public let maxResultsPerLane: Int
    public let onProgress: ((ResearchIntent, String?) async -> Void)?
    public var maximumLanes: Int { 2 + 3 * maxCriteria }
    public init(caseID: EntityID<PoliticalFactCheckCore.Case>, promiseRevisionID: EntityID<PromiseRevision>, discovery: DiscoveryCandidateRecord,
                policy: EvidenceSourcePolicy, currentDate: Date = Date(), maxCriteria: Int = 3, searchBudget: Int = 3, maxResultsPerLane: Int = 4, onProgress: ((ResearchIntent, String?) async -> Void)? = nil, startedAt: Date? = nil) {
        self.caseID = caseID; self.promiseRevisionID = promiseRevisionID; self.discovery = discovery; self.policy = policy
        self.currentDate = currentDate; self.startedAt = startedAt ?? Date(); self.maxCriteria = maxCriteria; self.searchBudget = searchBudget; self.maxResultsPerLane = maxResultsPerLane; self.onProgress = onProgress
    }
    public static func make(in graph: DomainContext, policy: EvidenceSourcePolicy, currentDate: Date = Date()) throws -> Self {
        guard let root = graph.cases.first, graph.cases.count == 1, root.workflowState == .candidate,
              let item = try DiscoveryCandidateMapper.inboxItem(in: graph),
              graph.find(root.currentPromiseRevisionID)?.quote.content.knownValue?.value == item.candidate.exactQuote else { throw CaseResearchError.invalidRequest }
        return Self(caseID: root.id, promiseRevisionID: root.currentPromiseRevisionID, discovery: item.record, policy: policy, currentDate: currentDate)
    }
    public func validate() throws {
        try discovery.validate(); try policy.validate()
        guard (1...3).contains(maxCriteria), (1...5).contains(searchBudget), (1...6).contains(maxResultsPerLane),
              currentDate.timeIntervalSinceReferenceDate.isFinite, startedAt.timeIntervalSinceReferenceDate.isFinite, startedAt >= discovery.requestedAt else { throw CaseResearchError.invalidRequest }
    }
}
public protocol CaseResearchProvider {
    var identifier: NonEmptyText { get }
    func researchCase(request: CaseResearchRequest) async throws -> CaseResearchResult
}
public struct OriginalSourceReview: Codable, Equatable {
    public let context: String
    public let looksLikeCommitment: Bool
    public let statementDate: String?
    public let statementDatePrecision: String?
    public let uncertainties: [String]
}
public struct ProposedCriterion: Codable, Equatable {
    public let criterionKey: String
    public let goal: String
    public let targetGroup: String?
    public let baseline: String?
    public let deadline: String?
    public let conditions: [String]?
    public let isCore: Bool
    public let materialityRule: String
    public let uncertainties: [String]
}
public struct ResearchSourceClaim: Codable, Equatable {
    public let sourceKey: String
    public let url: String
    public let title: String?
    public let publisher: String?
    public let author: String?
    public let publicationDate: String?
    public let eventDate: String?
    public let contentType: String?
    public let language: String?
}
/// Extends existing web provenance; does not duplicate the transport source type.
public struct ProposedResearchSource: Codable, Equatable {
    public let claim: ResearchSourceClaim
    public let searchSource: ResearchWebSource
    public let category: EvidenceSourceCategory
}
public struct ProposedExcerpt: Codable, Equatable {
    public let excerptKey: String
    public let sourceKey: String
    public let text: String
    public let locator: String
    public let context: String
    public let language: String
    public let eventDate: String?
    public let uncertainties: [String]
}
public struct ProposedDevelopment: Codable, Equatable {
    public let developmentKey: String
    public let title: String
    public let type: ResearchActionType
    public let description: String
    public let eventDate: String?
    public let proceduralState: String
    public let scope: String?
    public let excerptKeys: [String]
    public let uncertainties: [String]
}
public struct EvidenceProposal: Codable, Equatable {
    public let evidenceKey: String
    public let criterionKey: String
    public let excerptKeys: [String]
    public let developmentKey: String?
    public let relationship: ResearchRelationship
    public let directness: ResearchDirectness
    public let rationale: String
    public let temporalRole: ResearchTemporalRole
    public let temporalDate: String?
    public let uncertainties: [String]
}
public struct ProposedCriterionAssessment: Codable, Equatable {
    public let criterionKey: String
    public let suggestedCategory: ResearchCategory? // nil = no recommendation, not a seventh category.
    public let confidence: ResearchConfidence
    public let rationale: String
    public let supportingEvidenceKeys: [String]
    public let counterEvidenceKeys: [String]
    public let facts: [String]
    public let interpretations: [String]
    public let uncertainties: [String]
    public let notVerifiableReasons: [ResearchNotVerifiableReason]
    public let decisiveUncertainty: Bool
    public let conditionsApplicable: Bool?
}
public struct ProposedCaseAssessment: Codable, Equatable {
    public let suggestedCategory: ResearchCategory?
    public let confidence: ResearchConfidence
    public let rationale: String
    public let facts: [String]
    public let interpretations: [String]
    public let uncertainties: [String]
    public let notVerifiableReasons: [ResearchNotVerifiableReason]
    public let criterionAssessmentKeys: [String]
    public let decisiveUncertainty: Bool
}
public struct ResearchIssue: Codable, Equatable {
    public let laneID: String
    public let message: String // controlled application message, never raw server response.
}
public struct CriterionSearchCoverage: Codable, Equatable {
    public let criterionKey: String
    public let supportSearchPerformed: Bool
    public let contradictionSearchPerformed: Bool
    public let contextSearchPerformed: Bool
    public let supportSourceCount: Int
    public let contradictionSourceCount: Int
    public let contextSourceCount: Int
    public let blockedQueries: [String]
    public let failedQueries: [String]
    public let unresolvedQuestions: [String]
    public var permitsRecommendation: Bool { supportSearchPerformed && contradictionSearchPerformed && contextSearchPerformed && blockedQueries.isEmpty && failedQueries.isEmpty }
}
public struct CaseResearchResult: Codable, Equatable {
    public let originalSourceReview: OriginalSourceReview
    public let proposedCriteria: [ProposedCriterion]
    public let webSources: [ResearchWebSource]
    public let citations: [ResearchCitation]
    public let sources: [ProposedResearchSource]
    public let excerpts: [ProposedExcerpt]
    public let developments: [ProposedDevelopment]
    public let evidenceProposals: [EvidenceProposal]
    public let criterionAssessmentDrafts: [ProposedCriterionAssessment]
    public let overallAssessmentDraft: ProposedCaseAssessment
    public let coverage: [CriterionSearchCoverage]
    public let uncertainties: [String]
    public let issues: [ResearchIssue]
    public let promptVersion: String
    public let startedAt: Date
    public let completedAt: Date
}
public struct ResearchDomainBindings: Codable, Equatable {
    public let criterionRevisions: [String: UUID]
    public let sources: [String: UUID]
    public let sourceVersions: [String: UUID]
    public let excerpts: [String: UUID]
    public let actionRevisions: [String: UUID]
    public let evidenceLinks: [String: UUID]
}
public struct DeepResearchRecordV1: Codable, Equatable {
    public let formatVersion: Int
    public let caseID: UUID
    public let promiseRevisionID: UUID
    public let discovery: DiscoveryCandidateRecord
    public let provider: String
    public let model: String
    public let evidenceSourcePolicy: EvidenceSourcePolicy
    public let researchCutoff: Date
    public let maxCriteria: Int
    public let searchBudget: Int
    public let maxResultsPerLane: Int
    public let result: CaseResearchResult
    public let bindings: ResearchDomainBindings?
    public init(request: CaseResearchRequest, provider: String, result: CaseResearchResult, bindings: ResearchDomainBindings? = nil) {
        formatVersion = 1; caseID = request.caseID.rawValue; promiseRevisionID = request.promiseRevisionID.rawValue
        discovery = request.discovery; self.provider = provider; model = provider; evidenceSourcePolicy = request.policy; researchCutoff = request.currentDate
        maxCriteria = request.maxCriteria; searchBudget = request.searchBudget; maxResultsPerLane = request.maxResultsPerLane; self.result = result; self.bindings = bindings
    }
    public var request: CaseResearchRequest { CaseResearchRequest(caseID: EntityID(caseID), promiseRevisionID: EntityID(promiseRevisionID),
        discovery: discovery, policy: evidenceSourcePolicy, currentDate: researchCutoff, maxCriteria: maxCriteria, searchBudget: searchBudget, maxResultsPerLane: maxResultsPerLane, startedAt: result.startedAt) }
    public func encode() throws -> String {
        let e = JSONEncoder(); e.dateEncodingStrategy = .millisecondsSince1970; e.outputFormatting = [.sortedKeys]
        return String(decoding: try e.encode(self), as: UTF8.self)
    }
    public static func decode(_ text: String) throws -> Self {
        do {
            let d = JSONDecoder(); d.dateDecodingStrategy = .millisecondsSince1970
            let value = try d.decode(Self.self, from: Data(text.utf8))
            guard value.formatVersion == 1, !value.provider.isEmpty, value.model == value.provider, value.bindings != nil else { throw CaseResearchError.invalidStoredRecord }
            try CaseResearchValidation.validate(value.result, request: value.request)
            return value
        } catch { throw CaseResearchError.invalidStoredRecord }
    }
}
