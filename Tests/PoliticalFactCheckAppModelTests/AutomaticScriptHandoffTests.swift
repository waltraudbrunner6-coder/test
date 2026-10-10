import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckAppModel
import PoliticalFactCheckScripting
import PoliticalFactCheckVideoPlanning

final class AutomaticScriptHandoffTests: XCTestCase {
    @MainActor private func setup() throws -> (AppWorkspaceFixture, LocalCaseStore, CaseWorkspaceModel, UserDefaults) {
        let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
        var dto = CaseGraphDTO(f.context()); dto.cases[0].workflowState = "approved"
        try store.saveCase(dto.domain())
        let suite = "synthetic-script-handoff-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defaults.set(suite, forKey: "testSuite")
        defaults.set(f.reviewer.displayName.value, forKey: "politicalFactCheck.reviewerName")
        defaults.set(f.reviewer.id.rawValue.uuidString, forKey: "politicalFactCheck.reviewerID")
        return (f, store, CaseWorkspaceModel(store: store, defaults: defaults), defaults)
    }
    private func cleanup(_ defaults: UserDefaults) { defaults.removePersistentDomain(forName: defaults.string(forKey: "testSuite")!) }
    @MainActor private func generate(_ f: AppWorkspaceFixture, _ model: CaseWorkspaceModel) async throws -> EntityID<ScriptDraft> {
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: FakeScriptGenerationProvider())
        return try XCTUnwrap(result)
    }
    @MainActor func testApprovedEvaluationFakeGenerationBulkReviewApprovalHandoffAndReload() async throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults) }
        XCTAssertTrue(model.scriptReviewPlan?.generationAvailable == true)
        let id = try await generate(f, model), draftPlan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertEqual(draftPlan.scriptStatus, .draft); XCTAssertEqual(draftPlan.reviewedCount, 0)
        XCTAssertTrue(model.selectedContext?.statements.allSatisfy { $0.review == nil } == true)
        let selected = Set(draftPlan.statementItems.map { $0.statementID })
        XCTAssertTrue(model.reviewScriptStatements(scriptID: id, selected: selected))
        XCTAssertTrue(model.scriptReviewPlan?.readyForApproval == true)
        XCTAssertTrue(model.approveReviewedScript(id, explicitConfirmation: true))
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)), script = try XCTUnwrap(graph.find(id))
        XCTAssertEqual(script.status, .approved); XCTAssertEqual(script.approval?.reviewerID, f.reviewer.id)
        XCTAssertTrue(graph.statements.allSatisfy { $0.review?.reviewerID == f.reviewer.id })
        XCTAssertEqual(graph.find(f.evaluation.id), f.evaluation); XCTAssertEqual(graph.find(f.snapshot.id), f.snapshot)
        let handoff = try XCTUnwrap(model.videoScriptHandoff)
        XCTAssertEqual(handoff.scriptID, id); XCTAssertEqual(handoff.scenes.count, selected.count)
        XCTAssertEqual(handoff.scenes.reduce(0) { $0 + $1.estimatedDurationSeconds }, 45, accuracy: 0.000000001)
        let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
        XCTAssertEqual(reopened.videoScriptHandoff, handoff); XCTAssertNil(model.errorMessage)
    }
    @MainActor func testPreparationResolvesEvaluationLocallyAndDoesNotCreateScript() throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults) }
        let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertTrue(model.prepareCurrentScriptPreview())
        XCTAssertEqual(model.openAITransmissionPreview?.input.evaluation.id, f.evaluation.id)
        XCTAssertEqual(model.openAITransmissionPreview?.input.targetDurationSeconds, 45)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.scripts, before.scripts); XCTAssertEqual(after.auditEntries, before.auditEntries)
        XCTAssertNil(model.videoScriptHandoff)
    }
    @MainActor func testExistingDraftContinuesReviewAndPreventsAutomaticRegeneration() async throws {
        let (f, _, model, defaults) = try setup(); defer { cleanup(defaults) }
        _ = try await generate(f, model)
        XCTAssertFalse(model.prepareCurrentScriptPreview()); XCTAssertFalse(model.prepareCurrentScriptPreview(newVersion: true))
        XCTAssertNil(model.openAITransmissionPreview); XCTAssertFalse(model.scriptReviewPlan?.generationAvailable == true)
    }
    @MainActor func testMissingReviewerBlocksBulkAndApprovalWithoutWriting() async throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults) }
        let id = try await generate(f, model), before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        model.reviewerName = " "
        XCTAssertFalse(model.reviewScriptStatements(scriptID: id, selected: Set(before.statements.map { $0.id })))
        XCTAssertFalse(model.approveReviewedScript(id, explicitConfirmation: true))
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.statements, before.statements); XCTAssertEqual(after.scripts, before.scripts)
        XCTAssertEqual(after.auditEntries, before.auditEntries); XCTAssertEqual(after.reviewers, before.reviewers)
    }
    @MainActor func testExplicitFalseConfirmationDoesNotApprove() async throws {
        let (f, _, model, defaults) = try setup(); defer { cleanup(defaults) }
        let id = try await generate(f, model), plan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertTrue(model.reviewScriptStatements(scriptID: id, selected: Set(plan.statementItems.map { $0.statementID })))
        XCTAssertFalse(model.approveReviewedScript(id, explicitConfirmation: false))
        XCTAssertEqual(model.scriptReviewPlan?.scriptStatus, .draft); XCTAssertNil(model.videoScriptHandoff)
    }
    @MainActor func testSecondExplicitVersionPreservesOldApprovedScriptAndResetsReviews() async throws {
        let (f, _, model, defaults) = try setup(); defer { cleanup(defaults) }
        let first = try await generate(f, model), plan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertTrue(model.reviewScriptStatements(scriptID: first, selected: Set(plan.statementItems.map { $0.statementID })))
        XCTAssertTrue(model.approveReviewedScript(first, explicitConfirmation: true))
        let old = try XCTUnwrap(model.selectedContext?.find(first))
        XCTAssertFalse(model.prepareCurrentScriptPreview()); XCTAssertTrue(model.prepareCurrentScriptPreview(newVersion: true))
        XCTAssertEqual(model.openAITransmissionPreview?.input.evaluation.id, f.evaluation.id)
        model.dismissOpenAIPreview()
        let second = try await generate(f, model), graph = try XCTUnwrap(model.selectedContext), current = try XCTUnwrap(graph.find(second))
        XCTAssertEqual(current.version, 2); XCTAssertNotEqual(first, second); XCTAssertEqual(graph.find(first), old)
        XCTAssertTrue(Set(old.statementIDs).isDisjoint(with: current.statementIDs))
        XCTAssertTrue(current.statementIDs.allSatisfy { graph.find($0)?.review == nil })
        XCTAssertEqual(model.scriptReviewPlan?.scriptID, second); XCTAssertNil(model.videoScriptHandoff)
    }
    @MainActor func testReviewRequiredSupersedesApprovedScriptAndBlocksVideoAndPreview() async throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults) }
        let id = try await generate(f, model), plan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertTrue(model.reviewScriptStatements(scriptID: id, selected: Set(plan.statementItems.map { $0.statementID })))
        XCTAssertTrue(model.approveReviewedScript(id, explicitConfirmation: true))
        let old = try XCTUnwrap(model.selectedContext?.find(id))
        var dto = EvidenceLinkDTO(f.evidence); dto.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
        try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: dto.domain(), reason: text("Synthetic new information"),
            requestedBy: f.reviewer.id, at: Date())
        model.reload()
        XCTAssertNil(model.videoScriptHandoff); XCTAssertFalse(model.prepareCurrentScriptPreview())
        let historical = try XCTUnwrap(model.selectedContext?.find(id))
        XCTAssertEqual(historical.status, .superseded); XCTAssertEqual(historical.approval, old.approval)
        XCTAssertEqual(historical.statementIDs, old.statementIDs); XCTAssertEqual(model.selectedCase?.workflowState, .approved)
    }
    @MainActor func testConcurrentGraphChangeOutsideSnapshotRejectsFakeProviderResult() async throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults) }
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: ConcurrentScriptProvider(store: store, fixture: f))
        XCTAssertNil(result); XCTAssertNotNil(model.errorMessage)
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(graph.scripts.count, 1); XCTAssertEqual(graph.statements.count, 1)
        XCTAssertEqual(graph.statements[0].text.value, "Synthetic concurrent manual edit")
        XCTAssertEqual(graph.find(f.evaluation.id), f.evaluation); XCTAssertEqual(graph.find(f.snapshot.id), f.snapshot)
    }
    @MainActor func testOpenAIResponseCannotSaveAfterGraphChangeDuringTransmission() async throws {
        let (f, store, model, defaults) = try setup(); defer { cleanup(defaults); HandoffHTTPStub.reset() }
        let started = expectation(description: "Synthetic HTTP request started")
        HandoffHTTPStub.started = { started.fulfill() }
        let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [HandoffHTTPStub.self]
        let provider = OpenAIScriptGenerationProvider(session: URLSession(configuration: configuration),
            safetyIdentifier: "CD0DC2A3-B72F-4C47-89C5-2A3E43176999", environment: { _ in "test-key-not-real" })
        XCTAssertTrue(model.prepareCurrentScriptPreview())
        let task = Task { await model.sendOpenAIScript(provider: provider) }
        await fulfillment(of: [started], timeout: 5)
        _ = try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
            output: .init(statements: [.init(position: 0, text: "Synthetic concurrent manual edit", kind: .interpretation)]),
            reviewer: f.reviewer, at: Date())
        let beforeResponse = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        HandoffHTTPStub.release()
        let result = await task.value
        XCTAssertNil(result); XCTAssertNil(model.openAITransmissionPreview)
        XCTAssertTrue(model.errorMessage?.contains("Vorschau") == true)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.scripts, beforeResponse.scripts); XCTAssertEqual(after.statements, beforeResponse.statements)
        XCTAssertEqual(after.auditEntries, beforeResponse.auditEntries); XCTAssertEqual(after.caseEvaluations, beforeResponse.caseEvaluations)
    }
    @MainActor func testResearchReviewApprovalImmediatelyEnablesLocalScriptPreview() throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let suite = "synthetic-research-to-script-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = CaseWorkspaceModel(store: store, defaults: defaults); model.selectCase(f.request.caseID)
        model.reviewerName = "Synthetic human editor"
        XCTAssertTrue(model.performResearchReview(.excerpt(try XCTUnwrap(model.researchReviewPlan?.originalExcerptID), reject: false)))
        XCTAssertTrue(model.performResearchReview(.original))
        XCTAssertTrue(model.performResearchReview(.criterion("criterion-1", use: true)))
        XCTAssertTrue(model.performResearchReview(.frame("Synthetic human reviewed context")))
        XCTAssertTrue(model.performResearchReview(.assessment(acknowledgeOmittedCounterEvidence: false)))
        let evaluation = try XCTUnwrap(model.selectedContext?.caseEvaluations.first)
        XCTAssertTrue(model.performResearchReview(.approval(evaluation.id, checked: Set(evaluation.criterionEvaluationIDs),
            confirmation: true, acknowledgeOmittedCounterEvidence: false)))
        XCTAssertTrue(model.scriptReviewPlan?.generationAvailable == true)
        XCTAssertTrue(model.prepareCurrentScriptPreview())
        XCTAssertEqual(model.openAITransmissionPreview?.input.evaluation.id, evaluation.id)
        XCTAssertTrue(model.selectedContext?.scripts.isEmpty == true)
    }
}

private struct ConcurrentScriptProvider: ScriptGenerationProvider {
    let store: LocalCaseStore
    let fixture: AppWorkspaceFixture
    var identifier: NonEmptyText { text("synthetic-concurrent-provider") }
    func generateScript(input: PoliticalFactCheckScripting.ScriptGenerationInput) async throws -> PoliticalFactCheckScripting.ScriptGenerationOutput {
        try await MainActor.run {
            _ = try store.saveManualScriptDraft(caseID: fixture.politicalCase.id, evaluationID: fixture.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic concurrent manual edit", kind: .interpretation)]),
                reviewer: fixture.reviewer, at: Date())
        }
        return try await FakeScriptGenerationProvider().generateScript(input: input)
    }
}

/// Suspends an entirely offline response so the test can change the local graph first.
private final class HandoffHTTPStub: URLProtocol {
    static var started: (() -> Void)?
    private static let lock = NSLock()
    private static var pending: HandoffHTTPStub?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.pending = self; Self.lock.unlock()
        Self.started?()
    }
    static func reset() { lock.lock(); pending = nil; started = nil; lock.unlock() }
    static func release() {
        lock.lock(); let instance = pending; pending = nil; lock.unlock()
        instance?.finish()
    }
    private func finish() {
        let output: [String: Any] = ["statements": [["position": 0, "text": "Synthetic generated sourced fact", "kind": "fact",
            "referencedExcerptKeys": ["EX-1"], "referencedEvidenceKeys": ["EV-1"], "uncertainty": NSNull()]]]
        let text = String(data: try! JSONSerialization.data(withJSONObject: output), encoding: .utf8)!
        let body = try! JSONSerialization.data(withJSONObject: ["status": "completed", "output": [["type": "message", "role": "assistant", "status": "completed",
            "content": [["type": "output_text", "text": text]]]]])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
