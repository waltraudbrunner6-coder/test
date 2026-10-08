import Foundation
import SwiftData
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class ManualEvaluationTransactionTests: XCTestCase {
    func testMethodologyRegistrationIsIdempotentAndDoesNotDuplicateRows() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            XCTAssertEqual(try store.ensureMethodologyV1(), try store.ensureMethodologyV1())
            let rows = try store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>())
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(try MethodologyVersionDTO(try store.ensureMethodologyV1()).domain(), try MethodologyV1.version())
        }
    }
    func testConflictingVersionOneIsNeverOverwritten() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            let conflicting = MethodologyVersion(version: text("1.0"), title: text("Synthetic conflicting title"),
                contentReference: text("Synthetic incompatible content"), changeNote: text("Synthetic conflict"))
            dto.methodologies = [MethodologyVersionDTO(conflicting)]
            let original = try dto.domain()
            try store.saveCase(original)
            XCTAssertThrowsError(try store.ensureMethodologyV1()) { XCTAssertEqual($0 as? PersistenceError, .invalidDomain([.methodologyConflict])) }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            XCTAssertThrowsError(try startManualSnapshot(store, f))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testTwoCasesReuseSameCanonicalMethodology() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), a = try PersistenceFixture(), b = try PersistenceFixture()
            for f in [a, b] { try store.saveCase(evaluationReadyGraph(f)); _ = try startManualSnapshot(store, f) }
            let ga = try XCTUnwrap(store.loadCase(id: a.politicalCase.id)), gb = try XCTUnwrap(store.loadCase(id: b.politicalCase.id))
            XCTAssertEqual(ga.methodologies, gb.methodologies)
            XCTAssertEqual(try store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>()).count, 1)
        }
    }
    func testSnapshotStartCannotSkipReadinessAndRollsBackReviewerAndMethodology() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            let original = try draftGraph(f)
            try store.saveCase(original)
            let other = ReviewerIdentity(displayName: text("Synthetic new reviewer"))
            XCTAssertThrowsError(try store.startEvaluationSnapshot(caseID: f.politicalCase.id,
                cutoff: evaluationCutoff(), reviewer: other, at: evaluationTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            let canonicalID = try MethodologyV1.version().id.rawValue
            XCTAssertTrue(try store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>()).allSatisfy { $0.id != canonicalID })
        }
    }
    func testSnapshotContainsSourceClosureAndActionAndOnlyVerifiedLinks() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture(includeAction: true)
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            let draft = EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [f.excerpt.id],
                relationship: .contextualizes, directness: .indirect, rationale: text("Synthetic pending evidence"),
                temporalReference: f.evidence.temporalReference, metadata: f.evidence.metadata)
            dto.evidenceLinks.append(EvidenceLinkDTO(draft))
            try store.saveCase(dto.domain())
            let snapshot = try startManualSnapshot(store, f)
            XCTAssertEqual(snapshot.promiseRevisionID, f.promiseRevision.id)
            XCTAssertEqual(snapshot.criteria.map { $0.id }, [f.criterionRevision.id])
            XCTAssertEqual(snapshot.actionRevisionIDs, [f.actionRevision.id])
            XCTAssertEqual(snapshot.evidenceLinks.map { $0.id }, [f.evidence.id])
            XCTAssertEqual(snapshot.excerpts.map { $0.id }, [f.excerpt.id])
            XCTAssertEqual(snapshot.sourceVersions.map { $0.id }, [f.sourceVersion.id])
            XCTAssertFalse(snapshot.evidenceLinks.contains { $0.id == draft.id })
            XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.cases[0].workflowState, .readyForEvaluation)
        }
    }
    func testSnapshotCannotBeCreatedTwiceOrChangedUnderSameID() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            _ = try startManualSnapshot(store, f)
            let original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try startManualSnapshot(store, f))
            var dto = CaseGraphDTO(original)
            dto.caseRevisions[0].evidenceLinks = []
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testDraftAndSnapshotRoundtripOnNewContextWithUnreviewedChildren() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), evaluation = try saveManualDraft(store, f, snapshot)
            let g = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(g.caseRevisions, [snapshot])
            XCTAssertEqual(g.caseEvaluations, [evaluation])
            XCTAssertEqual(evaluation.status, .draft)
            XCTAssertEqual(evaluation.cutoff.role, .evaluationCutoff)
            XCTAssertEqual(evaluation.caseRevisionID, snapshot.id)
            XCTAssertEqual(evaluation.methodologyVersionID, try MethodologyV1.version().id)
            XCTAssertNil(evaluation.replacesEvaluationID)
            XCTAssertEqual(g.criterionEvaluations.count, snapshot.criteria.count)
            XCTAssertTrue(g.criterionEvaluations.allSatisfy { $0.reviewState == .unreviewed && $0.review == nil })
            XCTAssertEqual(g.cases[0].workflowState, .evaluated)
        }
    }
    func testDraftFailureRollsBackAllChildrenAuditAndCaseMilestone() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f)
            let original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let wrong = ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id,
                assessment: persistenceAssessment(category: .notVerifiable), evidenceLinkIDs: [f.evidence.id])
            XCTAssertThrowsError(try store.createEvaluationDraft(caseID: f.politicalCase.id, snapshotID: snapshot.id,
                cutoff: evaluationCutoff(), criteria: [wrong], overall: persistenceAssessment(), facts: [], interpretations: [],
                reviewer: f.reviewer, at: evaluationTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testMissingAndDuplicateChildrenAreRejectedAtomically() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let child = persistenceInput(f)
            for inputs in [[], [child, child]] {
                XCTAssertThrowsError(try store.createEvaluationDraft(caseID: f.politicalCase.id, snapshotID: snapshot.id,
                    cutoff: evaluationCutoff(), criteria: inputs, overall: persistenceAssessment(), facts: [], interpretations: [],
                    reviewer: f.reviewer, at: evaluationTime))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testCriterionReviewAndSubmissionRemainSeparateHumanSteps() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            try store.reviewCriterionEvaluation(caseID: f.politicalCase.id, childID: draft.criterionEvaluationIDs[0], reviewer: f.reviewer, at: evaluationTime)
            let reviewed = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(reviewed.criterionEvaluations[0].reviewState, .reviewed)
            XCTAssertEqual(reviewed.criterionEvaluations[0].review?.reviewerID, f.reviewer.id)
            XCTAssertEqual(reviewed.caseEvaluations[0].status, .draft)
            try store.submitEvaluationForReview(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime)
            XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.caseEvaluations[0].status, .needsReview)
            XCTAssertEqual(try store.loadCase(id: f.politicalCase.id)?.cases[0].workflowState, .evaluated)
        }
    }
    func testDirectDraftApprovalIsRejectedWithoutPartialCaseUpdate() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            let original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.approveEvaluation(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testApprovalCannotAutomaticallyReviewChildren() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            try store.submitEvaluationForReview(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime)
            let original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.approveEvaluation(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testApprovalAndCaseMilestoneSurviveActualDiskStoreReopen() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let url = folder.appendingPathComponent("Evaluation.store"), f = try PersistenceFixture()
            var expected: DomainContext?
            do {
                let store = try LocalCaseStore.at(url: url)
                try store.saveCase(evaluationReadyGraph(f))
                let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
                try approveManualDraft(store, f, draft)
                expected = try store.loadCase(id: f.politicalCase.id)
            }
            let loaded = try XCTUnwrap(LocalCaseStore.at(url: url).loadCase(id: f.politicalCase.id))
            assertGraphsEqual(try XCTUnwrap(expected), loaded)
            XCTAssertEqual(loaded.cases[0].workflowState, .approved)
            XCTAssertEqual(loaded.caseEvaluations[0].status, .approved)
            XCTAssertEqual(loaded.caseEvaluations[0].approval?.reviewerID, f.reviewer.id)
            XCTAssertEqual(loaded.caseEvaluations[0].approval?.reviewedAt, evaluationTime)
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .upToDate)
        }
    }
    func testNewVerifiedEvidenceStillMarksHistoricalApprovalForReview() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            try approveManualDraft(store, f, draft)
            let historical = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).caseEvaluations[0]
            let pending = EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [f.excerpt.id],
                relationship: .contextualizes, directness: .indirect, rationale: text("Synthetic additional context"),
                temporalReference: f.evidence.temporalReference, metadata: f.evidence.metadata)
            try store.addEvidenceDraft(caseID: f.politicalCase.id, link: pending, reviewer: f.reviewer, at: evaluationTime)
            try store.requestEvidenceReview(caseID: f.politicalCase.id, linkID: pending.id, reviewer: f.reviewer, at: evaluationTime)
            try store.verifyEvidence(caseID: f.politicalCase.id, linkID: pending.id, reviewer: f.reviewer, at: evaluationTime, reason: text("Synthetic new evidence requires review"))
            let g = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(g.cases[0].workflowState, .approved)
            XCTAssertEqual(g.caseEvaluations[0].status, .reviewRequired)
            XCTAssertEqual(g.caseEvaluations[0].category, historical.category)
            XCTAssertEqual(g.caseEvaluations[0].rationale, historical.rationale)
            XCTAssertEqual(g.caseEvaluations[0].approval, historical.approval)
            XCTAssertEqual(g.caseEvaluations[0].methodologyVersionID, historical.methodologyVersionID)
            XCTAssertEqual(g.caseRevisions, [snapshot])
            XCTAssertEqual(try CaseReviews.state(of: g.cases[0], in: g), .reviewRequired)
        }
    }
    func testHistoricalContentMethodologyAndCriterionReviewCannotBeOverwritten() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            try approveManualDraft(store, f, draft)
            let original = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            var dto = CaseGraphDTO(original)
            dto.caseEvaluations[0].rationale = "Synthetic attempted historical overwrite"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            dto = CaseGraphDTO(original); dto.methodologies[0].title = "Synthetic altered methodology"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            dto = CaseGraphDTO(original); dto.criterionEvaluations[0].rationale = "Synthetic altered child"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertThrowsError(try store.reviewCriterionEvaluation(caseID: f.politicalCase.id,
                childID: draft.criterionEvaluationIDs[0], reviewer: f.reviewer, at: evaluationTime))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testAuditContainsAllSeparatedCreationReviewApprovalAndMilestoneActs() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f), draft = try saveManualDraft(store, f, snapshot)
            try approveManualDraft(store, f, draft)
            let g = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let expected = ["registerMethodologyV1", "createCaseRevision", "createCriterionEvaluation", "createCaseEvaluation",
                            "markCaseEvaluated", "reviewCriterionEvaluation", "submitEvaluationForReview", "markCaseApproved", "approveEvaluation"]
            XCTAssertEqual(g.auditEntries.map { $0.operation.value }, expected)
            XCTAssertTrue(g.auditEntries.allSatisfy { $0.author == .human(f.reviewer.id) && $0.humanRequesterID == f.reviewer.id })
        }
    }
    func testEvidenceOfAnotherSnapshotCriterionIsRejected() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            let rootID = EntityID<EvaluationCriterion>()
            let draft = CriterionRevision(criterionID: rootID, promiseRevisionID: f.promiseRevision.id,
                goal: text("Synthetic second criterion"), targetGroup: f.criterionRevision.targetGroup,
                baseline: f.criterionRevision.baseline, deadline: f.criterionRevision.deadline,
                conditions: f.criterionRevision.conditions, isCore: false,
                materialityRule: text("Synthetic secondary materiality"), metadata: f.criterionRevision.metadata)
            dto.criteria.append(EvaluationCriterionDTO(EvaluationCriterion(id: rootID, promiseID: f.promise.id, currentRevisionID: draft.id)))
            dto.criterionRevisions.append(CriterionRevisionDTO(draft))
            let confirmed = try DomainChanges.transition(draft, to: .confirmed, review: f.review, in: dto.domain())
            dto.criterionRevisions[dto.criterionRevisions.count - 1] = CriterionRevisionDTO(confirmed)
            dto.cases[0].activeCriterionRevisionIDs.append(StoredID(confirmed.id, kind: "CriterionRevision"))
            try store.saveCase(dto.domain())
            let snapshot = try startManualSnapshot(store, f)
            XCTAssertEqual(snapshot.criteria.count, 2)
            let wrong = ManualCriterionAssessment(criterionRevisionID: confirmed.id,
                assessment: persistenceAssessment(), evidenceLinkIDs: [f.evidence.id])
            XCTAssertThrowsError(try store.createEvaluationDraft(caseID: f.politicalCase.id, snapshotID: snapshot.id,
                cutoff: evaluationCutoff(), criteria: [persistenceInput(f), wrong], overall: persistenceAssessment(),
                facts: [], interpretations: [], reviewer: f.reviewer, at: evaluationTime)) { error in
                guard let persistence = error as? PersistenceError else { return XCTFail("Unexpected error: \(error)") }
                guard case .invalidDomain(let errors) = persistence else { return XCTFail("Unexpected error: \(error)") }
                XCTAssertTrue(errors.contains(.relationshipMismatch(ObjectReference(kind: .evidenceLink, id: f.evidence.id))))
            }
            XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).caseEvaluations.isEmpty)
        }
    }
    func testSnapshotPreservesParticipationAndResearchTaskStatesWithoutUsingTasksAsEvidence() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture(includeAction: true)
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            let participation = ActionParticipation(actionRevisionID: f.actionRevision.id, actorID: f.speaker.id,
                role: text("Synthetic implementing participant"), kind: .ownAction,
                excerptIDs: [f.excerpt.id], verification: .verified, review: f.review)
            dto.participations.append(ActionParticipationDTO(participation))
            dto.actionRevisions[0].participationIDs = [StoredID(participation.id, kind: "ActionParticipation")]
            let task = ResearchTask(caseID: f.politicalCase.id, goal: text("Synthetic remaining context search"),
                criterionRevisionIDs: [f.criterionRevision.id], status: .blocked, author: .human(f.reviewer.id))
            dto.researchTasks.append(ResearchTaskDTO(task))
            try store.saveCase(dto.domain())
            let snapshot = try startManualSnapshot(store, f)
            XCTAssertEqual(snapshot.participations, [StateSnapshot(id: participation.id, state: .verified)])
            XCTAssertEqual(snapshot.researchTasks, [StateSnapshot(id: task.id, state: .blocked)])
            XCTAssertEqual(snapshot.evidenceLinks.map { $0.id }, [f.evidence.id])
            XCTAssertTrue(DomainValidator.validate(snapshot, in: try XCTUnwrap(store.loadCase(id: f.politicalCase.id))).isValid)
        }
    }
    func testMissingActiveCriteriaCannotCreateSnapshot() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            dto.cases[0].activeCriterionRevisionIDs = []
            // The ready milestone itself must remain invalid, not be bypassed for a fixture.
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }
    func testCurrentActionAndOlderEvidenceReferencedActionBothRemainReproducibleAndUpToDate() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture(includeAction: true)
            var dto = CaseGraphDTO(try evaluationReadyGraph(f))
            var updated = ActionRevisionDTO(f.actionRevision)
            updated.id = StoredID(EntityID<ActionRevision>(), kind: "ActionRevision")
            updated.metadata.number = 2
            updated.metadata.reason = "Synthetic newer procedural revision"
            dto.actionRevisions.append(updated)
            dto.actions[0].currentRevisionID = updated.id
            dto.cases[0].currentActionRevisionIDs = [updated.id]
            try store.saveCase(dto.domain())
            let snapshot = try startManualSnapshot(store, f)
            XCTAssertEqual(snapshot.actionRevisionIDs, [try updated.id.domain(ActionRevision.self, kind: "ActionRevision"), f.actionRevision.id])
            let draft = try saveManualDraft(store, f, snapshot)
            try approveManualDraft(store, f, draft)
            let g = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(g.caseRevisions[0], snapshot)
            XCTAssertEqual(g.find(f.actionRevision.id), f.actionRevision)
            XCTAssertEqual(try CaseReviews.state(of: g.cases[0], in: g), .upToDate)
        }
    }
    func testUnknownSnapshotAndWrongCutoffRoleAreRejectedWithoutDraft() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory(), f = try PersistenceFixture()
            try store.saveCase(evaluationReadyGraph(f))
            let snapshot = try startManualSnapshot(store, f)
            for (id, cutoff) in [(EntityID<CaseRevision>(), try evaluationCutoff()),
                                 (snapshot.id, try DatedValue.instant(PersistenceFixture.cutoff, role: .publication))] {
                XCTAssertThrowsError(try store.createEvaluationDraft(caseID: f.politicalCase.id, snapshotID: id, cutoff: cutoff,
                    criteria: [persistenceInput(f)], overall: persistenceAssessment(), facts: [], interpretations: [], reviewer: f.reviewer, at: evaluationTime))
            }
            XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).caseEvaluations.isEmpty)
        }
    }
}

private let evaluationTime = PersistenceFixture.creation.addingTimeInterval(6 * 86_400)
private func evaluationCutoff() throws -> DatedValue { try .instant(PersistenceFixture.cutoff, role: .evaluationCutoff) }
private func evaluationReadyGraph(_ f: PersistenceFixture) throws -> DomainContext {
    var dto = CaseGraphDTO(try draftGraph(f))
    dto.cases[0].workflowState = "readyForEvaluation"
    dto.cases[0].currentActionRevisionIDs = dto.actionRevisions.map { $0.id }
    dto.methodologies = []
    return try dto.domain()
}
private func persistenceAssessment(category: EvaluationCategory = .fulfilled) -> ManualAssessment {
    ManualAssessment(category: category, rationale: text("Synthetic human assessment"), confidence: .high)
}
private func persistenceInput(_ f: PersistenceFixture) -> ManualCriterionAssessment {
    ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id, assessment: persistenceAssessment(), evidenceLinkIDs: [f.evidence.id])
}
@MainActor private func startManualSnapshot(_ store: LocalCaseStore, _ f: PersistenceFixture) throws -> CaseRevision {
    try store.startEvaluationSnapshot(caseID: f.politicalCase.id, cutoff: evaluationCutoff(), reviewer: f.reviewer, at: evaluationTime)
}
@MainActor private func saveManualDraft(_ store: LocalCaseStore, _ f: PersistenceFixture, _ snapshot: CaseRevision) throws -> CaseEvaluation {
    try store.createEvaluationDraft(caseID: f.politicalCase.id, snapshotID: snapshot.id, cutoff: evaluationCutoff(),
        criteria: [persistenceInput(f)], overall: persistenceAssessment(), facts: [text("Synthetic fact")],
        interpretations: [text("Synthetic interpretation")], reviewer: f.reviewer, at: evaluationTime)
}
@MainActor private func approveManualDraft(_ store: LocalCaseStore, _ f: PersistenceFixture, _ draft: CaseEvaluation) throws {
    for id in draft.criterionEvaluationIDs {
        try store.reviewCriterionEvaluation(caseID: f.politicalCase.id, childID: id, reviewer: f.reviewer, at: evaluationTime)
    }
    try store.submitEvaluationForReview(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime)
    try store.approveEvaluation(caseID: f.politicalCase.id, evaluationID: draft.id, reviewer: f.reviewer, at: evaluationTime)
}
