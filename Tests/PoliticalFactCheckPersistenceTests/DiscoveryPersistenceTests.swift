import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence

final class DiscoveryPersistenceTests: XCTestCase {
    let f = StoredDiscoveryFixture()
    @MainActor func imported(_ store: LocalCaseStore, record: DiscoveryCandidateRecord? = nil) throws -> EntityID<PoliticalFactCheckCore.Case> {
        guard case .inserted(let id) = try store.insertDiscoveryCandidate(record ?? f.record()) else { throw DiscoveryError.duplicateSkipped }
        return id
    }
    @MainActor func testAtomicCandidateRoundtripNewStore() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store)
        let before = try XCTUnwrap(store.loadCase(id: id)), reopened = LocalCaseStore(container: store.container)
        let after = try XCTUnwrap(reopened.loadCase(id: id))
        XCTAssertEqual(before.cases, after.cases); XCTAssertEqual(before.promises, after.promises)
        XCTAssertEqual(before.promiseRevisions, after.promiseRevisions); XCTAssertEqual(before.sources, after.sources)
        XCTAssertEqual(before.sourceVersions, after.sourceVersions); XCTAssertEqual(before.excerpts, after.excerpts)
        XCTAssertEqual(before.researchTasks, after.researchTasks); XCTAssertEqual(before.auditEntries, after.auditEntries)
        XCTAssertEqual(try reopened.researchInbox().first?.id, id)
    }
    @MainActor func testInvalidSearchSourceSavesNothing() async throws {
        let store = try LocalCaseStore.inMemory()
        XCTAssertThrowsError(try store.insertDiscoveryCandidate(f.record(validSource: false)))
        XCTAssertTrue(try store.listCases().isEmpty); XCTAssertTrue(try store.researchInbox().isEmpty)
    }
    @MainActor func testWrongDomainSavesNothing() async throws {
        let store = try LocalCaseStore.inMemory()
        XCTAssertThrowsError(try store.insertDiscoveryCandidate(f.record(url: "https://foreign.invalid/promise")))
        XCTAssertTrue(try store.listCases().isEmpty)
    }
    @MainActor func testDuplicateAgainstStoreNotJustCurrentRun() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store)
        let reopened = LocalCaseStore(container: store.container)
        XCTAssertEqual(try reopened.insertDiscoveryCandidate(f.record()), .duplicate)
        XCTAssertEqual(try reopened.listCases().map { $0.id }, [id])
    }
    @MainActor func testCanonicalWhitespaceDuplicate() async throws {
        let store = try LocalCaseStore.inMemory(); _ = try imported(store)
        XCTAssertEqual(try store.insertDiscoveryCandidate(f.record(quote: "Wir  errichten\n drei synthetische Einrichtungen.", url: "HTTPS://SOURCE.INVALID:443/commitment#part")), .duplicate)
    }
    @MainActor func testDifferentQuoteNotMerged() async throws {
        let store = try LocalCaseStore.inMemory(); _ = try imported(store)
        _ = try imported(store, record: f.record(quote: "Wir errichten vier synthetische Einrichtungen."))
        XCTAssertEqual(try store.listCases().count, 2)
    }
    @MainActor func testPreexistingNonInboxCaseDeduplicated() async throws {
        let store = try LocalCaseStore.inMemory(), graph = try DiscoveryCandidateMapper.graph(f.record())
        // Existing case without discovery metadata, e.g. a manually captured original source.
        let existing = DomainContext(cases: graph.cases, actors: graph.actors, promises: graph.promises,
            promiseRevisions: graph.promiseRevisions, sources: graph.sources, sourceVersions: graph.sourceVersions, excerpts: graph.excerpts)
        try store.saveCase(existing)
        XCTAssertTrue(try store.researchInbox().isEmpty)
        XCTAssertEqual(try store.insertDiscoveryCandidate(f.record()), .duplicate)
        XCTAssertEqual(try store.listCases().count, 1)
    }
    @MainActor func testDeleteUsesExistingSafeDraftRules() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store)
        try store.deleteDraftCase(id: id)
        XCTAssertNil(try store.loadCase(id: id)); XCTAssertTrue(try store.researchInbox().isEmpty)
    }
    @MainActor func testAIAndUnreviewedStatusSurviveRoundtrip() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store), g = try XCTUnwrap(store.loadCase(id: id))
        XCTAssertEqual(g.cases[0].workflowState, .candidate); XCTAssertEqual(g.promiseRevisions[0].quote.provenance, .aiExtracted)
        XCTAssertEqual(g.promiseRevisions[0].quote.verification, .unreviewed); XCTAssertEqual(g.excerpts[0].state, .unverified)
        XCTAssertNil(g.excerpts[0].review); XCTAssertNil(g.sourceVersions[0].review); XCTAssertTrue(g.reviewers.isEmpty)
        XCTAssertEqual(g.auditEntries[0].author, g.promiseRevisions[0].metadata.author); XCTAssertNil(g.auditEntries[0].humanRequesterID)
    }
    @MainActor func testTaskSearchMetadataRoundtrip() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store), g = try XCTUnwrap(store.loadCase(id: id))
        XCTAssertEqual(try DiscoveryCandidateRecord.decode(XCTUnwrap(g.researchTasks[0].result)), f.record())
        XCTAssertEqual(g.researchTasks[0].sourceIDs, [g.sources[0].id]); XCTAssertEqual(g.researchTasks[0].excerptIDs, [g.excerpts[0].id])
    }
    @MainActor func testBadCandidateDoesNotDamageExistingCase() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store), before = try XCTUnwrap(store.loadCase(id: id))
        XCTAssertThrowsError(try store.insertDiscoveryCandidate(f.record(quote: " ")))
        let after = try XCTUnwrap(store.loadCase(id: id)); XCTAssertEqual(before.promiseRevisions, after.promiseRevisions)
        XCTAssertEqual(before.auditEntries, after.auditEntries); XCTAssertEqual(try store.listCases().count, 1)
    }
    @MainActor func testNoEvaluationEvidenceOrScriptRecords() async throws {
        let store = try LocalCaseStore.inMemory(), id = try imported(store), g = try XCTUnwrap(store.loadCase(id: id))
        XCTAssertTrue(g.caseEvaluations.isEmpty); XCTAssertTrue(g.evidenceLinks.isEmpty); XCTAssertTrue(g.scripts.isEmpty)
        XCTAssertTrue(g.caseRevisions.isEmpty); XCTAssertTrue(g.criteria.isEmpty)
    }
    @MainActor func testCandidateSurvivesRealStoreReopening() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-discovery-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("discovery.store")
        var first: LocalCaseStore? = try .at(url: url)
        let id = try imported(XCTUnwrap(first))
        let before = try XCTUnwrap(first?.loadCase(id: id)); first = nil
        let reopened = try LocalCaseStore.at(url: url), after = try XCTUnwrap(reopened.loadCase(id: id))
        XCTAssertEqual(before.promiseRevisions, after.promiseRevisions); XCTAssertEqual(before.researchTasks, after.researchTasks)
        XCTAssertEqual(before.auditEntries, after.auditEntries); XCTAssertEqual(try reopened.researchInbox().first?.id, id)
    }

}
