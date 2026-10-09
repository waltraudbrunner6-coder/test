import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

private struct SyntheticCaseResearchProvider: CaseResearchProvider {
    let identifier = try! NonEmptyText("synthetic-research-model")
    var failureForID: EntityID<PoliticalFactCheckCore.Case>? = nil
    var delay: UInt64 = 0
    var delayForID: EntityID<PoliticalFactCheckCore.Case>? = nil
    func researchCase(request: CaseResearchRequest) async throws -> CaseResearchResult {
        await request.onProgress?(.support, "criterion-1")
        if delay > 0 && (delayForID == nil || delayForID == request.caseID) { try await Task.sleep(nanoseconds: delay) }
        if request.caseID == failureForID { throw DiscoveryError.rateLimited }
        return try DeepResearchFixture().result(for: request)
    }
}
final class CaseResearchWorkspaceTests: XCTestCase {
    @MainActor func workspace(_ store: LocalCaseStore) -> CaseWorkspaceModel { CaseWorkspaceModel(store: store, defaults: UserDefaults(suiteName: "synthetic-deep-" + UUID().uuidString)!) }
    @MainActor func testSingleCandidateAndDossierReloadNavigation() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); let model = workspace(store)
        await model.researchCandidates(ids: [f.request.caseID], provider: SyntheticCaseResearchProvider(), policy: f.policy, currentDate: f.now)
        XCTAssertNotNil(model.researchDossiers[f.request.caseID]); XCTAssertEqual(model.selectedCaseID, f.request.caseID)
        XCTAssertEqual(model.selectedContext?.cases.first?.workflowState, .candidate)
        let reopened = workspace(LocalCaseStore(container: store.container)); XCTAssertEqual(reopened.researchDossiers, model.researchDossiers)
        let source = try XCTUnwrap(model.researchDossiers[f.request.caseID]?.result.sources.first)
        XCTAssertNotNil(URL(string: source.searchSource.url)); XCTAssertEqual(model.researchDossiers[f.request.caseID]?.result.overallAssessmentDraft.suggestedCategory, .notVerifiable)
    }
    @MainActor func testAllCandidatesSeriallyDeepened() async throws {
        let a = try DeepResearchFixture(), b = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(a.graph); try store.saveCase(b.graph)
        let model = workspace(store); XCTAssertEqual(model.pendingResearchCount, 2)
        await model.researchCandidates(provider: SyntheticCaseResearchProvider(), policy: a.policy, currentDate: a.now)
        XCTAssertEqual(model.researchDossiers.count, 2); XCTAssertEqual(model.pendingResearchCount, 0); XCTAssertFalse(model.isResearchingCases)
    }
    @MainActor func testAlreadyDeepenedCandidateSkipped() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let before = try XCTUnwrap(store.loadCase(id: f.request.caseID)), model = workspace(store)
        await model.researchCandidates(provider: SyntheticCaseResearchProvider(), policy: f.policy, currentDate: f.now)
        XCTAssertTrue(model.researchMessage?.contains("1 bereits vertieft recherchiert") == true)
        let after = try XCTUnwrap(store.loadCase(id: f.request.caseID)); XCTAssertEqual(before.auditEntries, after.auditEntries); XCTAssertEqual(before.evidenceLinks, after.evidenceLinks)
    }
    @MainActor func testOneCandidateFailureDoesNotBlockOther() async throws {
        let a = try DeepResearchFixture(), b = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(a.graph); try store.saveCase(b.graph)
        let model = workspace(store)
        await model.researchCandidates(ids: [a.request.caseID, b.request.caseID], provider: SyntheticCaseResearchProvider(failureForID: a.request.caseID), policy: a.policy, currentDate: a.now)
        XCTAssertNil(model.researchDossiers[a.request.caseID]); XCTAssertNotNil(model.researchDossiers[b.request.caseID])
        XCTAssertNotNil(model.researchErrorMessage); XCTAssertEqual(try store.loadCase(id: a.request.caseID)?.auditEntries, a.graph.auditEntries)
    }
    @MainActor func testProgressAndCancellationDiscardPendingCandidate() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); let model = workspace(store)
        let task = Task { await model.researchCandidates(provider: SyntheticCaseResearchProvider(delay: 1_000_000_000), policy: f.policy, currentDate: f.now) }
        while model.researchProgress?.contains("SUPPORT") != true { await Task.yield() }
        XCTAssertTrue(model.isResearchingCases); XCTAssertTrue(model.researchProgress?.contains("Kandidat 1 von 1") == true)
        model.cancelCaseResearch(); await task.value
        XCTAssertFalse(model.isResearchingCases); XCTAssertTrue(model.researchDossiers.isEmpty)
        XCTAssertEqual(try store.loadCase(id: f.request.caseID)?.researchTasks, f.graph.researchTasks)
    }
    @MainActor func testCancellationKeepsEarlierCompletedDossier() async throws {
        let a = try DeepResearchFixture(), b = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(a.graph); try store.saveCase(b.graph)
        let model = workspace(store)
        let task = Task { await model.researchCandidates(ids: [a.request.caseID, b.request.caseID], provider: SyntheticCaseResearchProvider(delay: 1_000_000_000, delayForID: b.request.caseID), policy: a.policy, currentDate: a.now) }
        while model.researchProgress?.contains("Kandidat 2 von 2 · SUPPORT") != true { await Task.yield() }
        model.cancelCaseResearch(); await task.value
        XCTAssertNotNil(model.researchDossiers[a.request.caseID]); XCTAssertNil(model.researchDossiers[b.request.caseID])
    }
    @MainActor func testManualNavigationAndSourceEntryRemainUsableWhileResearching() async throws {
        let a = try DeepResearchFixture(), b = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(a.graph); try store.saveCase(b.graph)
        let model = workspace(store)
        let task = Task { await model.researchCandidates(ids: [a.request.caseID], provider: SyntheticCaseResearchProvider(delay: 1_000_000_000), policy: a.policy, currentDate: a.now) }
        while model.researchProgress?.contains("SUPPORT") != true { await Task.yield() }
        model.selectCase(b.request.caseID); XCTAssertEqual(model.selectedContext?.cases.first?.id, b.request.caseID)
        model.cancelCaseResearch(); await task.value; XCTAssertEqual(model.selectedCaseID, b.request.caseID)
    }
    @MainActor func testProviderErrorWritesNoDraftsAndReleasesBusyState() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); let model = workspace(store)
        await model.researchCandidates(provider: SyntheticCaseResearchProvider(failureForID: f.request.caseID), policy: f.policy, currentDate: f.now)
        let g = try XCTUnwrap(store.loadCase(id: f.request.caseID)); XCTAssertEqual(g.researchTasks, f.graph.researchTasks); XCTAssertTrue(g.criteria.isEmpty)
        XCTAssertTrue(g.actions.isEmpty); XCTAssertTrue(g.evidenceLinks.isEmpty); XCTAssertFalse(model.isResearchingCases)
    }
    @MainActor func testGenuineManualCaseAndHumanAuditsUnchanged() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph)
        let model = workspace(store); model.reviewerName = "Synthetischer Mensch"
        let manualID = try XCTUnwrap(model.createDraftCase(title: "Synthetischer manueller Fall", quote: "Manuelles synthetisches Versprechen",
            thesis: "Synthetische Prüfung", speakerName: "Synthetische manuelle Person", partyName: "Synthetische manuelle Gruppe", statementDate: nil))
        let before = try XCTUnwrap(store.loadCase(id: manualID))
        await model.researchCandidates(ids: [f.request.caseID], provider: SyntheticCaseResearchProvider(), policy: f.policy, currentDate: f.now)
        let after = try XCTUnwrap(store.loadCase(id: manualID))
        XCTAssertEqual(before.promiseRevisions, after.promiseRevisions); XCTAssertEqual(before.auditEntries, after.auditEntries)
        XCTAssertEqual(before.reviewers, after.reviewers); XCTAssertEqual(before.cases, after.cases)
        XCTAssertEqual(after.promiseRevisions[0].quote.provenance, .humanEntered)
    }

}
