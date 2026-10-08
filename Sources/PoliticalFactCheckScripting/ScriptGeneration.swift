import Foundation
import PoliticalFactCheckCore

/// Transfer values, never independent evidence or persisted political truth.
public struct ScriptSource: Equatable {
    public let key: String
    public let version: SourceVersion
}
public struct ScriptExcerpt: Equatable {
    public let key: String
    public let sourceKey: String
    public let excerpt: SourceExcerpt
}
public struct ScriptEvidence: Equatable {
    public let key: String
    public let link: EvidenceLink
    public let excerptKeys: [String]
}
public struct ScriptGenerationInput: Equatable {
    public let evaluation: CaseEvaluation
    public let snapshotID: EntityID<CaseRevision>
    public let methodology: MethodologyVersion
    public let promise: PromiseRevision
    public let criteria: [CriterionRevision]
    public let criterionEvaluations: [CriterionEvaluation]
    public let sources: [ScriptSource]
    public let excerpts: [ScriptExcerpt]
    public let evidence: [ScriptEvidence]
    public let actions: [ActionRevision]
    public let targetDurationSeconds: Double
}

public struct GeneratedScriptStatement: Equatable {
    public let position: Int
    public let text: String
    public let kind: ScriptStatementKind
    public let referencedExcerptKeys: [String]
    public let referencedEvidenceKeys: [String]
    public let uncertainty: String?
    public init(position: Int, text: String, kind: ScriptStatementKind,
                referencedExcerptKeys: [String] = [], referencedEvidenceKeys: [String] = [], uncertainty: String? = nil) {
        self.position = position; self.text = text; self.kind = kind
        self.referencedExcerptKeys = referencedExcerptKeys; self.referencedEvidenceKeys = referencedEvidenceKeys
        self.uncertainty = uncertainty
    }
}
public struct ScriptGenerationOutput: Equatable {
    public let statements: [GeneratedScriptStatement]
    public init(statements: [GeneratedScriptStatement]) { self.statements = statements }
}

public protocol ScriptGenerationProvider {
    var identifier: NonEmptyText { get }
    func generateScript(input: ScriptGenerationInput) async throws -> ScriptGenerationOutput
}

public enum ScriptGenerationError: Error, Equatable {
    case evaluationUnavailable
    case evaluationNotApproved(EvaluationStatus)
    case snapshotUnavailable
    case invalidDuration
    case emptyOutput
    case invalidPosition
    case blankText
    case unknownExcerptKey(String)
    case unknownEvidenceKey(String)
    case duplicateKey
    case factWithoutExcerpt
    case inconsistentEvidence(String)
    case invalidSnapshot
    case providerFailure(String)
    case generationInProgress
}

public enum ScriptInputBuilder {
    public static func build(evaluationID: EntityID<CaseEvaluation>, targetDurationSeconds: Double = 45,
                             in graph: DomainContext) throws -> ScriptGenerationInput {
        guard let evaluation = graph.find(evaluationID) else { throw ScriptGenerationError.evaluationUnavailable }
        guard evaluation.status == .approved else { throw ScriptGenerationError.evaluationNotApproved(evaluation.status) }
        guard targetDurationSeconds.isFinite, (30...60).contains(targetDurationSeconds) else { throw ScriptGenerationError.invalidDuration }
        guard let snapshot = graph.find(evaluation.caseRevisionID) else { throw ScriptGenerationError.snapshotUnavailable }
        guard DomainValidator.validate(evaluation, in: graph).isValid,
              DomainValidator.validate(snapshot, in: graph).isValid,
              let methodology = graph.find(evaluation.methodologyVersionID),
              let promise = graph.find(snapshot.promiseRevisionID) else { throw ScriptGenerationError.invalidSnapshot }
        let criteria = try snapshot.criteria.map { entry -> CriterionRevision in
            guard entry.state == .confirmed, let value = graph.find(entry.id) else { throw ScriptGenerationError.invalidSnapshot }
            return value
        }
        let children = try evaluation.criterionEvaluationIDs.map { id -> CriterionEvaluation in
            guard let value = graph.find(id), value.caseEvaluationID == evaluationID else { throw ScriptGenerationError.invalidSnapshot }
            return value
        }
        let sources = try snapshot.sourceVersions.filter { $0.state == .verified }.enumerated().map { index, entry -> ScriptSource in
            guard let version = graph.find(entry.id) else { throw ScriptGenerationError.invalidSnapshot }
            return ScriptSource(key: "SRC-\(index + 1)", version: version)
        }
        let excerpts = try snapshot.excerpts.filter { $0.state == .verified }.enumerated().map { index, entry -> ScriptExcerpt in
            guard let excerpt = graph.find(entry.id), let source = sources.first(where: { $0.version.id == excerpt.sourceVersionID }),
                  DomainValidator.validate(excerpt, in: graph, verifiedAtSnapshot: true).isValid else { throw ScriptGenerationError.invalidSnapshot }
            return ScriptExcerpt(key: "EX-\(index + 1)", sourceKey: source.key, excerpt: excerpt)
        }
        let used = children.flatMap { $0.evidenceLinkIDs }
        let evidence = try snapshot.evidenceLinks.filter { $0.state == .verified && used.contains($0.id) }.enumerated().map { index, entry -> ScriptEvidence in
            guard let link = graph.find(entry.id) else { throw ScriptGenerationError.invalidSnapshot }
            let keys = try link.excerptIDs.map { id -> String in
                guard let value = excerpts.first(where: { $0.excerpt.id == id }) else { throw ScriptGenerationError.invalidSnapshot }
                return value.key
            }
            return ScriptEvidence(key: "EV-\(index + 1)", link: link, excerptKeys: keys)
        }
        let actions = try snapshot.actionRevisionIDs.map { id -> ActionRevision in
            guard let value = graph.find(id) else { throw ScriptGenerationError.invalidSnapshot }
            return value
        }
        return ScriptGenerationInput(evaluation: evaluation, snapshotID: snapshot.id, methodology: methodology,
            promise: promise, criteria: criteria, criterionEvaluations: children, sources: sources,
            excerpts: excerpts, evidence: evidence, actions: actions, targetDurationSeconds: targetDurationSeconds)
    }
}

public enum ScriptOutputValidator {
    public static func validate(_ output: ScriptGenerationOutput, input: ScriptGenerationInput) throws {
        guard !output.statements.isEmpty else { throw ScriptGenerationError.emptyOutput }
        var positions = Set<Int>()
        for statement in output.statements {
            guard statement.position >= 0, positions.insert(statement.position).inserted else { throw ScriptGenerationError.invalidPosition }
            guard !statement.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  statement.uncertainty.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true else { throw ScriptGenerationError.blankText }
            guard Set(statement.referencedExcerptKeys).count == statement.referencedExcerptKeys.count,
                  Set(statement.referencedEvidenceKeys).count == statement.referencedEvidenceKeys.count else { throw ScriptGenerationError.duplicateKey }
            for key in statement.referencedExcerptKeys {
                guard input.excerpts.contains(where: { $0.key == key }) else { throw ScriptGenerationError.unknownExcerptKey(key) }
            }
            for key in statement.referencedEvidenceKeys {
                guard let evidence = input.evidence.first(where: { $0.key == key }) else { throw ScriptGenerationError.unknownEvidenceKey(key) }
                guard evidence.excerptKeys.allSatisfy({ statement.referencedExcerptKeys.contains($0) }) else { throw ScriptGenerationError.inconsistentEvidence(key) }
            }
            if statement.kind == .fact && statement.referencedExcerptKeys.isEmpty { throw ScriptGenerationError.factWithoutExcerpt }
        }
    }
}

/// Deterministic development tool: copies supplied material, makes no new journalistic conclusions.
public struct FakeScriptGenerationProvider: ScriptGenerationProvider {
    public var identifier: NonEmptyText { try! NonEmptyText("local-test-provider-no-ai") }
    public init() {}
    public func generateScript(input: ScriptGenerationInput) async throws -> ScriptGenerationOutput {
        var statements: [GeneratedScriptStatement] = []
        if let excerpt = input.excerpts.first {
            statements.append(GeneratedScriptStatement(position: 0, text: excerpt.excerpt.text.value,
                kind: .fact, referencedExcerptKeys: [excerpt.key]))
        }
        statements.append(GeneratedScriptStatement(position: statements.count,
            text: input.evaluation.rationale.value, kind: .interpretation))
        for uncertainty in input.evaluation.uncertainties {
            statements.append(GeneratedScriptStatement(position: statements.count, text: uncertainty.value, kind: .qualification))
        }
        return ScriptGenerationOutput(statements: statements)
    }
}
