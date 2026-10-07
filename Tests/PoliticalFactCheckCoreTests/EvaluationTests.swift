import XCTest
@testable import PoliticalFactCheckCore

final class EvaluationTests: XCTestCase {
    func testApprovedFulfilmentWithoutSupportingEvidenceIsRejected() throws {
        let f = try Fixture(includeEvidence: false)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.positiveJudgmentRequiresSupportingEvidence))
    }
    func testCompleteSyntheticGraphIsValid() throws {
        let f = try Fixture()
        let result = DomainValidator.validate(f.context())
        XCTAssertTrue(result.isValid, "\(result.errors)")
    }
    func testNotFulfilledWithoutEvidenceIsRejected() throws {
        let f = try Fixture(includeEvidence: false, category: .notFulfilled)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.emptyEvidenceForNegativeJudgment))
    }
    func testContraryActionWithoutContradictingEvidenceIsRejected() throws {
        let f = try Fixture(category: .contraryAction)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.contraryActionRequiresContradictingEvidence))
    }
    func testContraryActionWithVerifiedContradictingEvidenceCanBeValid() throws {
        let f = try Fixture(relationship: .contradicts, category: .contraryAction)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).isValid)
    }
    func testUnverifiedLinkCannotSupportContraryAction() throws {
        let f = try Fixture(linkStatus: .draft, relationship: .contradicts, category: .contraryAction)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.evidenceLinkNotVerified(f.evidence.id)))
    }
    func testNotVerifiableNeedsExplicitStructuredReason() throws {
        let f = try Fixture(includeEvidence: false, category: .notVerifiable)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.missingNotVerifiableReason))
    }
    func testNotVerifiableWithReasonAndNoEvidenceIsPossible() throws {
        let f = try Fixture(includeEvidence: false, category: .notVerifiable, confidence: .low, reasons: [.missingEvidence])
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).isValid)
    }
    func testApprovedNotFulfilledWithLowConfidenceIsRejected() throws {
        let f = try Fixture(category: .notFulfilled, confidence: .low)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.lowConfidenceNegativeJudgment))
    }
    func testApprovedContraryActionWithLowConfidenceIsRejected() throws {
        let f = try Fixture(relationship: .contradicts, category: .contraryAction, confidence: .low)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.lowConfidenceNegativeJudgment))
    }
    func testLowConfidenceNegativeDraftIsNotFinalApproval() throws {
        let f = try Fixture(category: .notFulfilled, confidence: .low, status: .draft, hasApproval: false)
        XCTAssertFalse(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.lowConfidenceNegativeJudgment))
    }
    func testApprovedEvaluationWithoutReviewerIsRejected() throws {
        let f = try Fixture(hasApproval: false)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.missingHumanReview))
    }
    func testDanglingHumanReviewerIDIsRejected() throws {
        let f = try Fixture()
        let unknownReview = HumanReview(reviewerID: .init(), reviewedAt: f.approval.reviewedAt)
        let forged = f.evaluation.replacingLifecycle(status: .approved, approval: unknownReview, reviewReason: nil)
        XCTAssertTrue(DomainValidator.validate(forged, in: f.context()).errors.contains(
            .missingReference(ObjectReference(kind: .reviewer, id: unknownReview.reviewerID))))
    }
    func testDuplicateCriterionEvaluationIsRejected() throws {
        let f = try Fixture()
        let duplicate = CaseEvaluation(caseID: f.politicalCase.id, caseRevisionID: f.snapshot.id, cutoff: f.evaluation.cutoff,
            methodologyVersionID: f.methodology.id, criterionEvaluationIDs: [f.criterionEvaluation.id, f.criterionEvaluation.id],
            category: .fulfilled, rationale: text("Synthetic duplicate"), confidence: .high, metadata: f.evaluation.metadata)
        XCTAssertFalse(DomainValidator.validate(duplicate, in: f.context()).isValid)
    }
    func testResearchBlockIsNotNonFulfilment() throws {
        let f = try Fixture(includeEvidence: false, category: .notVerifiable, confidence: .low, reasons: [.researchBlocked])
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).isValid)
        XCTAssertEqual(f.evaluation.category, .notVerifiable)
    }
    func testContextOnlyLinksDoNotProveNonFulfilment() throws {
        let f = try Fixture(relationship: .contextualizes, category: .notFulfilled)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.emptyEvidenceForNegativeJudgment))
    }
}
