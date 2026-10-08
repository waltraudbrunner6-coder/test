import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class ManualInputTransactionTests: XCTestCase {
    func testActionFirstRevisionRoundtripRetainsIDsAndUnreviewedFacts() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let (action, revision) = try manualAction(f)
            try store.addAction(caseID: f.politicalCase.id, action: action, revision: revision, reviewer: f.reviewer, at: manualTime)
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.actions, [action])
            XCTAssertEqual(loaded.actionRevisions, [revision])
            XCTAssertEqual(loaded.cases[0].currentActionRevisionIDs, [revision.id])
            XCTAssertEqual(revision.description.verification, .unreviewed)
            XCTAssertEqual(revision.eventDate.verification, .unreviewed)
            XCTAssertEqual(revision.scope.verification, .unreviewed)
            XCTAssertNil(revision.description.review)
            XCTAssertTrue(loaded.participations.isEmpty)
            XCTAssertEqual(loaded.auditEntries.last?.operation, text("addAction"))
            XCTAssertEqual(loaded.auditEntries.last?.humanRequesterID, f.reviewer.id)
        }
    }

    func testActionVerificationCreatesNewRevisionAndKeepsOldContent() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let (action, old) = try manualAction(f)
            try store.addAction(caseID: f.politicalCase.id, action: action, revision: old, reviewer: f.reviewer, at: manualTime)
            try store.verifyAction(caseID: f.politicalCase.id, revisionID: old.id, excerptIDs: [f.excerpt.id], reviewer: f.reviewer, at: manualTime.addingTimeInterval(60))
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.find(old.id), old)
            let next = try XCTUnwrap(loaded.actionRevisions.first { $0.id != old.id })
            XCTAssertEqual(next.metadata.number, 2)
            XCTAssertEqual(next.actionID, old.actionID)
            XCTAssertEqual(next.description.content, old.description.content)
            XCTAssertEqual(next.eventDate.content, old.eventDate.content)
            XCTAssertEqual(next.scope.content, old.scope.content)
            XCTAssertEqual(next.description.verification, .verified)
            XCTAssertEqual(next.eventDate.verification, .verified)
            XCTAssertEqual(next.scope.verification, .verified)
            XCTAssertEqual(next.description.review?.reviewerID, f.reviewer.id)
            XCTAssertEqual(next.excerptIDs, [f.excerpt.id])
            XCTAssertEqual(loaded.actions[0].currentRevisionID, next.id)
            XCTAssertEqual(loaded.cases[0].currentActionRevisionIDs, [next.id])
            XCTAssertEqual(loaded.auditEntries.last?.operation, text("verifyAction"))
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
        }
    }

    func testActionVerificationWithoutExcerptsRollsBackEverything() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let (action, revision) = try manualAction(f)
            try store.addAction(caseID: f.politicalCase.id, action: action, revision: revision, reviewer: f.reviewer, at: manualTime)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let newReviewer = ReviewerIdentity(displayName: text("Another synthetic reviewer"))
            XCTAssertThrowsError(try store.verifyAction(caseID: f.politicalCase.id, revisionID: revision.id,
                excerptIDs: [], reviewer: newReviewer, at: manualTime))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testEvidenceDraftRetainsExactCriterionExcerptsAndActionRevision() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let link = try manualLink(f, actionID: f.actionRevision.id)
            try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime)
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.find(link.id), link)
            XCTAssertEqual(loaded.find(link.id)?.criterionRevisionID, f.criterionRevision.id)
            XCTAssertEqual(loaded.find(link.id)?.excerptIDs, [f.excerpt.id])
            XCTAssertEqual(loaded.find(link.id)?.actionRevisionID, f.actionRevision.id)
            XCTAssertEqual(loaded.find(link.id)?.status, .draft)
            XCTAssertNil(loaded.find(link.id)?.review)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.criterionEvaluations.isEmpty)
        }
    }

    func testEvidenceWithoutExcerptRejectedEvenWhenActionExists() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let link = try manualLink(f, excerptIDs: [], actionID: f.actionRevision.id)
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testUnverifiedExcerptCannotBeUsedAsManualEvidenceOrCheckedAction() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            var dto = CaseGraphDTO(try draftGraph(f))
            var unverified = SourceExcerptDTO(f.excerpt)
            let id = EntityID<SourceExcerpt>()
            unverified.id = StoredID(id, kind: "SourceExcerpt")
            unverified.state = "unverified"
            unverified.review = nil
            dto.excerpts.append(unverified)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(dto.domain())
            let link = try manualLink(f, excerptIDs: [id])
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime))
            let (action, revision) = try manualAction(f)
            try store.addAction(caseID: f.politicalCase.id, action: action, revision: revision, reviewer: f.reviewer, at: manualTime)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.verifyAction(caseID: f.politicalCase.id, revisionID: revision.id, excerptIDs: [id], reviewer: f.reviewer, at: manualTime))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testVerifiedEvidenceHumanReviewSurvivesDiskStoreReopen() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let url = folder.appendingPathComponent("Synthetic.store")
            let f = try PersistenceFixture(includeAction: false)
            let link = try manualLink(f)
            let date = manualTime.addingTimeInterval(60)
            var expected: EvidenceLink?
            do {
                let store = try LocalCaseStore.at(url: url)
                try store.saveCase(draftGraph(f))
                try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime)
                try store.requestEvidenceReview(caseID: f.politicalCase.id, linkID: link.id, reviewer: f.reviewer, at: manualTime)
                try store.verifyEvidence(caseID: f.politicalCase.id, linkID: link.id, reviewer: f.reviewer, at: date, reason: text("Synthetic human check"))
                expected = try store.loadCase(id: f.politicalCase.id)?.find(link.id)
            }
            let reopened = try LocalCaseStore.at(url: url)
            let loaded = try XCTUnwrap(reopened.loadCase(id: f.politicalCase.id))
            let verified = try XCTUnwrap(loaded.find(link.id))
            XCTAssertEqual(verified, expected)
            XCTAssertEqual(verified.status, .verified)
            XCTAssertEqual(verified.review, HumanReview(reviewerID: f.reviewer.id, reviewedAt: date))
            XCTAssertEqual(verified.id, link.id)
            XCTAssertEqual(verified.rationale, link.rationale)
            XCTAssertEqual(verified.temporalReference, link.temporalReference)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
            XCTAssertEqual(loaded.auditEntries.count, 3)
        }
    }

    func testDraftCannotSkipNeedsReviewAndFailureIsAtomic() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let link = try manualLink(f)
            try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.verifyEvidence(caseID: f.politicalCase.id, linkID: link.id, reviewer: f.reviewer, at: manualTime, reason: text("Synthetic attempted skip")))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testMissingOrForeignCriterionCannotBeSaved() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let other = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            try store.saveCase(draftGraph(other))
            for criterionID in [EntityID<CriterionRevision>(), other.criterionRevision.id] {
                let link = try manualLink(f, criterionID: criterionID)
                XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime))
            }
            assertGraphsEqual(try draftGraph(f), try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testDraftCriterionCannotReceiveManualEvidence() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(criterionState: .draft, includeAction: false)
            // Remove evaluations, snapshots and existing link: only the manual input is tested.
            var dto = CaseGraphDTO(try draftGraph(f))
            dto.evidenceLinks = []
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(dto.domain())
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: manualLink(f), reviewer: f.reviewer, at: manualTime))
            XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).evidenceLinks.isEmpty)
        }
    }

    func testMissingActionAndMissingExcerptRejected() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id,
                link: manualLink(f, actionID: EntityID<ActionRevision>()), reviewer: f.reviewer, at: manualTime))
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id,
                link: manualLink(f, excerptIDs: [EntityID<SourceExcerpt>()]), reviewer: f.reviewer, at: manualTime))
        }
    }

    func testPublicationDateCannotReplaceEvidenceTemporalRole() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let link = try manualLink(f, temporal: try .instant(manualTime, role: .publication))
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime))
        }
    }

    func testManualVerificationMarksHistoricalApprovalForReviewWithoutChangingJudgment() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            let link = try manualLink(f)
            try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime)
            XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.caseEvaluations[0], original.caseEvaluations[0])
            try store.requestEvidenceReview(caseID: f.politicalCase.id, linkID: link.id, reviewer: f.reviewer, at: manualTime)
            try store.verifyEvidence(caseID: f.politicalCase.id, linkID: link.id, reviewer: f.reviewer, at: manualTime, reason: text("Synthetic relevant new evidence"))
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.cases[0].workflowState, .approved)
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .reviewRequired)
            XCTAssertEqual(loaded.caseEvaluations[0].status, .reviewRequired)
            XCTAssertEqual(loaded.caseEvaluations[0].category, original.caseEvaluations[0].category)
            XCTAssertEqual(loaded.caseEvaluations[0].rationale, original.caseEvaluations[0].rationale)
            XCTAssertEqual(loaded.caseEvaluations[0].approval, original.caseEvaluations[0].approval)
            XCTAssertEqual(loaded.caseEvaluations[0].methodologyVersionID, original.caseEvaluations[0].methodologyVersionID)
            XCTAssertEqual(loaded.caseEvaluations[0].caseRevisionID, original.caseEvaluations[0].caseRevisionID)
            XCTAssertEqual(loaded.caseRevisions, original.caseRevisions)
            XCTAssertEqual(loaded.criterionEvaluations, original.criterionEvaluations)
            XCTAssertEqual(loaded.caseEvaluations.count, 1)
            XCTAssertEqual(loaded.auditEntries.count, 4)
        }
    }

    func testDuplicateDraftIDRejectedWithoutAuditOrContentChanges() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: false)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            let link = try manualLink(f)
            try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.addEvidenceDraft(caseID: f.politicalCase.id, link: link, reviewer: f.reviewer, at: manualTime))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testCheckedActionCannotBeOverwrittenUnderHistoricalID() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            var dto = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            dto.actionRevisions[0].title = "Synthetic changed historical title"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.find(f.actionRevision.id), f.actionRevision)
        }
    }
}

private var manualTime: Date { PersistenceFixture.creation.addingTimeInterval(5 * 86_400) }

private func manualAction(_ f: PersistenceFixture) throws -> (ActionOrDevelopment, ActionRevision) {
    let id = EntityID<ActionOrDevelopment>()
    let revision = try ActionRevision(actionID: id, type: .development, title: text("Synthetic later development"),
        description: AssertedValue(content: .known(text("Synthetic documented development")), provenance: .humanEntered),
        eventDate: AssertedValue(content: .known(DatedValue.instant(PersistenceFixture.event, role: .event)), provenance: .humanEntered),
        proceduralState: text("Synthetic procedural state"),
        scope: AssertedValue(content: .known(text("Synthetic target area")), provenance: .humanEntered),
        metadata: RevisionMetadata(number: 1, reason: text("Synthetic manual input"), author: .human(f.reviewer.id), createdAt: manualTime))
    return (ActionOrDevelopment(id: id, caseID: f.politicalCase.id, currentRevisionID: revision.id, createdAt: manualTime), revision)
}

private func manualLink(_ f: PersistenceFixture, criterionID: EntityID<CriterionRevision>? = nil,
                        excerptIDs: [EntityID<SourceExcerpt>]? = nil, actionID: EntityID<ActionRevision>? = nil,
                        temporal: DatedValue? = nil) throws -> EvidenceLink {
    EvidenceLink(criterionRevisionID: criterionID ?? f.criterionRevision.id,
        excerptIDs: excerptIDs ?? [f.excerpt.id], actionRevisionID: actionID, relationship: .contextualizes,
        directness: .direct, rationale: text("Synthetic evidence association, not a political category"),
        temporalReference: try temporal ?? DatedValue.instant(PersistenceFixture.event, role: .event),
        metadata: RevisionMetadata(number: 1, reason: text("Synthetic manual evidence"), author: .human(f.reviewer.id), createdAt: manualTime))
}
