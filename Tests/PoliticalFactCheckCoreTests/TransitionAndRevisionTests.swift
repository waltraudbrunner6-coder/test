import Foundation
import XCTest
@testable import PoliticalFactCheckCore

final class TransitionAndRevisionTests: XCTestCase {
    func testHistoricalActionUsesCapturedExcerptVerification() throws {
        let f = try Fixture(includeAction: true)
        let superseded = f.excerpt.replacingLifecycle(state: .superseded, review: f.review)
        let result = DomainValidator.validate(f.evaluation, in: f.context(excerptOverride: superseded))
        XCTAssertTrue(result.isValid, "\(result.errors)")
    }
    func testUnverifiedCandidateDoesNotTriggerNewEvidenceWorkflow() throws {
        let f = try Fixture(linkStatus: .draft)
        XCTAssertThrowsError(try DomainChanges.addingEvidence(f.evidence,
            reason: text("Unreviewed synthetic candidate"), in: f.context()))
    }
    func testHistoricalApprovalKeepsCapturedExcerptStatusAfterSupersession() throws {
        let f = try Fixture()
        let superseded = f.excerpt.replacingLifecycle(state: .superseded, review: f.review)
        let result = DomainValidator.validate(f.evaluation, in: f.context(excerptOverride: superseded))
        XCTAssertTrue(result.isValid, "\(result.errors)")
        XCTAssertEqual(f.snapshot.excerpts.first?.state, .verified)
    }
    func testSnapshotCannotFalselyDeclareDraftCriterionConfirmed() throws {
        let f = try Fixture(criterionState: .draft)
        let falseSnapshot = CaseRevision(caseID: f.politicalCase.id, promiseRevisionID: f.promiseRevision.id,
            criteria: [.init(id: f.criterionRevision.id, state: .confirmed)], metadata: f.snapshot.metadata)
        XCTAssertTrue(DomainValidator.validate(falseSnapshot, in: f.context()).errors.contains(.criterionNotConfirmed(f.criterionRevision.id)))
    }
    func testSnapshotRequiresItsReferencedSourceVersion() throws {
        let f = try Fixture()
        let incomplete = CaseRevision(caseID: f.politicalCase.id, promiseRevisionID: f.promiseRevision.id,
            criteria: f.snapshot.criteria, excerpts: f.snapshot.excerpts, metadata: f.snapshot.metadata)
        XCTAssertTrue(DomainValidator.validate(incomplete, in: f.context()).errors.contains(
            .snapshotMismatch(ObjectReference(kind: .sourceVersion, id: f.sourceVersion.id))))
    }
    func testOnlyAdjacentCaseTransitionsAreAllowed() throws {
        let states: [CaseWorkflowState] = [.candidate, .documented, .verified, .readyForEvaluation, .evaluated, .approved]
        for (i, from) in states.enumerated() {
            for (j, to) in states.enumerated() {
                if j == i + 1 { XCTAssertNoThrow(try TransitionRules.validate(from, to: to)) }
                else { XCTAssertThrowsError(try TransitionRules.validate(from, to: to)) }
            }
        }
    }
    func testConfirmedCriterionCannotReturnToDraft() {
        XCTAssertThrowsError(try TransitionRules.validate(CriterionRevisionState.confirmed, to: .draft))
    }
    func testDraftToConfirmedCriterionIsAllowed() throws {
        let f = try Fixture(criterionState: .draft)
        let confirmed = try DomainChanges.transition(f.criterionRevision, to: .confirmed, review: f.review, in: f.context())
        XCTAssertEqual(confirmed.state, .confirmed)
        XCTAssertEqual(confirmed.id, f.criterionRevision.id)
        XCTAssertEqual(f.criterionRevision.state, .draft)
    }
    func testConfirmingCriterionRequiresHumanConfirmation() throws {
        let f = try Fixture(criterionState: .draft)
        XCTAssertThrowsError(try DomainChanges.transition(f.criterionRevision, to: .confirmed, in: f.context()))
    }
    func testConfirmedToSupersededPreservesCriterionContent() throws {
        let f = try Fixture()
        let superseded = try DomainChanges.transition(f.criterionRevision, to: .superseded, in: f.context())
        XCTAssertEqual(superseded.goal, f.criterionRevision.goal)
        XCTAssertEqual(superseded.confirmation, f.criterionRevision.confirmation)
    }
    func testExcerptTransitionDoesNotRewriteOriginal() throws {
        let f = try Fixture(excerptState: .unverified, excerptReview: false)
        let verified = try DomainChanges.transition(f.excerpt, to: .verified, review: f.review, in: f.context())
        XCTAssertEqual(verified.state, .verified)
        XCTAssertEqual(verified.text, f.excerpt.text)
        XCTAssertEqual(f.excerpt.state, .unverified)
    }
    func testExcerptRejectionIsAllowedOnlyFromUnverified() {
        XCTAssertNoThrow(try TransitionRules.validate(ExcerptVerificationState.unverified, to: .rejected))
        XCTAssertThrowsError(try TransitionRules.validate(ExcerptVerificationState.verified, to: .rejected))
        XCTAssertThrowsError(try TransitionRules.validate(ExcerptVerificationState.superseded, to: .verified))
    }
    func testEvaluationCannotSkipReview() {
        XCTAssertThrowsError(try TransitionRules.validate(EvaluationStatus.draft, to: .approved))
        XCTAssertNoThrow(try TransitionRules.validate(EvaluationStatus.draft, to: .needsReview))
        XCTAssertThrowsError(try TransitionRules.validate(EvaluationStatus.approved, to: .draft))
    }
    func testNeedsReviewToApprovedChecksHumanReviewer() throws {
        let f = try Fixture(status: .needsReview, hasApproval: false)
        XCTAssertThrowsError(try DomainChanges.transition(f.evaluation, to: .approved, in: f.context()))
        let approved = try DomainChanges.transition(f.evaluation, to: .approved, approval: f.approval, in: f.context())
        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(f.evaluation.status, .needsReview)
    }
    func testReadyForEvaluationRejectsUnconfirmedActiveCriteria() throws {
        let f = try Fixture(criterionState: .draft)
        let verifiedCase = f.politicalCase.replacingLifecycle(workflowState: .verified, modifiedAt: Fixture.creation)
        XCTAssertThrowsError(try DomainChanges.transition(verifiedCase, to: .readyForEvaluation, at: Fixture.creation, in: f.context()))
    }
    func testCompleteCaseWorkflowCanAdvance() throws {
        let f = try Fixture()
        var current = f.politicalCase
        let remaining: [CaseWorkflowState] = [.documented, .verified, .readyForEvaluation, .evaluated, .approved]
        for next in remaining {
            current = try DomainChanges.transition(current, to: next, at: Fixture.creation, in: f.context())
        }
        XCTAssertEqual(current.workflowState, .approved)
        XCTAssertEqual(f.politicalCase.workflowState, .candidate)
    }
    func testNewCriterionRevisionDoesNotChangeOldSnapshot() throws {
        let f = try Fixture()
        let oldSnapshot = f.snapshot
        let change = try DomainChanges.revise(f.criterionRevision, goal: text("Revised synthetic goal"),
            reason: text("Clarify synthetic scope"), author: .human(f.reviewer.id),
            at: Fixture.creation.addingTimeInterval(5 * 86_400), in: f.context())
        XCTAssertNotEqual(change.revision.id, f.criterionRevision.id)
        XCTAssertEqual(change.revision.criterionID, f.criterionRevision.criterionID)
        XCTAssertEqual(change.revision.state, .draft)
        XCTAssertNil(change.revision.confirmation)
        XCTAssertEqual(change.revision.metadata.number, 2)
        XCTAssertEqual(f.snapshot, oldSnapshot)
        XCTAssertEqual(f.snapshot.criteria.first?.id, f.criterionRevision.id)
        XCTAssertEqual(change.reviewRequests.map { $0.evaluationID }, [f.evaluation.id])
        XCTAssertEqual(change.evaluationUpdates.first?.status, .reviewRequired)
    }
    func testChangedCriteriaMarkDependentApprovalForReviewWithoutChangingGrade() throws {
        let f = try Fixture()
        let change = try DomainChanges.revise(f.criterionRevision, goal: text("Another synthetic goal"),
            reason: text("Synthetic change"), author: .human(f.reviewer.id), at: Fixture.creation, in: f.context())
        let request = try XCTUnwrap(change.reviewRequests.first)
        let reviewed = try DomainChanges.apply(request, to: f.evaluation, in: f.context())
        XCTAssertEqual(reviewed.status, .reviewRequired)
        XCTAssertEqual(reviewed.category, f.evaluation.category)
        XCTAssertEqual(reviewed.caseRevisionID, f.snapshot.id)
        XCTAssertEqual(f.evaluation.status, .approved)
    }
    func testNewEvidenceDoesNotOverwriteHistoricalEvaluation() throws {
        let f = try Fixture()
        let historical = f.evaluation
        let newEvidence = EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [f.excerpt.id],
            relationship: .contextualizes, directness: .indirect, rationale: text("Synthetic additional context"),
            temporalReference: f.evidence.temporalReference, status: .verified, review: f.review, metadata: f.evidence.metadata)
        let requests = try DomainChanges.reviewImpact(of: newEvidence, reason: text("Synthetic new evidence"), in: f.context())
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(f.evaluation, historical)
        XCTAssertFalse(f.snapshot.evidenceLinks.contains(where: { $0.id == newEvidence.id }))
        let change = try DomainChanges.addingEvidence(newEvidence, reason: text("Synthetic new evidence"), in: f.context())
        XCTAssertEqual(change.evaluationUpdates.first?.status, .reviewRequired)
        XCTAssertEqual(change.evaluationUpdates.first?.category, historical.category)
    }
    func testHistoricalIDsRemainStableAcrossReviewStatusChanges() throws {
        let f = try Fixture()
        let reviewed = try DomainChanges.transition(f.evaluation, to: .reviewRequired, reason: text("Synthetic review"), in: f.context())
        let superseded = try DomainChanges.transition(reviewed, to: .superseded, in: f.context())
        XCTAssertEqual(superseded.id, f.evaluation.id)
        XCTAssertEqual(superseded.caseRevisionID, f.snapshot.id)
        XCTAssertEqual(superseded.approval, f.evaluation.approval)
    }
    func testSameIDCannotReplaceConfirmedCriterionContent() throws {
        let f = try Fixture()
        let original = f.criterionRevision
        let changed = CriterionRevision(id: original.id, criterionID: original.criterionID,
            promiseRevisionID: original.promiseRevisionID, goal: text("Attempted overwrite"), targetGroup: original.targetGroup,
            baseline: original.baseline, deadline: original.deadline, conditions: original.conditions,
            isCore: original.isCore, materialityRule: original.materialityRule, metadata: original.metadata,
            state: original.state, confirmation: original.confirmation)
        XCTAssertThrowsError(try RevisionRules.validateReplacement(original, with: changed))
    }
    func testSameIDCannotReplaceApprovedEvaluationGrade() throws {
        let f = try Fixture()
        let changed = CaseEvaluation(id: f.evaluation.id, caseID: f.evaluation.caseID, caseRevisionID: f.snapshot.id,
            cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id,
            criterionEvaluationIDs: f.evaluation.criterionEvaluationIDs, category: .notFulfilled,
            rationale: f.evaluation.rationale, confidence: f.evaluation.confidence, metadata: f.evaluation.metadata,
            status: .approved, approval: f.approval)
        XCTAssertThrowsError(try RevisionRules.validateReplacement(f.evaluation, with: changed))
    }
}
