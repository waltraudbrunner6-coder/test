import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class ReadinessTransactionTests: XCTestCase {
    func testPromiseAndCriteriaRevisionHistorySurvivesDiskStoreReopen() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let url = folder.appendingPathComponent("Readiness.store")
            let f = try PersistenceFixture()
            let original = try readinessInput(f)
            var expected: DomainContext?
            do {
                let store = try LocalCaseStore.at(url: url)
                try store.saveCase(original)
                try confirmFrame(store, f)
                expected = try store.loadCase(id: f.politicalCase.id)
            }
            let reopened = try LocalCaseStore.at(url: url)
            let loaded = try XCTUnwrap(reopened.loadCase(id: f.politicalCase.id))
            assertGraphsEqual(try XCTUnwrap(expected), loaded)
            XCTAssertEqual(loaded.promiseRevisions[0], original.promiseRevisions[0])
            XCTAssertEqual(loaded.criterionRevisions[0], original.criterionRevisions[0])
            let latest = try XCTUnwrap(loaded.find(loaded.cases[0].currentPromiseRevisionID))
            XCTAssertEqual(latest.context.verification, .verified)
            XCTAssertEqual(latest.speaker.verification, .verified)
            XCTAssertEqual(latest.quote, original.promiseRevisions[0].quote)
            XCTAssertEqual(latest.party, original.promiseRevisions[0].party)
            XCTAssertEqual(latest.party.verification, .unreviewed)
            XCTAssertEqual(loaded.promiseRevisions.count, 2)
            XCTAssertEqual(loaded.criterionRevisions.count, 2)
            XCTAssertEqual(loaded.criterionRevisions[1].state, .draft)
            XCTAssertNil(loaded.criterionRevisions[1].confirmation)
            XCTAssertEqual(loaded.criterionRevisions[1].promiseRevisionID, latest.id)
            XCTAssertEqual(loaded.criteria[0].currentRevisionID, loaded.criterionRevisions[1].id)
            XCTAssertEqual(loaded.cases[0].activeCriterionRevisionIDs, [loaded.criterionRevisions[1].id])
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
            XCTAssertTrue(loaded.criterionEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.methodologies.isEmpty)
        }
    }

    func testDraftAndConfirmedCriteriaAreBothReboundAsNewDrafts() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(try readinessInput(f))
            let criterionID = EntityID<EvaluationCriterion>()
            let draft = CriterionRevision(criterionID: criterionID, promiseRevisionID: f.promiseRevision.id,
                goal: text("Synthetic second goal"), targetGroup: text("Synthetic second group"),
                baseline: f.criterionRevision.baseline, deadline: f.criterionRevision.deadline,
                conditions: f.criterionRevision.conditions, isCore: false, materialityRule: text("Synthetic secondary condition"),
                metadata: f.criterionRevision.metadata)
            dto.criteria.append(EvaluationCriterionDTO(EvaluationCriterion(id: criterionID, promiseID: f.promise.id, currentRevisionID: draft.id)))
            dto.criterionRevisions.append(CriterionRevisionDTO(draft))
            dto.cases[0].activeCriterionRevisionIDs.append(StoredID(draft.id, kind: "CriterionRevision"))
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(dto.domain())
            try confirmFrame(store, f)
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.criterionRevisions.count, 4)
            XCTAssertEqual(loaded.find(f.criterionRevision.id), f.criterionRevision)
            XCTAssertEqual(loaded.find(draft.id), draft)
            for id in loaded.cases[0].activeCriterionRevisionIDs {
                let revision = try XCTUnwrap(loaded.find(id))
                XCTAssertEqual(revision.state, .draft)
                XCTAssertNil(revision.confirmation)
                XCTAssertEqual(revision.metadata.number, 2)
                XCTAssertEqual(revision.promiseRevisionID, loaded.cases[0].currentPromiseRevisionID)
                XCTAssertEqual(loaded.find(revision.criterionID)?.currentRevisionID, revision.id)
            }
            XCTAssertEqual(loaded.cases[0].activeCriterionRevisionIDs.count, 2)
        }
    }

    func testReadinessTransitionsPersistOnlyAfterNewCriterionHumanConfirmation() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(readinessInput(f))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .verified, reviewer: f.reviewer, at: readinessTime))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            try confirmFrame(store, f)
            try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .verified, reviewer: f.reviewer, at: readinessTime)
            let verified = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .readyForEvaluation, reviewer: f.reviewer, at: readinessTime))
            assertGraphsEqual(verified, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            let revision = try XCTUnwrap(verified.find(verified.cases[0].activeCriterionRevisionIDs[0]))
            let confirmed = try DomainChanges.transition(revision, to: .confirmed,
                review: HumanReview(reviewerID: f.reviewer.id, reviewedAt: readinessTime), in: verified)
            var dto = CaseGraphDTO(verified)
            dto.criterionRevisions[dto.criterionRevisions.firstIndex { $0.id.value == revision.id.rawValue }!] = CriterionRevisionDTO(confirmed)
            try store.saveCase(dto.domain())
            try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .readyForEvaluation, reviewer: f.reviewer, at: readinessTime)
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.cases[0].workflowState, .readyForEvaluation)
            XCTAssertEqual(loaded.find(revision.id)?.confirmation?.reviewerID, f.reviewer.id)
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
            XCTAssertTrue(loaded.criterionEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.methodologies.isEmpty)
        }
    }

    func testUnverifiedExcerptRejectedAtomicallyIncludingNewReviewerAndAudit() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(try readinessInput(f))
            let excerpt = SourceExcerpt(sourceVersionID: f.sourceVersion.id, locator: text("Synthetic unverified locator"),
                text: text("Synthetic context"), context: text("Synthetic context"), language: text("en"))
            dto.excerpts.append(SourceExcerptDTO(excerpt))
            let original = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            let another = ReviewerIdentity(displayName: text("Synthetic additional reviewer"))
            XCTAssertThrowsError(try store.verifyPromiseForEvaluationReadiness(caseID: f.politicalCase.id,
                contextText: text("Synthetic context"), contextExcerptIDs: [excerpt.id], speakerExcerptIDs: [f.excerpt.id], reviewer: another, at: readinessTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            XCTAssertThrowsError(try store.verifyPromiseForEvaluationReadiness(caseID: f.politicalCase.id,
                contextText: text("Synthetic context"), contextExcerptIDs: [f.excerpt.id], speakerExcerptIDs: [excerpt.id], reviewer: another, at: readinessTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testMissingOrForeignExcerptCannotBeUsed() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let other = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            let original = try readinessInput(f)
            try store.saveCase(original)
            try store.saveCase(readinessInput(other))
            for id in [EntityID<SourceExcerpt>(), other.excerpt.id] {
                XCTAssertThrowsError(try store.verifyPromiseForEvaluationReadiness(caseID: f.politicalCase.id,
                    contextText: text("Synthetic context"), contextExcerptIDs: [id], speakerExcerptIDs: [f.excerpt.id], reviewer: f.reviewer, at: readinessTime))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testExistingSnapshotOrEvaluationPreventsRebindingWithoutMutation() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            let original = try approvedGraph(f)
            try store.saveCase(original)
            XCTAssertThrowsError(try confirmFrame(store, f)) { error in
                XCTAssertEqual(error as? PersistenceError, .invalidDomain([.historicalReadinessChangeDenied]))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            var dto = CaseGraphDTO(original)
            dto.cases[0].workflowState = "documented"
            dto.caseEvaluations = []; dto.criterionEvaluations = []
            let snapshotOnlyStore = try LocalCaseStore.inMemory()
            let snapshotOnly = try dto.domain()
            try snapshotOnlyStore.saveCase(snapshotOnly)
            XCTAssertThrowsError(try confirmFrame(snapshotOnlyStore, f))
            assertGraphsEqual(snapshotOnly, try XCTUnwrap(snapshotOnlyStore.loadCase(id: f.politicalCase.id)))
        }
    }

    func testReadinessAuditRecordsPromiseContextSpeakerAndEveryReboundCriterion() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(readinessInput(f))
            try confirmFrame(store, f)
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.auditEntries.map { $0.operation.value }, ["verifyPromiseForReadiness", "verifyPromiseContext", "verifyPromiseSpeaker", "rebindCriterionToPromise"])
            XCTAssertTrue(loaded.auditEntries.allSatisfy { $0.author == .human(f.reviewer.id) && $0.humanRequesterID == f.reviewer.id })
            XCTAssertTrue(loaded.auditEntries.allSatisfy { $0.before != nil && $0.after != nil })
            XCTAssertEqual(loaded.evidenceLinks[0], f.evidence)
            XCTAssertEqual(loaded.evidenceLinks[0].criterionRevisionID, f.criterionRevision.id)
            XCTAssertNotEqual(loaded.evidenceLinks[0].criterionRevisionID, loaded.cases[0].activeCriterionRevisionIDs[0])
        }
    }

    func testReadinessOperationCannotSkipWorkflowOrCreateEvaluation() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            let original = try readinessInput(f)
            try store.saveCase(original)
            XCTAssertThrowsError(try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .readyForEvaluation, reviewer: f.reviewer, at: readinessTime))
            XCTAssertThrowsError(try store.advanceEvaluationReadiness(caseID: f.politicalCase.id, to: .evaluated, reviewer: f.reviewer, at: readinessTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
}

private var readinessTime: Date { PersistenceFixture.creation.addingTimeInterval(5 * 86_400) }
@MainActor
private func confirmFrame(_ store: LocalCaseStore, _ f: PersistenceFixture) throws {
    try store.verifyPromiseForEvaluationReadiness(caseID: f.politicalCase.id, contextText: text("Synthetic verified context"),
        contextExcerptIDs: [f.excerpt.id], speakerExcerptIDs: [f.excerpt.id], reviewer: f.reviewer, at: readinessTime)
}
private func readinessInput(_ f: PersistenceFixture) throws -> DomainContext {
    var dto = CaseGraphDTO(try draftGraph(f))
    dto.cases[0].workflowState = "documented"
    dto.methodologies = []
    dto.promiseRevisions[0].context.verification = "unreviewed"
    dto.promiseRevisions[0].context.review = nil
    dto.promiseRevisions[0].context.excerptIDs = []
    dto.promiseRevisions[0].speaker.verification = "unreviewed"
    dto.promiseRevisions[0].speaker.review = nil
    dto.promiseRevisions[0].speaker.excerptIDs = []
    dto.promiseRevisions[0].party.verification = "unreviewed"
    dto.promiseRevisions[0].party.review = nil
    dto.promiseRevisions[0].party.excerptIDs = []
    return try dto.domain()
}
