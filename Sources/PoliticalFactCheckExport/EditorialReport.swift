import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

/// Fixed fields for the selected approved editorial view; the archive separately preserves all history.
public struct EditorialCaseReportV1: Codable, Equatable {
    public let schemaVersion: Int
    public let title: String
    public let caseID: UUID
    let originalPromise: PromiseRevisionDTO
    let speaker: ActorDTO?
    let party: ActorDTO?
    let criteria: [CriterionRevisionDTO]
    let evaluation: CaseEvaluationDTO
    let criterionEvaluations: [CriterionEvaluationDTO]
    let methodology: MethodologyVersionDTO
    let evidenceLinks: [EvidenceLinkDTO]
    let actions: [ActionRevisionDTO]
    let participations: [ActionParticipationDTO]
    let sources: [SourceDTO]
    let sourceVersions: [SourceVersionDTO]
    let excerpts: [SourceExcerptDTO]
    let reviewers: [ReviewerIdentityDTO]
    let script: ScriptDraftDTO
    let statements: [ScriptStatementDTO]
    let statementSources: [StatementSourcesV1]
    let referenceKeys: [EditorialReferenceKeyV1]
    init(graph: DomainContext, input: ScriptGenerationInput, script: ScriptDraft) {
        schemaVersion = 1; title = graph.cases[0].title.value; caseID = graph.cases[0].id.rawValue
        originalPromise = PromiseRevisionDTO(input.promise)
        speaker = input.promise.speaker.content.knownValue.flatMap { graph.find($0) }.map(ActorDTO.init)
        party = input.promise.party.content.knownValue.flatMap { graph.find($0) }.map(ActorDTO.init)
        criteria = input.criteria.map(CriterionRevisionDTO.init)
        evaluation = CaseEvaluationDTO(input.evaluation)
        criterionEvaluations = input.criterionEvaluations.map(CriterionEvaluationDTO.init)
        methodology = MethodologyVersionDTO(input.methodology)
        evidenceLinks = input.evidence.map { EvidenceLinkDTO($0.link) }
        actions = input.actions.map(ActionRevisionDTO.init)
        let actionIDs = Set(input.actions.map { $0.id })
        participations = graph.participations.filter { actionIDs.contains($0.actionRevisionID) }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }.map(ActionParticipationDTO.init)
        let selected = script.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }
        self.script = ScriptDraftDTO(script); statements = selected.map(ScriptStatementDTO.init)
        var excerptIDs = Set(selected.flatMap { $0.excerptIDs } + input.evidence.flatMap { $0.link.excerptIDs })
        for id in input.promise.quote.excerptIDs + input.promise.context.excerptIDs + input.promise.statementDate.excerptIDs + input.promise.speaker.excerptIDs + input.promise.party.excerptIDs { excerptIDs.insert(id) }
        for action in input.actions { for id in action.excerptIDs { excerptIDs.insert(id) } }
        let selectedExcerpts = input.excerpts.filter { excerptIDs.contains($0.excerpt.id) }
        excerpts = selectedExcerpts.map { SourceExcerptDTO($0.excerpt) }
        let versionIDs = Set(selectedExcerpts.map { $0.excerpt.sourceVersionID })
        sourceVersions = input.sources.filter { versionIDs.contains($0.version.id) }.map { SourceVersionDTO($0.version) }
        let sourceIDs = Set(input.sources.filter { versionIDs.contains($0.version.id) }.map { $0.version.sourceID })
        sources = graph.sources.filter { sourceIDs.contains($0.id) }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }.map(SourceDTO.init)
        reviewers = graph.reviewers.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }.map(ReviewerIdentityDTO.init)
        referenceKeys = input.sources.filter { versionIDs.contains($0.version.id) }.map {
            EditorialReferenceKeyV1(key: $0.key, kind: "SourceVersion", id: $0.version.id.rawValue)
        } + selectedExcerpts.map {
            EditorialReferenceKeyV1(key: $0.key, kind: "SourceExcerpt", id: $0.excerpt.id.rawValue)
        } + input.evidence.map {
            EditorialReferenceKeyV1(key: $0.key, kind: "EvidenceLink", id: $0.link.id.rawValue)
        }
        statementSources = selected.map { statement in
            StatementSourcesV1(statementID: statement.id.rawValue,
                excerptKeys: input.excerpts.filter { statement.excerptIDs.contains($0.excerpt.id) }.map { $0.key },
                evidenceKeys: input.evidence.filter { statement.evidenceLinkIDs.contains($0.link.id) }.map { $0.key })
        }
    }
}
struct EditorialReferenceKeyV1: Codable, Equatable {
    let key: String
    let kind: String
    let id: UUID
}
struct StatementSourcesV1: Codable, Equatable {
    let statementID: UUID
    let excerptKeys: [String]
    let evidenceKeys: [String]
}

public struct EditorialPackageSummary: Equatable {
    public let caseID: EntityID<Case>
    public let evaluationID: EntityID<CaseEvaluation>
    public let scriptID: EntityID<ScriptDraft>
    public let title: String
    public let category: EvaluationCategory
    public let cutoff: DatedValue
    public let methodologyVersion: String
    public let scriptVersion: Int
    public let scriptStatus: ScriptStatus
    public let statementCount: Int
    public let sourceCount: Int
    public let excerptCount: Int
    public let schemaVersion: Int
    public let exportedAt: Date?
    public var cutoffText: String { EditorialDocuments.date(cutoff) }
}
