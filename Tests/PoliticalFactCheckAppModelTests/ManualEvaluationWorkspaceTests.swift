import Foundation
import XCTest
@testable import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckAppModel

final class ManualEvaluationWorkspaceTests: XCTestCase {
    func testCompleteManualEvaluationHumanReviewAndApprovalReloadWorkflow() async throws {
        try await MainActor.run {
            let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(workspaceEvaluationGraph(f))
            let defaults = evaluationDefaults(f)
            defer { defaults.removePersistentDomain(forName: defaults.string(forKey: "testSuite")!) }
            let model = CaseWorkspaceModel(store: store, defaults: defaults)
            let snapshotID = try XCTUnwrap(model.startEvaluationSnapshot(cutoff: workspaceCutoff()))
            let snapshot = try XCTUnwrap(model.selectedContext?.find(snapshotID))
            let evaluationID = try XCTUnwrap(model.createEvaluationDraft(snapshotID: snapshotID, cutoff: workspaceCutoff(),
                criteria: [workspaceAssessment(f)], overall: workspaceOverall(), facts: [text("Synthetic human fact")],
                interpretations: [text("Synthetic human interpretation")]))
            let draft = try XCTUnwrap(model.selectedContext?.find(evaluationID))
            XCTAssertEqual(draft.status, .draft)
            XCTAssertEqual(model.selectedCase?.workflowState, .evaluated)
            let child = try XCTUnwrap(model.selectedContext?.find(draft.criterionEvaluationIDs[0]))
            XCTAssertEqual(child.reviewState, .unreviewed)
            XCTAssertNil(child.review)
            XCTAssertTrue(model.reviewCriterionEvaluation(child.id))
            XCTAssertEqual(model.selectedContext?.find(evaluationID)?.status, .draft)
            XCTAssertTrue(model.submitEvaluationForReview(evaluationID))
            XCTAssertEqual(model.selectedCase?.workflowState, .evaluated)
            XCTAssertTrue(model.approveEvaluation(evaluationID))
            let historical = try XCTUnwrap(model.selectedContext?.find(evaluationID))
            XCTAssertEqual(historical.category, draft.category)
            XCTAssertEqual(historical.rationale, draft.rationale)
            XCTAssertEqual(historical.facts, draft.facts)
            XCTAssertEqual(historical.interpretations, draft.interpretations)
            XCTAssertEqual(historical.approval?.reviewerID, f.reviewer.id)
            XCTAssertEqual(historical.methodologyVersionID, try MethodologyV1.version().id)
            let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
            XCTAssertEqual(reopened.selectedCase?.workflowState, .approved)
            XCTAssertEqual(reopened.selectedReviewState, .upToDate)
            XCTAssertEqual(reopened.selectedContext?.find(evaluationID), historical)
            XCTAssertEqual(reopened.selectedContext?.find(snapshotID), snapshot)
            XCTAssertEqual(reopened.cases.count, 1)
            XCTAssertNil(reopened.errorMessage)
        }
    }
    func testStartingEvaluationBeforeReadinessShowsErrorAndDoesNotPersistAnything() async throws {
        try await MainActor.run {
            let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(workspaceEvaluationGraph(f, ready: false))
            let model = CaseWorkspaceModel(store: store, defaults: evaluationDefaults(f))
            XCTAssertNil(model.startEvaluationSnapshot(cutoff: try workspaceCutoff()))
            XCTAssertEqual(model.errorMessage, WorkspaceErrorMessage.describe(DomainValidationError.evaluationRequiresReadyCase))
            let g = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertTrue(g.caseRevisions.isEmpty)
            XCTAssertTrue(g.caseEvaluations.isEmpty)
            XCTAssertTrue(g.methodologies.isEmpty)
        }
    }
    func testNotVerifiableReasonErrorKeepsReadyCaseAndSnapshotWithoutEvaluation() async throws {
        try await MainActor.run {
            let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(workspaceEvaluationGraph(f))
            let model = CaseWorkspaceModel(store: store, defaults: evaluationDefaults(f))
            let snapshotID = try XCTUnwrap(model.startEvaluationSnapshot(cutoff: workspaceCutoff()))
            let missingReason = ManualAssessment(category: .notVerifiable, rationale: text("Synthetic explicit unknown judgment"), confidence: .low)
            let input = ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id, assessment: missingReason)
            XCTAssertNil(model.createEvaluationDraft(snapshotID: snapshotID, cutoff: try workspaceCutoff(), criteria: [input],
                overall: missingReason, facts: [], interpretations: []))
            XCTAssertTrue(model.errorMessage?.contains("strukturierter Grund") == true)
            let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: evaluationDefaults(f))
            XCTAssertEqual(reopened.selectedCase?.workflowState, .readyForEvaluation)
            XCTAssertEqual(reopened.selectedContext?.caseRevisions.count, 1)
            XCTAssertTrue(reopened.selectedContext?.caseEvaluations.isEmpty == true)
        }
    }
    func testUICommandsCannotSkipSubmissionOrChildReview() async throws {
        try await MainActor.run {
            let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(workspaceEvaluationGraph(f))
            let model = CaseWorkspaceModel(store: store, defaults: evaluationDefaults(f))
            let snapshot = try XCTUnwrap(model.startEvaluationSnapshot(cutoff: workspaceCutoff()))
            let id = try XCTUnwrap(model.createEvaluationDraft(snapshotID: snapshot, cutoff: workspaceCutoff(),
                criteria: [workspaceAssessment(f)], overall: workspaceOverall(), facts: [], interpretations: []))
            XCTAssertFalse(model.approveEvaluation(id))
            XCTAssertEqual(model.selectedContext?.find(id)?.status, .draft)
            XCTAssertTrue(model.submitEvaluationForReview(id))
            XCTAssertFalse(model.approveEvaluation(id))
            XCTAssertTrue(model.errorMessage?.contains("noch nicht menschlich geprüft") == true)
            XCTAssertEqual(model.selectedContext?.find(id)?.status, .needsReview)
            XCTAssertEqual(model.selectedCase?.workflowState, .evaluated)
        }
    }
    func testValidationWarningsAreExposedWithoutExcludingHistoricalSource() async throws {
        try await MainActor.run {
            let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
            var dto = CaseGraphDTO(try workspaceEvaluationGraph(f))
            dto.evidenceLinks[0].temporalReference = DatedDTO(try .unknown(role: .event, reason: text("Synthetic uncertain event dating")))
            try store.saveCase(dto.domain())
            let model = CaseWorkspaceModel(store: store, defaults: evaluationDefaults(f))
            let snapshot = try XCTUnwrap(model.startEvaluationSnapshot(cutoff: workspaceCutoff()))
            let id = try XCTUnwrap(model.createEvaluationDraft(snapshotID: snapshot, cutoff: workspaceCutoff(),
                criteria: [workspaceAssessment(f)], overall: workspaceOverall(), facts: [], interpretations: []))
            let warnings = model.evaluationWarnings(id)
            XCTAssertTrue(warnings.contains { $0.contains("Rückblickende Dokumentation") })
            XCTAssertTrue(warnings.contains { $0.contains("menschliche Einordnung") })
            XCTAssertNotNil(model.selectedContext?.find(f.sourceVersion.id))
            XCTAssertNil(model.errorMessage)
        }
    }
    func testWorkflowErrorsAreReadableAndDoNotSuggestAutomaticJudgment() {
        for error in [DomainValidationError.evaluationRequiresReadyCase, .methodologyConflict,
                      .criterionReviewNotAllowed, .firstEvaluationOnly, .unreviewedCriterionEvaluation,
                      .lowConfidenceNegativeJudgment, .deadlineNotPassed, .missingCutoff] {
            XCTAssertFalse(WorkspaceErrorMessage.describe(error).isEmpty)
        }
    }
}

private func workspaceEvaluationGraph(_ f: AppWorkspaceFixture, ready: Bool = true) throws -> DomainContext {
    var dto = CaseGraphDTO(f.context())
    dto.cases[0].workflowState = ready ? "readyForEvaluation" : "candidate"
    dto.caseRevisions = []; dto.caseEvaluations = []; dto.criterionEvaluations = []; dto.methodologies = []
    return try dto.domain()
}
private func evaluationDefaults(_ f: AppWorkspaceFixture) -> UserDefaults {
    let suite = "SyntheticEvaluation-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(suite, forKey: "testSuite")
    defaults.set(f.reviewer.displayName.value, forKey: "politicalFactCheck.reviewerName")
    defaults.set(f.reviewer.id.rawValue.uuidString, forKey: "politicalFactCheck.reviewerID")
    return defaults
}
private func workspaceCutoff() throws -> DatedValue { try .instant(AppWorkspaceFixture.cutoff, role: .evaluationCutoff) }
private func workspaceOverall() -> ManualAssessment {
    ManualAssessment(category: .fulfilled, rationale: text("Synthetic human overall reasoning"), confidence: .high)
}
private func workspaceAssessment(_ f: AppWorkspaceFixture) -> ManualCriterionAssessment {
    ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id, assessment: workspaceOverall(), evidenceLinkIDs: [f.evidence.id])
}
