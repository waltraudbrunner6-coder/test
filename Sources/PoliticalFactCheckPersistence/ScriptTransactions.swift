import Foundation
import CryptoKit
import SwiftData
import PoliticalFactCheckCore
import PoliticalFactCheckScripting

extension LocalCaseStore {
    /// Local-only change token. The digest, graph and audits are never part of the provider request.
    public func scriptGenerationChangeToken(caseID: EntityID<Case>) throws -> String {
        guard let graph = try loadCase(id: caseID) else { throw PersistenceError.missingEntity(kind: "Case", id: caseID.rawValue) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(CaseGraphDTO(graph))
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    /// Rebuild the input after the async provider returns: stale output cannot bypass a new review request.
    @discardableResult
    public func saveGeneratedScriptDraft(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        output: ScriptGenerationOutput, targetDurationSeconds: Double = 45,
        providerIdentifier: NonEmptyText = try! NonEmptyText("local-test-provider-no-ai"),
        reviewer: ReviewerIdentity, at date: Date) throws -> ScriptDraft {
        try saveScriptDraft(caseID: caseID, evaluationID: evaluationID, output: output,
            targetDurationSeconds: targetDurationSeconds,
            author: .ai(model: providerIdentifier, templateVersion: "script-contract-1"),
            reviewer: reviewer, at: date)
    }

    @discardableResult
    public func saveManualScriptDraft(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        output: ScriptGenerationOutput, targetDurationSeconds: Double = 45,
        reviewer: ReviewerIdentity, at date: Date) throws -> ScriptDraft {
        try saveScriptDraft(caseID: caseID, evaluationID: evaluationID, output: output,
            targetDurationSeconds: targetDurationSeconds, author: .human(reviewer.id), reviewer: reviewer, at: date)
    }

    private func saveScriptDraft(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        output: ScriptGenerationOutput, targetDurationSeconds: Double, author: Authorship,
        reviewer: ReviewerIdentity, at date: Date) throws -> ScriptDraft {
        var result: ScriptDraft?
        try transaction("saveScriptDraft") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard graph.find(evaluationID)?.caseID == caseID else { throw PersistenceError.scriptGeneration(.evaluationUnavailable) }
            let input = try scriptChange { try ScriptInputBuilder.build(evaluationID: evaluationID,
                targetDurationSeconds: targetDurationSeconds, in: graph) }
            try scriptChange { try ScriptOutputValidator.validate(output, input: input) }
            let scriptID = EntityID<ScriptDraft>()
            let statements = try output.statements.sorted { $0.position < $1.position }.map { value in
                try ScriptStatement(scriptDraftID: scriptID, position: value.position, text: NonEmptyText(value.text),
                    kind: value.kind,
                    excerptIDs: value.referencedExcerptKeys.map { key in input.excerpts.first { $0.key == key }!.excerpt.id },
                    evidenceLinkIDs: value.referencedEvidenceKeys.map { key in input.evidence.first { $0.key == key }!.link.id },
                    uncertainty: value.uncertainty.map { try NonEmptyText($0) })
            }
            let version = (graph.scripts.filter { $0.caseEvaluationID == evaluationID }.map { $0.version }.max() ?? 0) + 1
            let script = ScriptDraft(id: scriptID, caseEvaluationID: evaluationID, version: version,
                targetDurationSeconds: targetDurationSeconds, statementIDs: statements.map { $0.id }, author: author, createdAt: date)
            var dto = CaseGraphDTO(graph)
            dto.scripts.append(ScriptDraftDTO(script)); dto.statements.append(contentsOf: statements.map(ScriptStatementDTO.init))
            try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .script, id: script.id),
                operation: "createScriptDraft", author: author, reviewer: reviewer, at: date)
            if version > 1 {
                try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .script, id: script.id),
                    operation: "createScriptVersion", author: author, reviewer: reviewer, at: date)
            }
            try writeCase(domainChange { try dto.domain() }, in: context)
            result = script
        }
        guard let result else { throw PersistenceError.invalidAggregate }
        return result
    }

    public func reviewScriptStatement(caseID: EntityID<Case>, statementID: EntityID<ScriptStatement>,
                                     reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("reviewScriptStatement") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let statement = graph.find(statementID) else { throw PersistenceError.missingEntity(kind: "ScriptStatement", id: statementID.rawValue) }
            let next = try domainChange { try DomainChanges.reviewScriptStatement(statement,
                review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: graph) }
            var dto = CaseGraphDTO(graph)
            let index = dto.statements.firstIndex { $0.id.value == statementID.rawValue }!
            dto.statements[index] = ScriptStatementDTO(next)
            try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .statement, id: statementID),
                operation: "reviewScriptStatement", author: .human(reviewer.id), reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    public func submitScriptForReview(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>,
                                     reviewer: ReviewerIdentity, at date: Date) throws {
        try changeScriptStatus(caseID: caseID, scriptID: scriptID, status: .needsReview, reviewer: reviewer, at: date)
    }
    public func approveScript(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>,
                              reviewer: ReviewerIdentity, at date: Date) throws {
        try changeScriptStatus(caseID: caseID, scriptID: scriptID, status: .approved, reviewer: reviewer, at: date)
    }

    /// One explicit selection, one reviewer/date, one save. Already reviewed sentences
    /// remain byte-for-byte unchanged; any invalid member rolls back the whole selection.
    public func reviewScriptStatements(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>,
        statementIDs: Set<EntityID<ScriptStatement>>, reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("reviewScriptStatements") { context in
            var graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            let plan = try ScriptReviewPlan.build(caseID: caseID, in: graph)
            guard let script = graph.find(scriptID), plan.scriptID == scriptID,
                  script.status == .draft || script.status == .needsReview,
                  !statementIDs.isEmpty, statementIDs.isSubset(of: Set(script.statementIDs)) else {
                throw ScriptReviewError.invalidSelection
            }
            var dto = CaseGraphDTO(graph)
            for id in script.statementIDs where statementIDs.contains(id) {
                guard let statement = graph.find(id) else { throw ScriptReviewError.invalidSelection }
                if statement.review != nil { continue }
                let next = try domainChange { try DomainChanges.reviewScriptStatement(statement,
                    review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: graph) }
                guard let index = dto.statements.firstIndex(where: { $0.id.value == id.rawValue }) else {
                    throw ScriptReviewError.invalidSelection
                }
                dto.statements[index] = ScriptStatementDTO(next)
                try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .statement, id: id),
                    operation: "reviewScriptStatement", author: .human(reviewer.id), reviewer: reviewer, at: date)
                graph = try domainChange { try dto.domain() }
            }
            try writeCase(graph, in: context)
        }
    }

    /// Stages adjacent Core transitions in the same unsaved context, then saves exactly
    /// once through transaction(). No direct draft -> approved replacement.
    public func approveReviewedScript(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>,
        explicitConfirmation: Bool, reviewer: ReviewerIdentity, at date: Date) throws {
        try approveReviewedScript(caseID: caseID, scriptID: scriptID, explicitConfirmation: explicitConfirmation,
            reviewer: reviewer, at: date, beforeFinalWrite: {})
    }

    /// Internal fault seam for testing rollback after the unsaved transition checkpoint.
    func approveReviewedScript(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>,
        explicitConfirmation: Bool, reviewer: ReviewerIdentity, at date: Date,
        beforeFinalWrite: () throws -> Void) throws {
        try transaction("approveReviewedScript") { context in
            guard explicitConfirmation else { throw ScriptReviewError.confirmationRequired }
            var graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            let plan = try ScriptReviewPlan.build(caseID: caseID, in: graph)
            guard plan.scriptID == scriptID, plan.readyForApproval, var script = graph.find(scriptID) else {
                throw ScriptReviewError.statementsNotReviewed
            }
            guard date >= script.createdAt,
                  script.statementIDs.compactMap({ graph.find($0)?.review?.reviewedAt }).allSatisfy({ $0 <= date }) else {
                throw PersistenceError.invalidDomain([.invalidReviewTime])
            }
            if script.status == .draft {
                script = try domainChange { try DomainChanges.transition(script, to: .needsReview, in: graph) }
                var dto = CaseGraphDTO(graph)
                let index = dto.scripts.firstIndex { $0.id.value == scriptID.rawValue }!
                dto.scripts[index] = ScriptDraftDTO(script)
                try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .script, id: scriptID),
                    operation: "submitScriptForReview", author: .human(reviewer.id), reviewer: reviewer, at: date)
                graph = try domainChange { try dto.domain() }
                try writeCase(graph, in: context) // unsaved checkpoint preserves replacement rules
            }
            let approved = try domainChange { try DomainChanges.transition(script, to: .approved,
                approval: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: graph) }
            var dto = CaseGraphDTO(graph)
            let index = dto.scripts.firstIndex { $0.id.value == scriptID.rawValue }!
            dto.scripts[index] = ScriptDraftDTO(approved)
            try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .script, id: scriptID),
                operation: "approveScript", author: .human(reviewer.id), reviewer: reviewer, at: date)
            try beforeFinalWrite()
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    private func changeScriptStatus(caseID: EntityID<Case>, scriptID: EntityID<ScriptDraft>, status: ScriptStatus,
                                    reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("changeScriptStatus") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let script = graph.find(scriptID), let evaluation = graph.find(script.caseEvaluationID) else {
                throw PersistenceError.missingEntity(kind: "ScriptDraft", id: scriptID.rawValue)
            }
            guard evaluation.status == .approved else { throw PersistenceError.scriptGeneration(.evaluationNotApproved(evaluation.status)) }
            guard date >= script.createdAt else { throw PersistenceError.invalidDomain([.invalidReviewTime]) }
            let next = try domainChange { try DomainChanges.transition(script, to: status,
                approval: status == .approved ? HumanReview(reviewerID: reviewer.id, reviewedAt: date) : nil, in: graph) }
            var dto = CaseGraphDTO(graph)
            let index = dto.scripts.firstIndex { $0.id.value == scriptID.rawValue }!
            dto.scripts[index] = ScriptDraftDTO(next)
            try scriptAudit(&dto, caseID: caseID, target: ObjectReference(kind: .script, id: scriptID),
                operation: status == .approved ? "approveScript" : "submitScriptForReview",
                author: .human(reviewer.id), reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    private func scriptAudit(_ dto: inout CaseGraphDTO, caseID: EntityID<Case>, target: ObjectReference,
                             operation: String, author: Authorship, reviewer: ReviewerIdentity, at date: Date) throws {
        dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID, target: target,
            operation: try NonEmptyText(operation), author: author, humanRequesterID: reviewer.id, occurredAt: date,
            reason: try NonEmptyText("Lokaler Skriptschritt; Bewertung und historische Referenzen unverändert"))))
    }
}

private func scriptChange<T>(_ operation: () throws -> T) throws -> T {
    do { return try operation() }
    catch let error as ScriptGenerationError { throw PersistenceError.scriptGeneration(error) }
}
