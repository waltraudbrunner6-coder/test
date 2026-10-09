import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

final class ResearchReviewWorkspaceTests: XCTestCase {
    @MainActor func setup() throws -> (DeepResearchFixture, LocalCaseStore, CaseWorkspaceModel) {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        let model = CaseWorkspaceModel(store: store, defaults: UserDefaults(suiteName: "synthetic-review-" + UUID().uuidString)!)
        model.selectCase(f.request.caseID)
        return (f, store, model)
    }
    @MainActor func ready(_ model: CaseWorkspaceModel) throws {
        model.reviewerName = "Synthetischer Mensch"
        let id = try XCTUnwrap(model.researchReviewPlan?.originalExcerptID)
        XCTAssertTrue(model.performResearchReview(.excerpt(id, reject: false)))
        XCTAssertTrue(model.performResearchReview(.original))
        XCTAssertTrue(model.performResearchReview(.criterion("criterion-1", use: true)))
        XCTAssertTrue(model.performResearchReview(.frame("Menschlich geprüfter synthetischer Kontext")))
    }
    @MainActor func testPlanAvailableWithoutCreatingReviewer() throws {
        let (_, _, model) = try setup()
        XCTAssertNotNil(model.researchReviewPlan); XCTAssertFalse(model.researchReviewPlan?.blockingIssues.isEmpty == true)
        XCTAssertTrue(model.selectedContext?.reviewers.isEmpty == true)
    }
    @MainActor func testMissingReviewerBlocksReviewWithoutWriting() throws {
        let (_, store, model) = try setup(), id = try XCTUnwrap(model.researchReviewPlan?.originalExcerptID)
        XCTAssertFalse(model.performResearchReview(.excerpt(id, reject: false))); XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(try store.loadCase(id: XCTUnwrap(model.selectedCaseID))?.reviewers.isEmpty == true)
    }
    @MainActor func testStagesProgressAndPrefilledAssessment() throws {
        let (_, _, model) = try setup(); try ready(model)
        XCTAssertEqual(model.selectedCase?.workflowState, .readyForEvaluation)
        XCTAssertEqual(model.researchReviewPlan?.criteria[0].state, .reviewed)
        XCTAssertEqual(model.researchReviewPlan?.assessment, .ready)
        XCTAssertTrue(model.performResearchReview(.assessment(acknowledgeOmittedCounterEvidence: false)))
        let evaluation = try XCTUnwrap(model.selectedContext?.caseEvaluations.first)
        XCTAssertEqual(evaluation.category, .notVerifiable)
        XCTAssertEqual(evaluation.rationale.value, model.researchDossiers[try XCTUnwrap(model.selectedCaseID)]?.result.overallAssessmentDraft.rationale)
        XCTAssertNil(evaluation.approval); XCTAssertEqual(evaluation.status, .draft)
    }
    @MainActor func testEvidenceUsesCurrentIDs() throws {
        let (_, _, model) = try setup(); try ready(model)
        let plan = try XCTUnwrap(model.researchReviewPlan), raw = try XCTUnwrap(plan.record.bindings?.excerpts["e1"])
        XCTAssertFalse(model.performResearchReview(.evidence("ev1", use: true)))
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.performResearchReview(.excerpt(EntityID<SourceExcerpt>(raw), reject: false)))
        XCTAssertTrue(model.performResearchReview(.correctedDevelopment("d1", scope: "Synthetischer geprüfter Umfang", eventDate: "2023")))
        XCTAssertTrue(model.performResearchReview(.evidence("ev1", use: true)))
        let current = try XCTUnwrap(model.researchReviewPlan), id = try XCTUnwrap(current.evidenceIDs["ev1"])
        XCTAssertEqual(model.selectedContext?.find(id)?.criterionRevisionID, current.criterionIDs["criterion-1"])
        XCTAssertEqual(model.selectedContext?.find(id)?.actionRevisionID, current.actionIDs["d1"])
        XCTAssertEqual(model.selectedContext?.find(id)?.excerptIDs, [try XCTUnwrap(current.excerptIDs["e1"])])
    }
    @MainActor func testFinalExplicitApprovalAndReopen() throws {
        let (f, store, model) = try setup(); try ready(model)
        XCTAssertTrue(model.performResearchReview(.assessment(acknowledgeOmittedCounterEvidence: false)))
        let evaluation = try XCTUnwrap(model.selectedContext?.caseEvaluations.first)
        XCTAssertFalse(model.performResearchReview(.approval(evaluation.id, checked: [], confirmation: true, acknowledgeOmittedCounterEvidence: false)))
        XCTAssertTrue(model.performResearchReview(.approval(evaluation.id, checked: Set(evaluation.criterionEvaluationIDs), confirmation: true, acknowledgeOmittedCounterEvidence: false)))
        let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: UserDefaults(suiteName: "synthetic-reopened-" + UUID().uuidString)!)
        reopened.selectCase(f.request.caseID)
        XCTAssertEqual(reopened.researchReviewPlan?.assessment, .reviewed); XCTAssertEqual(reopened.selectedCase?.workflowState, .approved)
        XCTAssertTrue(reopened.selectedContext?.scripts.isEmpty == true)
    }
    @MainActor func testNoRecommendationDisplayedAndCannotMaterialize() throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        let result = try f.result { object in
            var child = (object["criterionAssessmentDrafts"] as! [[String: Any]])[0]; child["suggestedCategory"] = NSNull(); object["criterionAssessmentDrafts"] = [child]
            var overall = object["overallAssessmentDraft"] as! [String: Any]; overall["suggestedCategory"] = NSNull(); object["overallAssessmentDraft"] = overall
        }
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record(result))
        let model = CaseWorkspaceModel(store: store, defaults: UserDefaults(suiteName: "synthetic-no-recommendation-" + UUID().uuidString)!); model.selectCase(f.request.caseID)
        try ready(model)
        XCTAssertTrue(model.researchReviewPlan?.blockingIssues.contains { $0.contains("keine belastbare Empfehlung") } == true)
        XCTAssertFalse(model.performResearchReview(.assessment(acknowledgeOmittedCounterEvidence: false)))
        XCTAssertTrue(model.selectedContext?.caseRevisions.isEmpty == true); XCTAssertTrue(model.selectedContext?.caseEvaluations.isEmpty == true)
    }
}
