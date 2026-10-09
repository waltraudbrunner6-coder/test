import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence

final class CaseResearchPersistenceTests: XCTestCase {
    @MainActor func testAtomicCompleteDossierAndDraftRoundtrip() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let reopened = LocalCaseStore(container: store.container), g = try XCTUnwrap(reopened.loadCase(id: f.request.caseID))
        XCTAssertEqual(g.cases[0].workflowState, .candidate); XCTAssertEqual(g.criterionRevisions.count, 1); XCTAssertEqual(g.actionRevisions.count, 1); XCTAssertEqual(g.evidenceLinks.count, 1)
        XCTAssertEqual(g.promiseRevisions, f.graph.promiseRevisions); XCTAssertEqual(g.researchTasks[0], f.graph.researchTasks[0])
        let record = try XCTUnwrap(reopened.researchDossier(caseID: f.request.caseID)); XCTAssertEqual(record.result, try f.result())
        XCTAssertEqual(record.bindings?.evidenceLinks["ev1"], g.evidenceLinks[0].id.rawValue)
    }
    @MainActor func testInvalidURLRollsBackEverything() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph)
        let result = try f.result { o in var web = (o["webSources"] as! [[String: Any]])[0]; web["url"] = "https://foreign.invalid/test"; o["webSources"] = [web] }
        XCTAssertThrowsError(try store.saveCaseResearch(f.record(result)))
        let g = try XCTUnwrap(store.loadCase(id: f.request.caseID)); XCTAssertEqual(g.cases, f.graph.cases); XCTAssertEqual(g.sources, f.graph.sources)
        XCTAssertTrue(g.criterionRevisions.isEmpty); XCTAssertTrue(g.evidenceLinks.isEmpty); XCTAssertEqual(g.researchTasks, f.graph.researchTasks); XCTAssertEqual(g.auditEntries, f.graph.auditEntries)
    }
    @MainActor func testUnknownEvidenceReferenceWritesNothing() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph)
        let result = try f.result { o in var a = (o["criterionAssessmentDrafts"] as! [[String: Any]])[0]; a["supportingEvidenceKeys"] = ["unknown"]; o["criterionAssessmentDrafts"] = [a] }
        XCTAssertThrowsError(try store.saveCaseResearch(f.record(result)))
        let g = try XCTUnwrap(store.loadCase(id: f.request.caseID)); XCTAssertEqual(g.researchTasks, f.graph.researchTasks); XCTAssertTrue(g.actions.isEmpty)
    }
    @MainActor func testRepeatedRunSkippedWithoutNewDrafts() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let before = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertThrowsError(try store.caseResearchRequest(caseID: f.request.caseID, policy: f.policy)) { XCTAssertEqual($0 as? CaseResearchError, .alreadyResearched) }
        XCTAssertThrowsError(try store.saveCaseResearch(f.record()))
        let after = try XCTUnwrap(store.loadCase(id: f.request.caseID)); XCTAssertEqual(before.criterionRevisions, after.criterionRevisions); XCTAssertEqual(before.auditEntries, after.auditEntries)
    }
    @MainActor func testDuplicateSourceReusesOriginalIdentity() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let g = try XCTUnwrap(store.loadCase(id: f.request.caseID)), dossier = try XCTUnwrap(store.researchDossier(caseID: f.request.caseID))
        XCTAssertEqual(g.sources.filter { $0.canonicalURL?.absoluteString == f.discovery.candidate.sourceURL }.count, 1)
        XCTAssertEqual(dossier.bindings?.sources["original-source"], f.graph.sources[0].id.rawValue)
        XCTAssertEqual(g.sources.count, 2); XCTAssertEqual(g.sourceVersions.count, 2)
    }
    @MainActor func testNoReviewApprovalEvaluationOrParticipation() async throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let g = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertTrue(g.caseEvaluations.isEmpty); XCTAssertTrue(g.criterionEvaluations.isEmpty); XCTAssertTrue(g.participations.isEmpty); XCTAssertTrue(g.reviewers.isEmpty)
        XCTAssertTrue(g.criterionRevisions.allSatisfy { $0.state == .draft && $0.confirmation == nil }); XCTAssertTrue(g.evidenceLinks.allSatisfy { $0.status == .draft && $0.review == nil })
    }
    @MainActor func testIndependentManualCaseUnchanged() async throws {
        let f = try DeepResearchFixture(), other = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(f.graph); try store.saveCase(other.graph); try store.saveCaseResearch(f.record())
        let g = try XCTUnwrap(store.loadCase(id: other.request.caseID)); XCTAssertEqual(g.cases, other.graph.cases); XCTAssertEqual(g.promiseRevisions, other.graph.promiseRevisions)
        XCTAssertEqual(g.sources, other.graph.sources); XCTAssertEqual(g.auditEntries, other.graph.auditEntries); XCTAssertNil(try store.researchDossier(caseID: other.request.caseID))
    }
    @MainActor func testRealStoreReopenPreservesDossierIDsAndDrafts() async throws {
        let f = try DeepResearchFixture(), directory = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-deep-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("research.store"); var first: LocalCaseStore? = try .at(url: url)
        try first!.saveCase(f.graph); try first!.saveCaseResearch(f.record()); let before = try first!.researchDossier(caseID: f.request.caseID); first = nil
        let reopened = try LocalCaseStore.at(url: url)
        XCTAssertEqual(before, try reopened.researchDossier(caseID: f.request.caseID))
        XCTAssertTrue(DomainValidator.validate(try XCTUnwrap(reopened.loadCase(id: f.request.caseID))).isValid)
    }
}
