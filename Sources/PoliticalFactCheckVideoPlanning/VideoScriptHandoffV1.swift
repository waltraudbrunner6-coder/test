import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

public struct VideoScriptHandoffV1: Equatable {
    public let caseID: EntityID<Case>
    public let evaluationID: EntityID<CaseEvaluation>
    public let scriptID: EntityID<ScriptDraft>
    public let scriptVersion: Int
    public let targetDurationSeconds: Double
    public let scenes: [VideoSceneV1]
}

public struct VideoSceneV1: Equatable {
    public let position: Int
    public let statementID: EntityID<ScriptStatement>
    public let kind: ScriptStatementKind
    public let narrationText: String
    public let uncertainty: String?
    public let excerptIDs: [EntityID<SourceExcerpt>]
    public let evidenceLinkIDs: [EntityID<EvidenceLink>]
    public let sourceOverlays: [SourceOverlayV1]
    public let estimatedDurationSeconds: Double
}

public struct SourceOverlayV1: Equatable {
    public let sourceVersionID: EntityID<SourceVersion>
    public let sourceTitle: String?
    public let publisher: String?
    public let url: URL?
    public let locator: String
    public let excerptID: EntityID<SourceExcerpt>
}

public enum VideoHandoffError: Error, Equatable {
    case scriptUnavailable
    case scriptNotApproved
    case evaluationNotCurrent
    case statementNotReviewed
    case invalidDomain
    case invalidDuration
    case invalidSource
    case factWithoutOverlay
}

/// Internal, ephemeral Phase 6 input. No political assessment, persistence, AI or rendering.
public enum VideoScriptHandoffBuilder {
    public static func build(scriptID: EntityID<ScriptDraft>, in graph: DomainContext) throws -> VideoScriptHandoffV1 {
        guard let script = graph.find(scriptID) else { throw VideoHandoffError.scriptUnavailable }
        guard script.status == .approved, script.approval != nil else { throw VideoHandoffError.scriptNotApproved }
        guard let evaluation = graph.find(script.caseEvaluationID), evaluation.status == .approved,
              (try? CurrentScriptContext.evaluation(caseID: evaluation.caseID, in: graph).id) == evaluation.id,
              (try? CurrentScriptContext.script(evaluationID: evaluation.id, in: graph)?.id) == scriptID else {
            throw VideoHandoffError.evaluationNotCurrent
        }
        let statements = script.statementIDs.compactMap { graph.find($0) }.sorted { $0.position < $1.position }
        guard statements.count == script.statementIDs.count, !statements.isEmpty,
              statements.allSatisfy({ $0.review != nil }) else { throw VideoHandoffError.statementNotReviewed }
        guard DomainValidator.validate(graph).isValid,
              DomainValidator.validate(script, in: graph).isValid else { throw VideoHandoffError.invalidDomain }
        guard script.targetDurationSeconds.isFinite, (30...60).contains(script.targetDurationSeconds) else {
            throw VideoHandoffError.invalidDuration
        }
        let weights = statements.map { Double(max(1, $0.text.value.split(whereSeparator: { $0.isWhitespace }).count)) }
        let totalWeight = weights.reduce(0, +)
        var assigned: Double = 0
        let scenes = try statements.enumerated().map { index, statement -> VideoSceneV1 in
            let overlays = try statement.excerptIDs.map { id -> SourceOverlayV1 in
                guard let excerpt = graph.find(id), excerpt.state == .verified,
                      let source = graph.find(excerpt.sourceVersionID), source.verification == .verified,
                      DomainValidator.validate(excerpt, in: graph).isValid else { throw VideoHandoffError.invalidSource }
                return SourceOverlayV1(sourceVersionID: source.id, sourceTitle: source.title?.value,
                    publisher: source.publisher?.value,
                    url: source.finalURL ?? source.requestedURL ?? source.archiveURL ?? graph.find(source.sourceID)?.canonicalURL,
                    locator: excerpt.locator.value, excerptID: excerpt.id)
            }
            if statement.kind == .fact && overlays.isEmpty { throw VideoHandoffError.factWithoutOverlay }
            // Last scene gets the floating-point remainder, preserving the exact target sum.
            let duration = index == statements.count - 1 ? script.targetDurationSeconds - assigned :
                script.targetDurationSeconds * weights[index] / totalWeight
            assigned += duration
            return VideoSceneV1(position: statement.position, statementID: statement.id, kind: statement.kind,
                narrationText: statement.text.value, uncertainty: statement.uncertainty?.value,
                excerptIDs: statement.excerptIDs, evidenceLinkIDs: statement.evidenceLinkIDs,
                sourceOverlays: overlays, estimatedDurationSeconds: duration)
        }
        return VideoScriptHandoffV1(caseID: evaluation.caseID, evaluationID: evaluation.id, scriptID: scriptID,
            scriptVersion: script.version, targetDurationSeconds: script.targetDurationSeconds, scenes: scenes)
    }
}
