import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

private struct SyntheticDiscoveryProvider: PromiseDiscoveryProvider {
    let identifier = try! NonEmptyText("synthetic-test-model")
    let result: PromiseDiscoveryResult
    var failure: DiscoveryError? = nil
    var delay: UInt64 = 0
    func discoverPromises(request: PromiseDiscoveryRequest) async throws -> PromiseDiscoveryResult {
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        if let failure { throw failure }
        return result
    }
}
final class DiscoveryWorkspaceTests: XCTestCase {
    let f = StoredDiscoveryFixture()
    @MainActor func model(_ store: LocalCaseStore) -> CaseWorkspaceModel {
        CaseWorkspaceModel(store: store, defaults: UserDefaults(suiteName: "discovery-test-" + UUID().uuidString)!)
    }
    @MainActor func scan(_ workspace: CaseWorkspaceModel, result: PromiseDiscoveryResult? = nil) async {
        await workspace.discoverPromises(provider: SyntheticDiscoveryProvider(result: result ?? f.result), policy: f.policy, currentDate: f.now)
    }
    @MainActor func testNoReviewerOrSearchInputRequired() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store)
        XCTAssertEqual(workspace.reviewerName, ""); await scan(workspace)
        XCTAssertEqual(workspace.cases.count, 1); XCTAssertEqual(workspace.researchInbox.count, 1)
        XCTAssertEqual(workspace.cases[0].workflowState, .candidate); XCTAssertFalse(workspace.isDiscoveringPromises)
    }
    @MainActor func testInboxSurvivesNewWorkspace() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace)
        let reopened = model(LocalCaseStore(container: store.container))
        XCTAssertEqual(reopened.researchInbox, workspace.researchInbox); XCTAssertEqual(reopened.cases.map { $0.id }, workspace.cases.map { $0.id })
    }
    @MainActor func testOpenCandidateUsesExistingCaseWorkflow() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace)
        let id = try XCTUnwrap(workspace.researchInbox.first?.id); workspace.selectCase(id)
        XCTAssertEqual(workspace.selectedContext?.cases.first?.id, id)
        XCTAssertEqual(workspace.selectedContext?.excerpts.first?.state, .unverified)
    }
    @MainActor func testDiscardRemovesCandidateThroughSafeDelete() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace)
        let id = try XCTUnwrap(workspace.researchInbox.first?.id); workspace.discardDiscoveryCandidate(id: id)
        XCTAssertTrue(workspace.researchInbox.isEmpty); XCTAssertNil(try store.loadCase(id: id))
    }
    @MainActor func testRepeatedScanSkipsPersistedDuplicate() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace); await scan(workspace)
        XCTAssertEqual(workspace.cases.count, 1); XCTAssertTrue(workspace.discoveryMessage?.contains("1 Duplikate") == true)
    }
    @MainActor func testZeroCandidatesNoFakeCase() async throws {
        let workspace = model(try LocalCaseStore.inMemory())
        await scan(workspace, result: PromiseDiscoveryResult(outcomes: [DiscoveryGroupOutcome(group: f.group, candidates: [])]))
        XCTAssertTrue(workspace.cases.isEmpty); XCTAssertTrue(workspace.researchInbox.isEmpty); XCTAssertNotNil(workspace.discoveryMessage)
    }
    @MainActor func testProviderFailureKeepsExistingData() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace)
        let ids = workspace.cases.map { $0.id }
        await workspace.discoverPromises(provider: SyntheticDiscoveryProvider(result: f.result, failure: .missingAPIKey), policy: f.policy, currentDate: f.now)
        XCTAssertEqual(workspace.cases.map { $0.id }, ids); XCTAssertEqual(workspace.discoveryErrorMessage, DiscoveryError.missingAPIKey.displayMessage)
        XCTAssertFalse(workspace.isDiscoveringPromises)
    }
    @MainActor func testValidCandidateKeptAndInvalidCandidateRejected() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store), invalid = f.record(url: "https://foreign.invalid/promise")
        let foreign = ResearchWebSource(key: "WEB-2", url: invalid.candidate.sourceURL, title: nil, domain: "foreign.invalid",
            researchTimestamp: f.now, policyVersion: f.policy.version, category: nil, fromSearch: true, cited: false)
        let result = PromiseDiscoveryResult(outcomes: [DiscoveryGroupOutcome(group: f.group,
            candidates: [f.record().candidate, invalid.candidate], sources: f.record().sources + [foreign])])
        await scan(workspace, result: result)
        XCTAssertEqual(workspace.cases.count, 1); XCTAssertNotNil(workspace.discoveryErrorMessage)
    }
    @MainActor func testGroupFailureDoesNotDiscardOtherGroupCandidates() async throws {
        let workspace = model(try LocalCaseStore.inMemory())
        let failedGroup = ResearchSourceGroup(id: "other", label: "Synthetische zweite Gruppe", domains: [PolicyDomain(host: "other.invalid", category: .officialParty)])
        let policy = SourcePolicy(version: f.policy.version, groups: [f.group, failedGroup])
        let result = PromiseDiscoveryResult(outcomes: [f.result.outcomes[0], DiscoveryGroupOutcome(group: failedGroup, candidates: [], error: .rateLimited, searched: false)])
        await workspace.discoverPromises(provider: SyntheticDiscoveryProvider(result: result), policy: policy, currentDate: f.now)
        XCTAssertEqual(workspace.cases.count, 1); XCTAssertTrue(workspace.discoveryErrorMessage?.contains(DiscoveryError.rateLimited.displayMessage) == true)
    }
    @MainActor func testBusyRejectsDoubleScanWithoutDuplicateWrites() async throws {
        let workspace = model(try LocalCaseStore.inMemory())
        let first = Task { await workspace.discoverPromises(provider: SyntheticDiscoveryProvider(result: f.result, delay: 100_000_000), policy: f.policy, currentDate: f.now) }
        while !workspace.isDiscoveringPromises { await Task.yield() }
        XCTAssertTrue(workspace.isDiscoveringPromises)
        await scan(workspace)
        await first.value
        XCTAssertEqual(workspace.cases.count, 1)
    }
    @MainActor func testCancellationDoesNotImportPendingBatch() async throws {
        let workspace = model(try LocalCaseStore.inMemory())
        let first = Task { await workspace.discoverPromises(provider: SyntheticDiscoveryProvider(result: f.result, delay: 1_000_000_000), policy: f.policy, currentDate: f.now) }
        while !workspace.isDiscoveringPromises { await Task.yield() }
        workspace.cancelDiscovery(); await first.value
        XCTAssertTrue(workspace.cases.isEmpty); XCTAssertFalse(workspace.isDiscoveringPromises)
        XCTAssertTrue(workspace.discoveryMessage?.contains("abgebrochen") == true)
    }
    @MainActor func testNoEvaluationScriptOrHumanReviewCreated() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store); await scan(workspace)
        let graph = try XCTUnwrap(workspace.selectedContext)
        XCTAssertTrue(graph.caseEvaluations.isEmpty); XCTAssertTrue(graph.scripts.isEmpty); XCTAssertTrue(graph.evidenceLinks.isEmpty)
        XCTAssertTrue(graph.reviewers.isEmpty); XCTAssertEqual(graph.promiseRevisions[0].quote.verification, .unreviewed)
    }
    @MainActor func testExistingManualCasePreservedExactly() async throws {
        let store = try LocalCaseStore.inMemory(), workspace = model(store)
        workspace.reviewerName = "Synthetischer menschlicher Prüfer"
        let id = try XCTUnwrap(workspace.createDraftCase(title: "Manueller synthetischer Fall", quote: "Synthetisches manuelles Versprechen",
            thesis: "Synthetisch prüfen", speakerName: "Manuelle Person", partyName: "Manuelle Gruppe", statementDate: nil))
        let before = try XCTUnwrap(store.loadCase(id: id)); await scan(workspace)
        let after = try XCTUnwrap(store.loadCase(id: id))
        XCTAssertEqual(before.cases, after.cases); XCTAssertEqual(before.promiseRevisions, after.promiseRevisions)
        XCTAssertEqual(before.reviewers, after.reviewers); XCTAssertEqual(before.auditEntries, after.auditEntries)
        XCTAssertEqual(workspace.cases.count, 2)
    }

}
