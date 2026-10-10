import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckScripting

final class ScriptQueuePersistenceTests: XCTestCase {
    @MainActor private func setup() throws -> (PersistenceFixture, LocalCaseStore, ScriptDraft) {
        let f = try PersistenceFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(f.context())
        let script = try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
            output: .init(statements: [
                .init(position: 0, text: "Synthetic fact", kind: .fact, referencedExcerptKeys: ["EX-1"], referencedEvidenceKeys: ["EV-1"]),
                .init(position: 1, text: "Synthetic interpretation", kind: .interpretation),
                .init(position: 2, text: "Synthetic question?", kind: .question)]), reviewer: f.reviewer, at: date(5))
        return (f, store, script)
    }
    private func date(_ day: Double) -> Date { PersistenceFixture.creation.addingTimeInterval(day * 86400) }
    @MainActor private func load(_ f: PersistenceFixture, _ store: LocalCaseStore) throws -> DomainContext {
        try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
    }
    @MainActor private func reviewAll(_ f: PersistenceFixture, _ store: LocalCaseStore, _ script: ScriptDraft) throws {
        try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: Set(script.statementIDs), reviewer: f.reviewer, at: date(6))
    }
    @MainActor func testSelectedSubsetUsesOneReviewerDateAndLeavesOthersUnreviewed() throws {
        let (f, store, script) = try setup(), chosen = Set(script.statementIDs.prefix(2))
        try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: chosen, reviewer: f.reviewer, at: date(6))
        let graph = try load(f, LocalCaseStore(container: store.container))
        for id in chosen { XCTAssertEqual(graph.find(id)?.review, HumanReview(reviewerID: f.reviewer.id, reviewedAt: date(6))) }
        XCTAssertNil(graph.find(script.statementIDs[2])?.review)
        XCTAssertEqual(graph.auditEntries.filter { $0.operation.value == "reviewScriptStatement" }.count, 2)
    }
    @MainActor func testInvalidSelectionRollsBackIncludingNewReviewerAndAudits() throws {
        let (f, store, script) = try setup(), before = try load(f, store)
        XCTAssertThrowsError(try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: [script.statementIDs[0], EntityID<ScriptStatement>()],
            reviewer: ReviewerIdentity(displayName: text("Synthetic other human")), at: date(6)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testEmptySelectionBlocksWithoutWriting() throws {
        let (f, store, script) = try setup(), before = try load(f, store)
        XCTAssertThrowsError(try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: [], reviewer: f.reviewer, at: date(6)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testAlreadyReviewedSentenceKeepsOriginalReviewAndAudit() throws {
        let (f, store, script) = try setup()
        try store.reviewScriptStatement(caseID: f.politicalCase.id, statementID: script.statementIDs[0], reviewer: f.reviewer, at: date(6))
        let old = try XCTUnwrap(load(f, store).find(script.statementIDs[0]))
        try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: Set(script.statementIDs), reviewer: f.reviewer, at: date(7))
        let graph = try load(f, store)
        XCTAssertEqual(graph.find(old.id), old)
        XCTAssertEqual(graph.auditEntries.filter { $0.operation.value == "reviewScriptStatement" }.count, 3)
        XCTAssertEqual(graph.find(script.statementIDs[1])?.review?.reviewedAt, date(7))
    }
    @MainActor func testReviewBeforeScriptCreationBlocksWithRollback() throws {
        let (f, store, script) = try setup(), before = try load(f, store)
        XCTAssertThrowsError(try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: Set(script.statementIDs), reviewer: f.reviewer, at: date(4)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testUnreviewedSentencesBlockFinalApproval() throws {
        let (f, store, script) = try setup(), before = try load(f, store)
        XCTAssertThrowsError(try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(7)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testFalseConfirmationBlocksEvenAfterAllReviews() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        let before = try load(f, store)
        XCTAssertThrowsError(try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: false, reviewer: f.reviewer, at: date(7)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testFinalApprovalPreservesTextsEvaluationAndSnapshotAcrossReload() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        let before = try load(f, store)
        try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(7))
        let after = try load(f, LocalCaseStore(container: store.container)), approved = try XCTUnwrap(after.find(script.id))
        XCTAssertEqual(approved.status, .approved); XCTAssertEqual(approved.approval?.reviewerID, f.reviewer.id)
        XCTAssertEqual(approved.approval?.reviewedAt, date(7)); XCTAssertEqual(after.statements, before.statements)
        XCTAssertEqual(after.caseEvaluations, before.caseEvaluations); XCTAssertEqual(after.caseRevisions, before.caseRevisions)
        XCTAssertTrue(after.auditEntries.contains { $0.operation.value == "submitScriptForReview" })
        XCTAssertTrue(after.auditEntries.contains { $0.operation.value == "approveScript" })
    }
    @MainActor func testNeedsReviewCanBeFinallyApprovedWithoutRepeatedSubmission() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        try store.submitScriptForReview(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: date(7))
        try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(8))
        let graph = try load(f, store)
        XCTAssertEqual(graph.find(script.id)?.status, .approved)
        XCTAssertEqual(graph.auditEntries.filter { $0.operation.value == "submitScriptForReview" }.count, 1)
    }
    @MainActor func testFailureAfterUnsavedCheckpointRollsBackEverything() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        let before = try load(f, store)
        XCTAssertThrowsError(try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(7), beforeFinalWrite: {
                throw PersistenceError.storage(operation: "synthetic-late-fault", detail: "Synthetic offline injected failure")
            }))
        assertGraphsEqual(before, try load(f, LocalCaseStore(container: store.container)))
        XCTAssertEqual(try load(f, store).find(script.id)?.status, .draft)
    }
    @MainActor func testApprovalDateBeforeSentenceReviewsBlocksWithoutChangingDraft() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        let before = try load(f, store)
        XCTAssertThrowsError(try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(5.5)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testNewEvidenceBlocksBulkAndFinalApprovalPreservingHistory() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        var dto = EvidenceLinkDTO(f.evidence); dto.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
        try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: dto.domain(), reason: text("Synthetic new information"),
            requestedBy: f.reviewer.id, at: date(7))
        let before = try load(f, store)
        XCTAssertThrowsError(try store.reviewScriptStatements(caseID: f.politicalCase.id, scriptID: script.id,
            statementIDs: Set(script.statementIDs), reviewer: f.reviewer, at: date(8)))
        XCTAssertThrowsError(try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(8)))
        assertGraphsEqual(before, try load(f, store))
    }
    @MainActor func testApprovedHistoricalVersionSurvivesNewUnreviewedVersion() throws {
        let (f, store, script) = try setup(); try reviewAll(f, store, script)
        try store.approveReviewedScript(caseID: f.politicalCase.id, scriptID: script.id,
            explicitConfirmation: true, reviewer: f.reviewer, at: date(7))
        let old = try XCTUnwrap(load(f, store).find(script.id)), oldStatements = try load(f, store).statements
        let second = try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
            output: .init(statements: [.init(position: 0, text: "Synthetic new interpretation", kind: .interpretation)]),
            reviewer: f.reviewer, at: date(8))
        let graph = try load(f, store), plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertEqual(second.version, 2); XCTAssertEqual(plan.scriptID, second.id); XCTAssertFalse(plan.readyForVideo)
        XCTAssertEqual(graph.find(old.id), old); XCTAssertEqual(old.statementIDs.compactMap { graph.find($0) }, oldStatements)
        XCTAssertTrue(Set(old.statementIDs).isDisjoint(with: second.statementIDs))
        XCTAssertTrue(second.statementIDs.allSatisfy { graph.find($0)?.review == nil })
    }
}
