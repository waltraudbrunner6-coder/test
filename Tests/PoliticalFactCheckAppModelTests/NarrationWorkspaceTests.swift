import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckAppModel
import PoliticalFactCheckAudio
import PoliticalFactCheckScripting
import PoliticalFactCheckVideoPlanning

final class NarrationWorkspaceTests: XCTestCase {
    @MainActor private func setup() throws -> (AppWorkspaceFixture, LocalCaseStore, CaseWorkspaceModel, UserDefaults, URL) {
        let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(approvedGraph(f))
        let suite = "synthetic-narration-workspace-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defaults.set(suite, forKey: "testSuite")
        defaults.set(f.reviewer.displayName.value, forKey: "politicalFactCheck.reviewerName")
        defaults.set(f.reviewer.id.rawValue.uuidString, forKey: "politicalFactCheck.reviewerID")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = CaseWorkspaceModel(store: store, defaults: defaults, narrationStore: NarrationPackageStore(root: root))
        model.selectCase(f.politicalCase.id)
        return (f, store, model, defaults, root)
    }
    private func cleanup(_ defaults: UserDefaults, _ root: URL) {
        defaults.removePersistentDomain(forName: defaults.string(forKey: "testSuite")!)
        try? FileManager.default.removeItem(at: root)
    }
    @MainActor private func prepare(_ f: AppWorkspaceFixture, _ model: CaseWorkspaceModel) async throws -> EntityID<ScriptDraft> {
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: FakeScriptGenerationProvider())
        let id = try XCTUnwrap(result), plan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertTrue(model.reviewScriptStatements(scriptID: id, selected: Set(plan.statementItems.map { $0.statementID })))
        XCTAssertTrue(model.approveReviewedScript(id, explicitConfirmation: true)); XCTAssertNotNil(model.videoScriptHandoff)
        return id
    }
    private func assertNoTemporaryFiles(_ root: URL) throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".tmp-") })
    }
    @MainActor func testDraftScriptBlocksNarrationAndNeverCallsProvider() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = await model.generateScript(evaluationID: f.evaluation.id, provider: FakeScriptGenerationProvider())
        let provider = WorkspaceNarrationCounter()
        XCTAssertFalse(model.canGenerateNarration)
        let success = await model.generateNarration(provider: provider), calls = await provider.calls()
        XCTAssertFalse(success); XCTAssertEqual(calls, 0); XCTAssertNil(model.narrationPackage)
        XCTAssertEqual(model.narrationErrorMessage, NarrationError.inputUnavailable.displayMessage)
    }
    @MainActor func testReadyForVideoEnablesExplicitGeneration() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        XCTAssertTrue(model.scriptReviewPlan?.readyForVideo == true); XCTAssertTrue(model.canGenerateNarration)
        XCTAssertNil(model.narrationPackage); XCTAssertFalse(model.isPlayingNarration); XCTAssertFalse(model.narrationReadyForRendering)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
    @MainActor func testSuccessShowsMeasuredDurationDisclosureCuesAndDoesNotAutoplay() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let handoff = try XCTUnwrap(model.videoScriptHandoff), before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        let success = await model.generateNarration(provider: FakeNarrationProvider(durationSeconds: 10))
        XCTAssertTrue(success)
        let package = try XCTUnwrap(model.narrationPackage)
        XCTAssertEqual(package.manifest.actualDurationSeconds, Double(handoff.scenes.count) * 10)
        XCTAssertEqual(package.manifest.targetDurationSeconds, 45); XCTAssertFalse(package.manifest.captionCues.isEmpty)
        XCTAssertTrue(package.manifest.requiresAIDisclosure); XCTAssertEqual(package.manifest.disclosureText, "KI-generierte Stimme")
        XCTAssertFalse(model.isPlayingNarration); XCTAssertFalse(model.isGeneratingNarration); XCTAssertNil(model.narrationProgress)
        XCTAssertNil(model.narrationErrorMessage)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.scripts, before.scripts); XCTAssertEqual(after.statements, before.statements)
        XCTAssertEqual(after.caseEvaluations, before.caseEvaluations); XCTAssertEqual(after.auditEntries, before.auditEntries)
    }
    @MainActor func testOutOfRangeAudioIsSavedButNotRenderReady() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let success = await model.generateNarration(provider: FakeNarrationProvider(durationSeconds: 0.5))
        XCTAssertTrue(success); XCTAssertNotNil(model.narrationPackage)
        XCTAssertFalse(model.narrationPackage?.durationWithinPublicationRange == true); XCTAssertFalse(model.narrationReadyForRendering)
    }
    @MainActor func testReopenedWorkspaceLoadsPackageWithoutAnyProviderCall() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let success = await model.generateNarration(provider: FakeNarrationProvider(durationSeconds: 10)); XCTAssertTrue(success)
        let before = try XCTUnwrap(model.narrationPackage)
        let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults,
            narrationStore: NarrationPackageStore(root: root))
        reopened.selectCase(f.politicalCase.id)
        XCTAssertEqual(reopened.narrationPackage, before); XCTAssertNil(reopened.narrationErrorMessage)
        XCTAssertFalse(reopened.isPlayingNarration); XCTAssertFalse(reopened.isGeneratingNarration)
    }
    @MainActor func testExistingAudioRequiresExplicitRegeneration() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let provider = WorkspaceNarrationCounter()
        let first = await model.generateNarration(provider: provider); XCTAssertTrue(first)
        let before = model.narrationPackage, count = await provider.calls()
        let second = await model.generateNarration(provider: provider); XCTAssertFalse(second)
        let unchanged = await provider.calls(); XCTAssertEqual(unchanged, count); XCTAssertEqual(model.narrationPackage, before)
        XCTAssertEqual(model.narrationErrorMessage, NarrationError.alreadyExists.displayMessage)
        let third = await model.generateNarration(provider: provider, regenerate: true); XCTAssertTrue(third)
        let regenerated = await provider.calls(); XCTAssertEqual(regenerated, count * 2)
        XCTAssertNil(model.narrationErrorMessage)
    }
    @MainActor func testMissingKeyIsControlledAndCreatesNoPackage() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let success = await model.generateNarration(provider: OpenAINarrationProvider(environment: { _ in nil }))
        XCTAssertFalse(success); XCTAssertEqual(model.narrationErrorMessage, NarrationError.missingAPIKey.displayMessage)
        XCTAssertNil(model.narrationPackage); try assertNoTemporaryFiles(root)
    }
    @MainActor func testProviderFailureKeepsPreviouslyCompletedPackage() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let first = await model.generateNarration(provider: FakeNarrationProvider(durationSeconds: 10)); XCTAssertTrue(first)
        let old = try XCTUnwrap(model.narrationPackage)
        let second = await model.generateNarration(provider: WorkspaceNarrationFailure(), regenerate: true)
        XCTAssertFalse(second); XCTAssertEqual(model.narrationPackage, old)
        XCTAssertEqual(model.narrationErrorMessage, NarrationError.serviceUnavailable.displayMessage); try assertNoTemporaryFiles(root)
    }
    @MainActor func testProgressDuplicateInvocationAndCancellationAreControlled() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let started = expectation(description: "Offline audio request entered")
        let task = Task { await model.generateNarration(provider: WorkspaceWaitingNarration(started: { started.fulfill() })) }
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(model.isGeneratingNarration); XCTAssertFalse(model.canGenerateNarration)
        XCTAssertEqual(model.narrationProgress, "Szene 1 von \(try XCTUnwrap(model.videoScriptHandoff).scenes.count)")
        let counter = WorkspaceNarrationCounter(), duplicate = await model.generateNarration(provider: counter)
        let calls = await counter.calls(); XCTAssertFalse(duplicate); XCTAssertEqual(calls, 0)
        model.cancelNarration(); let result = await task.value
        XCTAssertFalse(result); XCTAssertFalse(model.isGeneratingNarration); XCTAssertNil(model.narrationProgress)
        XCTAssertEqual(model.narrationErrorMessage, NarrationError.cancelled.displayMessage)
        XCTAssertNil(model.narrationPackage); try assertNoTemporaryFiles(root)
    }
    @MainActor func testReopenRejectsMissingSceneWithoutRepairOrAutogeneration() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let success = await model.generateNarration(provider: FakeNarrationProvider()); XCTAssertTrue(success)
        let package = try XCTUnwrap(model.narrationPackage), scene = package.manifest.scenes[0]
        try FileManager.default.removeItem(at: package.directory.appendingPathComponent(scene.relativeFilename))
        let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults,
            narrationStore: NarrationPackageStore(root: root))
        reopened.selectCase(f.politicalCase.id)
        XCTAssertNil(reopened.narrationPackage); XCTAssertEqual(reopened.narrationErrorMessage, NarrationError.missingScene.displayMessage)
        XCTAssertFalse(reopened.narrationReadyForRendering); XCTAssertFalse(reopened.isGeneratingNarration)
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.directory.appendingPathComponent("manifest.json").path))
    }
    @MainActor func testNewCurrentScriptNeverUsesOldAudioAndRetainsHistoricalFiles() async throws {
        let (f, _, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let success = await model.generateNarration(provider: FakeNarrationProvider()); XCTAssertTrue(success)
        let old = try XCTUnwrap(model.narrationPackage)
        let result = await model.generateScript(evaluationID: f.evaluation.id, provider: FakeScriptGenerationProvider())
        let id = try XCTUnwrap(result), plan = try XCTUnwrap(model.scriptReviewPlan)
        XCTAssertNil(model.narrationPackage); XCTAssertFalse(model.narrationReadyForRendering)
        XCTAssertTrue(model.reviewScriptStatements(scriptID: id, selected: Set(plan.statementItems.map { $0.statementID })))
        XCTAssertTrue(model.approveReviewedScript(id, explicitConfirmation: true))
        XCTAssertNil(model.narrationPackage); XCTAssertTrue(model.canGenerateNarration)
        XCTAssertNotEqual(model.videoScriptHandoff?.scriptID.rawValue, old.manifest.scriptID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.directory.path))
    }
    @MainActor func testReviewRequiredInvalidatesRenderReadinessWithoutDeletingAudio() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let handoff = try XCTUnwrap(model.videoScriptHandoff)
        let duration = 40 / Double(handoff.scenes.count)
        let success = await model.generateNarration(provider: FakeNarrationProvider(durationSeconds: duration)); XCTAssertTrue(success)
        XCTAssertTrue(model.narrationReadyForRendering)
        let old = try XCTUnwrap(model.narrationPackage)
        try addSyntheticReviewEvidence(store, f); model.reload()
        XCTAssertNil(model.videoScriptHandoff); XCTAssertFalse(model.narrationReadyForRendering); XCTAssertFalse(model.canGenerateNarration)
        XCTAssertNil(model.narrationPackage); XCTAssertTrue(FileManager.default.fileExists(atPath: old.directory.path))
        XCTAssertEqual(model.selectedContext?.find(f.evaluation.id)?.status, .reviewRequired)
        XCTAssertEqual(model.selectedContext?.find(f.evaluation.id)?.approval, f.evaluation.approval)
    }
    @MainActor func testEvaluationBecomingReviewRequiredDuringTTSDiscardsStagedAudio() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let handoff = try XCTUnwrap(model.videoScriptHandoff)
        let success = await model.generateNarration(provider: ChangingWorkspaceNarration(change: { try addSyntheticReviewEvidence(store, f) }))
        XCTAssertFalse(success); XCTAssertEqual(model.narrationErrorMessage, NarrationError.staleInput.displayMessage)
        XCTAssertFalse(NarrationPackageStore(root: root).exists(for: handoff)); try assertNoTemporaryFiles(root)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(after.find(f.evaluation.id)?.status, .reviewRequired)
        XCTAssertTrue(after.scripts.allSatisfy { $0.status == .superseded })
        XCTAssertEqual(after.find(f.evaluation.id)?.category, f.evaluation.category)
        XCTAssertEqual(after.find(f.evaluation.id)?.approval, f.evaluation.approval)
    }
    @MainActor func testNewManualScriptDuringTTSDiscardsOldStatementAudio() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let handoff = try XCTUnwrap(model.videoScriptHandoff)
        let success = await model.generateNarration(provider: ChangingWorkspaceNarration(change: {
            _ = try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic manually revised sentence.", kind: .interpretation)]),
                reviewer: f.reviewer, at: Date())
        }))
        XCTAssertFalse(success); XCTAssertEqual(model.narrationErrorMessage, NarrationError.staleInput.displayMessage)
        XCTAssertFalse(NarrationPackageStore(root: root).exists(for: handoff)); try assertNoTemporaryFiles(root)
        XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.scripts.count, 2)
    }
    @MainActor func testGraphChangeOutsideSnapshotDetectedByExistingFullGraphToken() async throws {
        let (f, store, model, defaults, root) = try setup(); defer { cleanup(defaults, root) }
        _ = try await prepare(f, model)
        let handoff = try XCTUnwrap(model.videoScriptHandoff), token = try store.scriptGenerationChangeToken(caseID: f.politicalCase.id)
        let success = await model.generateNarration(provider: ChangingWorkspaceNarration(change: {
            var dto = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            dto.researchTasks.append(ResearchTaskDTO(ResearchTask(caseID: f.politicalCase.id,
                goal: text("Synthetic extra research task, outside the frozen snapshot"), author: .human(f.reviewer.id))))
            try store.saveCase(dto.domain())
        }))
        XCTAssertFalse(success); XCTAssertEqual(model.narrationErrorMessage, NarrationError.staleInput.displayMessage)
        let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertEqual(try VideoScriptHandoffBuilder.build(scriptID: handoff.scriptID, in: after), handoff)
        XCTAssertNotEqual(try store.scriptGenerationChangeToken(caseID: f.politicalCase.id), token)
        XCTAssertFalse(NarrationPackageStore(root: root).exists(for: handoff)); try assertNoTemporaryFiles(root)
    }
}

@MainActor private func addSyntheticReviewEvidence(_ store: LocalCaseStore, _ fixture: AppWorkspaceFixture) throws {
    var dto = EvidenceLinkDTO(fixture.evidence); dto.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
    try store.addVerifiedEvidence(caseID: fixture.politicalCase.id, link: dto.domain(),
        reason: text("Synthetic new evidence while narration is running"), requestedBy: fixture.reviewer.id, at: Date())
}
private actor WorkspaceNarrationCounter: NarrationProvider {
    nonisolated var identifier: NonEmptyText { try! NonEmptyText("synthetic-workspace-narration") }
    nonisolated let model = "synthetic-pcm-wav"
    private var count = 0
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        count += 1; return try await FakeNarrationProvider(durationSeconds: 10).synthesize(request: request)
    }
    func calls() -> Int { count }
}
private struct WorkspaceNarrationFailure: NarrationProvider {
    var identifier: NonEmptyText { text("synthetic-offline-failure") }
    let model = "synthetic-pcm-wav"
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio { throw NarrationError.serviceUnavailable }
}
private struct WorkspaceWaitingNarration: NarrationProvider {
    let started: () -> Void
    var identifier: NonEmptyText { text("synthetic-offline-cancellation") }
    let model = "synthetic-pcm-wav"
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        started(); try await Task.sleep(nanoseconds: 60_000_000_000)
        return try await FakeNarrationProvider().synthesize(request: request)
    }
}
private actor ChangingWorkspaceNarration: NarrationProvider {
    nonisolated var identifier: NonEmptyText { try! NonEmptyText("synthetic-concurrent-case-change") }
    nonisolated let model = "synthetic-pcm-wav"
    private let change: @MainActor () throws -> Void
    private var changed = false
    init(change: @escaping @MainActor () throws -> Void) { self.change = change }
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        if !changed { changed = true; try await change() }
        return try await FakeNarrationProvider().synthesize(request: request)
    }
}
