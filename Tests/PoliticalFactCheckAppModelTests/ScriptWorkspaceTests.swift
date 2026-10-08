import Foundation
import XCTest
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckCore
import PoliticalFactCheckAppModel
import PoliticalFactCheckScripting

final class ScriptWorkspaceTests: XCTestCase {
    @MainActor func testFakeGenerationReloadHumanReviewAndApprovalWorkflow() async throws {
        let (f, store, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let generatedID = await model.generateScript(evaluationID: f.evaluation.id)
        let id = try XCTUnwrap(generatedID)
        let draft = try XCTUnwrap(model.selectedContext?.find(id))
        XCTAssertEqual(draft.status, .draft); XCTAssertNil(draft.approval)
        let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
        XCTAssertEqual(reopened.selectedContext?.find(id), draft)
        for statementID in draft.statementIDs { XCTAssertTrue(reopened.reviewScriptStatement(statementID)) }
        XCTAssertTrue(reopened.submitScriptForReview(id))
        XCTAssertTrue(reopened.approveScript(id))
        XCTAssertEqual(reopened.selectedContext?.find(id)?.status, .approved)
        XCTAssertEqual(reopened.selectedContext?.find(id)?.approval?.reviewerID, f.reviewer.id)
        XCTAssertEqual(reopened.selectedContext?.find(f.evaluation.id), f.evaluation)
        XCTAssertEqual(reopened.selectedContext?.find(f.snapshot.id), f.snapshot)
        XCTAssertNil(reopened.errorMessage)
    }
    @MainActor func testProviderFailureShowsErrorAndPersistsNothing() async throws {
        let (f, store, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: FailingScriptProvider())
        XCTAssertNil(result); XCTAssertTrue(model.errorMessage?.contains("Provider fehlgeschlagen") == true)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.scripts, before.scripts); XCTAssertEqual(after.statements, before.statements)
        XCTAssertEqual(after.auditEntries, before.auditEntries); XCTAssertEqual(after.caseEvaluations, before.caseEvaluations)
        XCTAssertFalse(model.isGeneratingScript)
    }
    @MainActor func testUnknownProviderReferenceShowsErrorWithoutHalfDraft() async throws {
        let (f, store, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: InvalidScriptProvider())
        XCTAssertNil(result); XCTAssertTrue(model.errorMessage?.contains("Snapshot-fremde Fundstelle") == true)
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertTrue(graph.scripts.isEmpty); XCTAssertTrue(graph.statements.isEmpty); XCTAssertTrue(graph.auditEntries.isEmpty)
    }
    @MainActor func testManualDraftUsesSameValidationAndResetsReview() async throws {
        let (f, _, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let invalid = PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0, text: "Synthetic unsupported fact", kind: .fact)])
        XCTAssertNil(model.createManualScript(evaluationID: f.evaluation.id, output: invalid))
        XCTAssertTrue(model.errorMessage?.contains("Tatsachensatz") == true)
        let output = PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0, text: "Synthetic sourced fact", kind: .fact, referencedExcerptKeys: ["EX-1"])])
        let id = try XCTUnwrap(model.createManualScript(evaluationID: f.evaluation.id, output: output))
        let graph = try XCTUnwrap(model.selectedContext), script = try XCTUnwrap(graph.find(id))
        XCTAssertEqual(script.author, .human(f.reviewer.id)); XCTAssertEqual(script.status, .draft)
        XCTAssertTrue(graph.statements.allSatisfy { $0.review == nil })
        XCTAssertNil(model.errorMessage)
    }
    @MainActor func testMissingReviewerDoesNotInvokeProviderOrPersistDraft() async throws {
        let (f, store, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        model.reviewerName = "  "
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: FailingScriptProvider())
        XCTAssertNil(result); XCTAssertTrue(model.errorMessage?.contains("Prüfername") == true)
        XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts.isEmpty)
    }
    @MainActor func testUnreviewedStatementsPreventUIApprovalAndPreserveDraft() async throws {
        let (f, _, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let generatedID = await model.generateScript(evaluationID: f.evaluation.id)
        let id = try XCTUnwrap(generatedID)
        XCTAssertFalse(model.approveScript(id))
        XCTAssertEqual(model.selectedContext?.find(id)?.status, .draft)
        XCTAssertTrue(model.submitScriptForReview(id))
        XCTAssertFalse(model.approveScript(id))
        XCTAssertTrue(model.errorMessage?.contains("jeden einzelnen Satz") == true)
        XCTAssertEqual(model.selectedContext?.find(id)?.status, .needsReview)
    }
    @MainActor func testEvaluationChangedWhileProviderRunsRejectsStaleOutput() async throws {
        let (f, store, model, defaults) = try scriptWorkspace()
        defer { cleanScriptDefaults(defaults) }
        let result = await model.generateScript(evaluationID: f.evaluation.id,
            provider: ReviewingDuringGenerationProvider(store: store, fixture: f))
        XCTAssertNil(result)
        XCTAssertTrue(model.errorMessage?.contains("Bewertung muss erneut geprüft werden") == true)
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertTrue(graph.scripts.isEmpty); XCTAssertTrue(graph.statements.isEmpty)
        XCTAssertEqual(graph.evidenceLinks.count, 2)
        XCTAssertEqual(graph.caseEvaluations[0].status, .reviewRequired)
        XCTAssertEqual(graph.caseEvaluations[0].category, f.evaluation.category)
        XCTAssertEqual(graph.caseEvaluations[0].approval, f.evaluation.approval)
    }
    func testScriptErrorsAreVisibleAndSpecific() {
        for error in [ScriptGenerationError.evaluationUnavailable, .evaluationNotApproved(.reviewRequired), .snapshotUnavailable,
                      .unknownExcerptKey("EX-invented"), .unknownEvidenceKey("EV-invented"), .factWithoutExcerpt,
                      .invalidSnapshot, .inconsistentEvidence("EV-1"), .emptyOutput, .generationInProgress] {
            XCTAssertFalse(WorkspaceErrorMessage.describe(error).isEmpty)
            XCTAssertFalse(WorkspaceErrorMessage.describe(PersistenceError.scriptGeneration(error)).isEmpty)
        }
    }
}
@MainActor private func scriptWorkspace() throws -> (AppWorkspaceFixture, LocalCaseStore, CaseWorkspaceModel, UserDefaults) {
    let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
    var dto = CaseGraphDTO(f.context()); dto.cases[0].workflowState = "approved"
    try store.saveCase(dto.domain())
    let suite = "SyntheticScriptWorkspace-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(suite, forKey: "scriptTestSuite")
    defaults.set(f.reviewer.displayName.value, forKey: "politicalFactCheck.reviewerName")
    defaults.set(f.reviewer.id.rawValue.uuidString, forKey: "politicalFactCheck.reviewerID")
    return (f, store, CaseWorkspaceModel(store: store, defaults: defaults), defaults)
}
private func cleanScriptDefaults(_ defaults: UserDefaults) {
    if let suite = defaults.string(forKey: "scriptTestSuite") { defaults.removePersistentDomain(forName: suite) }
}
private struct FailingScriptProvider: ScriptGenerationProvider {
    var identifier: NonEmptyText { text("synthetic-failing-provider") }
    func generateScript(input: PoliticalFactCheckScripting.ScriptGenerationInput) async throws -> PoliticalFactCheckScripting.ScriptGenerationOutput {
        throw ScriptGenerationError.providerFailure("Synthetic provider failure")
    }
}
private struct InvalidScriptProvider: ScriptGenerationProvider {
    var identifier: NonEmptyText { text("synthetic-invalid-provider") }
    func generateScript(input: PoliticalFactCheckScripting.ScriptGenerationInput) async throws -> PoliticalFactCheckScripting.ScriptGenerationOutput {
        .init(statements: [.init(position: 0, text: "Synthetic invented reference", kind: .fact, referencedExcerptKeys: ["EX-invented"])])
    }
}

private struct ReviewingDuringGenerationProvider: ScriptGenerationProvider {
    let store: LocalCaseStore
    let fixture: AppWorkspaceFixture
    var identifier: NonEmptyText { text("synthetic-stale-output-provider") }
    func generateScript(input: PoliticalFactCheckScripting.ScriptGenerationInput) async throws -> PoliticalFactCheckScripting.ScriptGenerationOutput {
        try await MainActor.run {
            var dto = EvidenceLinkDTO(fixture.evidence)
            dto.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            try store.addVerifiedEvidence(caseID: fixture.politicalCase.id, link: dto.domain(),
                reason: text("Synthetic change while provider is running"), requestedBy: fixture.reviewer.id, at: Date())
        }
        return try await FakeScriptGenerationProvider().generateScript(input: input)
    }
}
