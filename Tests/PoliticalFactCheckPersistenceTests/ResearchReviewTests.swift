import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch
@testable import PoliticalFactCheckPersistence

final class ResearchReviewTests: XCTestCase {
    let reviewer = ReviewerIdentity(displayName: try! NonEmptyText("Synthetischer menschlicher Reviewer"))
    let date = Date(timeIntervalSince1970: 1_791_500_000)
    @MainActor func setup() throws -> (DeepResearchFixture, LocalCaseStore) {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record())
        return (f, store)
    }
    @MainActor func original(_ f: DeepResearchFixture, _ store: LocalCaseStore) throws {
        let plan = try store.researchReviewPlan(caseID: f.request.caseID)
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: XCTUnwrap(plan.originalExcerptID), reviewer: reviewer, at: date)
        try store.reviewResearchOriginal(caseID: f.request.caseID, reviewer: reviewer, at: date)
    }
    @MainActor func frame(_ f: DeepResearchFixture, _ store: LocalCaseStore) throws {
        try original(f, store)
        try store.selectResearchCriterion(caseID: f.request.caseID, key: "criterion-1", use: true, reviewer: reviewer, at: date)
        try store.confirmResearchFrame(caseID: f.request.caseID, contextText: NonEmptyText("Synthetischer geprüfter Kontext"), reviewer: reviewer, at: date)
    }
    @MainActor func evidence(_ f: DeepResearchFixture, _ store: LocalCaseStore) throws {
        try frame(f, store)
        let plan = try store.researchReviewPlan(caseID: f.request.caseID), raw = try XCTUnwrap(plan.record.bindings?.excerpts["e1"])
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: EntityID<SourceExcerpt>(raw), reviewer: reviewer, at: date)
        try store.reviewResearchDevelopment(caseID: f.request.caseID, key: "d1", use: true, scope: NonEmptyText("Synthetischer geprüfter Umfang"), reviewer: reviewer, at: date)
        try store.adoptResearchEvidence(caseID: f.request.caseID, key: "ev1", use: true, reviewer: reviewer, at: date)
    }
    @MainActor func testEndToEndHumanReviewToApprovedEvaluation() throws {
        let (f, store) = try setup(); try evidence(f, store)
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let draft = try XCTUnwrap(store.loadCase(id: f.request.caseID)), evaluation = try XCTUnwrap(draft.caseEvaluations.first)
        XCTAssertEqual(evaluation.status, .draft); XCTAssertNil(evaluation.approval)
        XCTAssertEqual(evaluation.cutoff.content.knownValue?.end, f.now)
        XCTAssertTrue(draft.criterionEvaluations.allSatisfy { $0.reviewState == .unreviewed })
        try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: evaluation.id,
            checkedCriterionIDs: Set(evaluation.criterionEvaluationIDs), explicitConfirmation: true, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertEqual(graph.cases[0].workflowState, .approved); XCTAssertEqual(graph.caseEvaluations[0].status, .approved)
        XCTAssertEqual(graph.caseEvaluations[0].approval?.reviewerID, reviewer.id)
        XCTAssertTrue(graph.criterionEvaluations.allSatisfy { $0.review?.reviewerID == reviewer.id })
        XCTAssertTrue(DomainValidator.validate(graph).isValid); XCTAssertTrue(graph.participations.isEmpty); XCTAssertTrue(graph.scripts.isEmpty)
    }
    @MainActor func testEvidenceRebasesAllThreeIDsAndRetainsAIHistory() throws {
        let (f, store) = try setup(), before = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        try evidence(f, store)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID)), plan = try store.researchReviewPlan(caseID: f.request.caseID)
        let adopted = try XCTUnwrap(plan.evidenceIDs["ev1"]), link = try XCTUnwrap(graph.find(adopted))
        XCTAssertEqual(link.criterionRevisionID, plan.criterionIDs["criterion-1"])
        XCTAssertEqual(link.excerptIDs, [try XCTUnwrap(plan.excerptIDs["e1"])])
        XCTAssertEqual(link.actionRevisionID, plan.actionIDs["d1"])
        XCTAssertNotEqual(link.criterionRevisionID.rawValue, plan.record.bindings?.criterionRevisions["criterion-1"])
        XCTAssertNotEqual(link.excerptIDs[0].rawValue, plan.record.bindings?.excerpts["e1"])
        XCTAssertNotEqual(link.actionRevisionID?.rawValue, plan.record.bindings?.actionRevisions["d1"])
        XCTAssertEqual(link.status, .verified); XCTAssertEqual(link.review?.reviewerID, reviewer.id)
        for old in before.criterionRevisions { XCTAssertEqual(graph.find(old.id), old) }
        for old in before.excerpts { XCTAssertEqual(graph.find(old.id), old) }
        for old in before.actionRevisions { XCTAssertEqual(graph.find(old.id), old) }
        for old in before.evidenceLinks { XCTAssertEqual(graph.find(old.id), old) }
        XCTAssertEqual(before.researchTasks, graph.researchTasks)
        for old in before.auditEntries { XCTAssertTrue(graph.auditEntries.contains(old)) }
    }
    @MainActor func testReopenAfterEachStageReconstructsPlan() throws {
        let (f, store) = try setup()
        func reopened() throws -> ResearchReviewPlan { try LocalCaseStore(container: store.container).researchReviewPlan(caseID: f.request.caseID) }
        try original(f, store); XCTAssertEqual(try reopened().originalSource, .reviewed)
        try store.selectResearchCriterion(caseID: f.request.caseID, key: "criterion-1", use: true, reviewer: reviewer, at: date)
        try store.confirmResearchFrame(caseID: f.request.caseID, contextText: NonEmptyText("Synthetischer Kontext"), reviewer: reviewer, at: date)
        XCTAssertEqual(try reopened().criteria[0].state, .reviewed)
        let raw = try XCTUnwrap(try reopened().record.bindings?.excerpts["e1"])
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: EntityID<SourceExcerpt>(raw), reviewer: reviewer, at: date)
        XCTAssertNotNil(try reopened().excerptIDs["e1"])
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        XCTAssertEqual(try reopened().assessment, .open)
        let evaluation = try XCTUnwrap(store.loadCase(id: f.request.caseID)?.caseEvaluations.first)
        try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: evaluation.id, checkedCriterionIDs: Set(evaluation.criterionEvaluationIDs), explicitConfirmation: true,
            acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        XCTAssertEqual(try reopened().assessment, .reviewed)
    }
    @MainActor func testUnusedSourceDoesNotBlockNotVerifiableAssessment() throws {
        let (f, store) = try setup(); try frame(f, store)
        let plan = try store.researchReviewPlan(caseID: f.request.caseID)
        XCTAssertNil(plan.excerptIDs["e1"]); XCTAssertTrue(plan.blockingIssues.isEmpty)
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        let raw = try XCTUnwrap(plan.record.bindings?.excerpts["e1"])
        XCTAssertEqual(graph.find(EntityID<SourceExcerpt>(raw))?.state, .unverified)
        XCTAssertEqual(graph.caseEvaluations[0].category, .notVerifiable)
    }
    @MainActor func testUnverifiedExcerptPreventsEvidenceAdoptionAndRollsBack() throws {
        let (f, store) = try setup(); try frame(f, store)
        let before = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID)))
        XCTAssertThrowsError(try store.adoptResearchEvidence(caseID: f.request.caseID, key: "ev1", use: true, reviewer: reviewer, at: date))
        XCTAssertEqual(before, CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
    }
    @MainActor func testUnknownActionScopeRequiresExplicitHumanCorrection() throws {
        let (f, store) = try setup(); try frame(f, store)
        let plan = try store.researchReviewPlan(caseID: f.request.caseID), raw = try XCTUnwrap(plan.record.bindings?.excerpts["e1"])
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: EntityID<SourceExcerpt>(raw), reviewer: reviewer, at: date)
        let before = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID)))
        XCTAssertThrowsError(try store.reviewResearchDevelopment(caseID: f.request.caseID, key: "d1", use: true, reviewer: reviewer, at: date))
        XCTAssertEqual(before, CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
        try store.reviewResearchDevelopment(caseID: f.request.caseID, key: "d1", use: true, scope: NonEmptyText("Menschlich geprüfter synthetischer Umfang"), reviewer: reviewer, at: date)
        let current = try store.researchReviewPlan(caseID: f.request.caseID), graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        let checked = try XCTUnwrap(current.actionIDs["d1"])
        XCTAssertEqual(graph.find(checked)?.scope.provenance, .humanEntered)
        XCTAssertEqual(graph.find(checked)?.scope.verification, .verified)
        let old = try XCTUnwrap(plan.record.bindings?.actionRevisions["d1"])
        XCTAssertNil(graph.find(EntityID<ActionRevision>(old))?.scope.content.knownValue)
    }

    @MainActor func testMissingActionVerificationPreventsAdoption() throws {
        let (f, store) = try setup(); try frame(f, store)
        let plan = try store.researchReviewPlan(caseID: f.request.caseID), raw = try XCTUnwrap(plan.record.bindings?.excerpts["e1"])
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: EntityID<SourceExcerpt>(raw), reviewer: reviewer, at: date)
        XCTAssertThrowsError(try store.adoptResearchEvidence(caseID: f.request.caseID, key: "ev1", use: true, reviewer: reviewer, at: date))
        XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.request.caseID)).evidenceLinks.allSatisfy { $0.status == .draft })
    }
    @MainActor func testFinalApprovalRequiresExplicitAndEveryCriterionConfirmation() throws {
        let (f, store) = try setup(); try frame(f, store)
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let before = try XCTUnwrap(store.loadCase(id: f.request.caseID)), e = before.caseEvaluations[0]
        XCTAssertThrowsError(try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: e.id, checkedCriterionIDs: Set(e.criterionEvaluationIDs), explicitConfirmation: false, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date))
        XCTAssertThrowsError(try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: e.id, checkedCriterionIDs: [], explicitConfirmation: true, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date))
        XCTAssertEqual(CaseGraphDTO(before), CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
    }
    @MainActor func testFailureDuringFinalApprovalRollsBackAllCriterionReviews() throws {
        let (f, store) = try setup(); try frame(f, store)
        let cutoff = try DatedValue.instant(f.now, role: .evaluationCutoff)
        let snapshot = try store.startEvaluationSnapshot(caseID: f.request.caseID, cutoff: cutoff, reviewer: reviewer, at: date)
        let id = try XCTUnwrap(try store.researchReviewPlan(caseID: f.request.caseID).criterionIDs["criterion-1"])
        let unsupported = ManualAssessment(category: .fulfilled, rationale: try NonEmptyText("Synthetischer noch unbelegter Entwurf"), confidence: .high)
        let evaluation = try store.createEvaluationDraft(caseID: f.request.caseID, snapshotID: snapshot.id, cutoff: cutoff,
            criteria: [ManualCriterionAssessment(criterionRevisionID: id, assessment: unsupported)], overall: unsupported, facts: [], interpretations: [], reviewer: reviewer, at: date)
        let before = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID)))
        XCTAssertThrowsError(try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: evaluation.id,
            checkedCriterionIDs: Set(evaluation.criterionEvaluationIDs), explicitConfirmation: true, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date))
        XCTAssertEqual(before, CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
    }

    @MainActor func testFailedOriginalQuoteVerificationLeavesNoPartialRevision() throws {
        let (f, store) = try setup(), before = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID)))
        XCTAssertThrowsError(try store.reviewResearchOriginal(caseID: f.request.caseID, reviewer: reviewer, at: date))
        XCTAssertEqual(before, CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
    }
    @MainActor func testRejectedExcerptDiffersFromUnusedEvidence() throws {
        let (f, store) = try setup(), p = try store.researchReviewPlan(caseID: f.request.caseID), raw = try XCTUnwrap(p.record.bindings?.excerpts["e1"])
        try store.adoptResearchEvidence(caseID: f.request.caseID, key: "ev1", use: false, reviewer: reviewer, at: date)
        XCTAssertEqual(try store.researchReviewPlan(caseID: f.request.caseID).evidence[0].state, .notUsed)
        XCTAssertEqual(try store.loadCase(id: f.request.caseID)?.find(EntityID<SourceExcerpt>(raw))?.state, .unverified)
        try store.reviewResearchExcerpt(caseID: f.request.caseID, excerptID: EntityID<SourceExcerpt>(raw), reject: true, reviewer: reviewer, at: date)
        XCTAssertEqual(try store.researchReviewPlan(caseID: f.request.caseID).evidenceSources.first { $0.key == "e1" }?.state, .rejected)
    }
    @MainActor func testCriterionSelectionIsExplicitAndPreservesRejectedDraft() throws {
        let (f, store) = try setup(); try original(f, store)
        let before = try XCTUnwrap(store.loadCase(id: f.request.caseID)), id = before.criterionRevisions[0].id
        XCTAssertThrowsError(try store.confirmResearchFrame(caseID: f.request.caseID, contextText: NonEmptyText("Synthetischer Kontext"), reviewer: reviewer, at: date))
        try store.selectResearchCriterion(caseID: f.request.caseID, key: "criterion-1", use: false, reviewer: reviewer, at: date)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertEqual(graph.find(id), before.find(id)); XCTAssertFalse(graph.cases[0].activeCriterionRevisionIDs.contains(id))
        XCTAssertEqual(graph.researchTasks, before.researchTasks)
        XCTAssertEqual(try store.researchReviewPlan(caseID: f.request.caseID).criteria[0].state, .notUsed)
    }
    @MainActor func testRejectedSecondCriterionDoesNotEnterSnapshot() throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        let result = try f.result { object in
            var criteria = object["proposedCriteria"] as! [[String: Any]], second = criteria[0]
            second["criterionKey"] = "criterion-2"; second["goal"] = "Synthetischer zweiter Zielzustand"; criteria.append(second); object["proposedCriteria"] = criteria
            var coverage = object["coverage"] as! [[String: Any]], c = coverage[0]; c["criterionKey"] = "criterion-2"; coverage.append(c); object["coverage"] = coverage
            var assessments = object["criterionAssessmentDrafts"] as! [[String: Any]], a = assessments[0]; a["criterionKey"] = "criterion-2"; assessments.append(a); object["criterionAssessmentDrafts"] = assessments
            var overall = object["overallAssessmentDraft"] as! [String: Any]; overall["criterionAssessmentKeys"] = ["criterion-1","criterion-2"]; object["overallAssessmentDraft"] = overall
        }
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record(result)); try original(f, store)
        let before = try XCTUnwrap(store.loadCase(id: f.request.caseID)), rejected = try XCTUnwrap(try store.researchReviewPlan(caseID: f.request.caseID).criterionIDs["criterion-2"])
        try store.selectResearchCriterion(caseID: f.request.caseID, key: "criterion-2", use: false, reviewer: reviewer, at: date)
        try store.selectResearchCriterion(caseID: f.request.caseID, key: "criterion-1", use: true, reviewer: reviewer, at: date)
        try store.confirmResearchFrame(caseID: f.request.caseID, contextText: NonEmptyText("Synthetischer Kontext"), reviewer: reviewer, at: date)
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertEqual(graph.caseRevisions[0].criteria.count, 1); XCTAssertFalse(graph.caseRevisions[0].criteria.contains { $0.id == rejected })
        XCTAssertEqual(graph.find(rejected), before.find(rejected)); XCTAssertEqual(graph.researchTasks, before.researchTasks)
    }
    @MainActor func testOmittedCounterEvidenceRequiresConsciousAcknowledgement() throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        let result = try f.result { object in
            var links = object["evidenceProposals"] as! [[String: Any]], counter = links[0]
            counter["evidenceKey"] = "counter-1"; counter["relationship"] = "contradicts"; links.append(counter); object["evidenceProposals"] = links
        }
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record(result)); try frame(f, store)
        XCTAssertFalse(try store.researchReviewPlan(caseID: f.request.caseID).warnings.isEmpty)
        let before = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID)))
        XCTAssertThrowsError(try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date))
        XCTAssertEqual(before, CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.request.caseID))))
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: true, reviewer: reviewer, at: date)
        let evaluation = try XCTUnwrap(store.loadCase(id: f.request.caseID)?.caseEvaluations.first)
        XCTAssertThrowsError(try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: evaluation.id, checkedCriterionIDs: Set(evaluation.criterionEvaluationIDs), explicitConfirmation: true, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date))
    }
    @MainActor func testFinalNegativeUsesOnlyHumanVerifiedCounterEvidence() throws {
        let f = try DeepResearchFixture(), store = try LocalCaseStore.inMemory()
        let result = try f.result { object in
            var link = (object["evidenceProposals"] as! [[String: Any]])[0]; link["relationship"] = "contradicts"; object["evidenceProposals"] = [link]
            var row = (object["criterionAssessmentDrafts"] as! [[String: Any]])[0]; row["suggestedCategory"] = "contraryAction"; row["confidence"] = "high"
            row["supportingEvidenceKeys"] = []; row["counterEvidenceKeys"] = ["ev1"]; object["criterionAssessmentDrafts"] = [row]
            var overall = object["overallAssessmentDraft"] as! [String: Any]; overall["suggestedCategory"] = "contraryAction"; overall["confidence"] = "high"; object["overallAssessmentDraft"] = overall
        }
        try store.saveCase(f.graph); try store.saveCaseResearch(f.record(result)); try evidence(f, store)
        try store.materializeResearchAssessment(caseID: f.request.caseID, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let draft = try XCTUnwrap(store.loadCase(id: f.request.caseID)), e = draft.caseEvaluations[0]
        try store.approveResearchEvaluation(caseID: f.request.caseID, evaluationID: e.id, checkedCriterionIDs: Set(e.criterionEvaluationIDs), explicitConfirmation: true, acknowledgeOmittedCounterEvidence: false, reviewer: reviewer, at: date)
        let graph = try XCTUnwrap(store.loadCase(id: f.request.caseID))
        XCTAssertEqual(graph.caseEvaluations[0].category, .contraryAction)
        let ids = graph.criterionEvaluations[0].counterEvidenceLinkIDs
        XCTAssertEqual(ids.count, 1); XCTAssertTrue(ids.allSatisfy { graph.find($0)?.status == .verified && graph.find($0)?.review?.reviewerID == reviewer.id })
        XCTAssertEqual(graph.evidenceLinks[0].status, .draft)
    }

    func testAllCategoriesMapExplicitlyWithoutDefaults() throws {
        let pairs: [(ResearchCategory, EvaluationCategory)] = [(.fulfilled,.fulfilled),(.mostlyFulfilled,.mostlyFulfilled),(.partiallyFulfilled,.partiallyFulfilled),(.notFulfilled,.notFulfilled),(.contraryAction,.contraryAction),(.notVerifiable,.notVerifiable)]
        for (input, expected) in pairs { XCTAssertEqual(try ResearchAssessmentMapping.assessment(category: input, confidence: .medium, rationale: "Synthetische Begründung", uncertainties: [], reasons: [.missingEvidence]).category, expected) }
        XCTAssertThrowsError(try ResearchAssessmentMapping.assessment(category: nil, confidence: .low, rationale: "Keine Empfehlung", uncertainties: [], reasons: []))
    }
    func testEveryNotVerifiableReasonMapsExplicitly() {
        let pairs: [(ResearchNotVerifiableReason, NotVerifiableReason)] = [(.unclearPromise,.unclearPromise),(.openDeadline,.openDeadline),(.conditionNotMet,.conditionNotMet),(.missingEvidence,.missingEvidence),(.unclearAttribution,.unclearAttribution),(.conflictingSources,.conflictingSources),(.researchBlocked,.researchBlocked)]
        for (a,b) in pairs { XCTAssertEqual(ResearchAssessmentMapping.reason(a), b) }
    }
    @MainActor func testStaleCriterionBlocksPlanRatherThanGuessing() throws {
        let (f, store) = try setup(); try evidence(f, store)
        let plan = try store.researchReviewPlan(caseID: f.request.caseID), id = try XCTUnwrap(plan.criterionIDs["criterion-1"])
        try store.reviseCriterion(caseID: f.request.caseID, revisionID: id, goal: NonEmptyText("Synthetisch geändertes Ziel"), reason: NonEmptyText("Manuelle Änderung"), requestedBy: reviewer.id, at: date, confirmation: HumanReview(reviewerID: reviewer.id, reviewedAt: date))
        XCTAssertThrowsError(try store.researchReviewPlan(caseID: f.request.caseID))
    }
}
