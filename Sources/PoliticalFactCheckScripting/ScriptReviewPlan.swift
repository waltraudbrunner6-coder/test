import Foundation
import PoliticalFactCheckCore

public enum ScriptReviewError: Error, Equatable {
    case currentEvaluationUnavailable
    case ambiguousEvaluation
    case ambiguousScript
    case scriptUnavailable
    case existingScriptRequiresReview
    case newVersionConfirmationRequired
    case invalidScript
    case confirmationRequired
    case statementsNotReviewed
    case invalidSelection
}

/// Conservative selection of an approved, current manifest. Never falls back to an old
/// approval when a newer assessment is awaiting review; unrelated approvals are ambiguous.
public enum CurrentScriptContext {
    public static func evaluation(caseID: EntityID<Case>, in graph: DomainContext) throws -> CaseEvaluation {
        guard let politicalCase = graph.find(caseID),
              try CaseReviews.state(of: politicalCase, in: graph) == .upToDate else {
            throw ScriptReviewError.currentEvaluationUnavailable
        }
        let all = graph.caseEvaluations.filter { $0.caseID == caseID }
        let heads = all.filter { candidate in
            !all.contains { descendant in
                var next = descendant.replacesEvaluationID
                var visited = Set<EntityID<CaseEvaluation>>()
                while let id = next, visited.insert(id).inserted {
                    if id == candidate.id { return true }
                    next = graph.find(id)?.replacesEvaluationID
                }
                return false
            }
        }
        guard heads.count <= 1 else { throw ScriptReviewError.ambiguousEvaluation }
        let relevant = graph.evidenceLinks.filter {
            $0.status == .verified && politicalCase.activeCriterionRevisionIDs.contains($0.criterionRevisionID)
        }
        let actions = Set(politicalCase.currentActionRevisionIDs + relevant.compactMap { $0.actionRevisionID })
        let candidates = heads.filter { evaluation in
            guard evaluation.status == .approved,
                  let snapshot = graph.find(evaluation.caseRevisionID) else { return false }
            return snapshot.promiseRevisionID == politicalCase.currentPromiseRevisionID &&
                Set(snapshot.criteria.map { $0.id }) == Set(politicalCase.activeCriterionRevisionIDs) &&
                Set(snapshot.actionRevisionIDs) == actions && relevant.allSatisfy { link in
                    snapshot.evidenceLinks.contains { $0.id == link.id && $0.state == .verified }
                }
        }
        guard !candidates.isEmpty else { throw ScriptReviewError.currentEvaluationUnavailable }
        guard candidates.count == 1 else { throw ScriptReviewError.ambiguousEvaluation }
        _ = try ScriptInputBuilder.build(evaluationID: candidates[0].id, in: graph)
        return candidates[0]
    }

    public static func script(evaluationID: EntityID<CaseEvaluation>, in graph: DomainContext) throws -> ScriptDraft? {
        let scripts = graph.scripts.filter { $0.caseEvaluationID == evaluationID }
        guard let version = scripts.map({ $0.version }).max() else { return nil }
        let latest = scripts.filter { $0.version == version }
        guard latest.count == 1 else { throw ScriptReviewError.ambiguousScript }
        return latest[0]
    }
}

public struct ScriptReviewSourceSummary: Equatable {
    public let excerptID: EntityID<SourceExcerpt>
    public let sourceVersionID: EntityID<SourceVersion>
    public let title: String?
    public let publisher: String?
    public let url: URL?
    public let locator: String
    public let exactExcerptText: String
    public let relationships: [EvidenceRelationship]
}

public struct ScriptReviewItem: Equatable {
    public let statementID: EntityID<ScriptStatement>
    public let position: Int
    public let text: String
    public let kind: ScriptStatementKind
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let evidenceLinkIDs: [EntityID<EvidenceLink>]
    public let uncertainty: String?
    public let reviewState: HumanReviewState
    public let sourceSummaries: [ScriptReviewSourceSummary]
}

/// Nonpersisted projection; deriving it never writes reviews or changes the graph.
public struct ScriptReviewPlan: Equatable {
    public let evaluationID: EntityID<CaseEvaluation>
    public let scriptID: EntityID<ScriptDraft>?
    public let scriptVersion: Int?
    public let scriptStatus: ScriptStatus?
    public let statementItems: [ScriptReviewItem]
    public let blockingIssues: [ScriptReviewError]
    public var reviewedCount: Int { statementItems.filter { $0.reviewState == .reviewed }.count }
    public var totalCount: Int { statementItems.count }
    public var generationAvailable: Bool { scriptID == nil && blockingIssues.isEmpty }
    public var readyForApproval: Bool {
        blockingIssues.isEmpty && totalCount > 0 && reviewedCount == totalCount &&
            (scriptStatus == .draft || scriptStatus == .needsReview)
    }
    public var readyForVideo: Bool {
        blockingIssues.isEmpty && scriptStatus == .approved && totalCount > 0 && reviewedCount == totalCount
    }

    public static func build(caseID: EntityID<Case>, in graph: DomainContext) throws -> ScriptReviewPlan {
        let evaluation = try CurrentScriptContext.evaluation(caseID: caseID, in: graph)
        guard let script = try CurrentScriptContext.script(evaluationID: evaluation.id, in: graph) else {
            return ScriptReviewPlan(evaluationID: evaluation.id, scriptID: nil, scriptVersion: nil,
                scriptStatus: nil, statementItems: [], blockingIssues: [])
        }
        var issues: [ScriptReviewError] = []
        if !DomainValidator.validate(script, in: graph).isValid || !script.targetDurationSeconds.isFinite ||
            !(30...60).contains(script.targetDurationSeconds) { issues.append(.invalidScript) }
        let items = script.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }.map { statement in
            let summaries = statement.excerptIDs.compactMap { id -> ScriptReviewSourceSummary? in
                guard let excerpt = graph.find(id), excerpt.state == .verified,
                      let version = graph.find(excerpt.sourceVersionID), version.verification == .verified,
                      DomainValidator.validate(excerpt, in: graph).isValid else { return nil }
                let relationships = statement.evidenceLinkIDs.compactMap { graph.find($0) }
                    .filter { $0.excerptIDs.contains(id) }.map { $0.relationship }
                return ScriptReviewSourceSummary(excerptID: id, sourceVersionID: version.id,
                    title: version.title?.value, publisher: version.publisher?.value,
                    url: version.finalURL ?? version.requestedURL ?? version.archiveURL ?? graph.find(version.sourceID)?.canonicalURL,
                    locator: excerpt.locator.value, exactExcerptText: excerpt.text.value, relationships: relationships)
            }
            return ScriptReviewItem(statementID: statement.id, position: statement.position, text: statement.text.value,
                kind: statement.kind, excerptIDs: statement.excerptIDs, evidenceLinkIDs: statement.evidenceLinkIDs,
                uncertainty: statement.uncertainty?.value, reviewState: statement.review == nil ? .unreviewed : .reviewed,
                sourceSummaries: summaries)
        }
        if items.contains(where: { $0.sourceSummaries.count != $0.excerptIDs.count }) && !issues.contains(.invalidScript) {
            issues.append(.invalidScript)
        }
        return ScriptReviewPlan(evaluationID: evaluation.id, scriptID: script.id, scriptVersion: script.version,
            scriptStatus: script.status, statementItems: items, blockingIssues: issues)
    }
}
