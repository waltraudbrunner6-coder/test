import Foundation
import XCTest
@testable import PoliticalFactCheckCore

final class ManualEvaluationTests: XCTestCase {
    func testCanonicalMethodologyHasStableIdentityVersionAndReference() throws {
        let a = try MethodologyV1.version(), b = try MethodologyV1.version()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.version.value, "1.0")
        XCTAssertTrue(a.contentReference.value.contains("docs/methodology-v1.0.md"))
        XCTAssertEqual(a.hash?.sha256.count, 64)
    }
    func testSnapshotRequiresReadyWorkflow() throws {
        let f = try Fixture()
        for state in [CaseWorkflowState.candidate, .documented, .verified] {
            let root = f.politicalCase.replacingLifecycle(workflowState: state, modifiedAt: manualTime)
            XCTAssertThrowsError(try DomainChanges.evaluationSnapshot(root, cutoff: manualCutoff(), review: f.review,
                at: manualTime, in: manualGraph(f))) { XCTAssertEqual($0 as? DomainValidationError, .evaluationRequiresReadyCase) }
        }
    }
    func testSnapshotContainsCurrentPromiseAndExactlyActiveConfirmedCriteria() throws {
        let f = try Fixture(), g = manualGraph(f)
        let snapshot = try makeSnapshot(f, g)
        XCTAssertEqual(snapshot.promiseRevisionID, g.cases[0].currentPromiseRevisionID)
        XCTAssertEqual(snapshot.criteria.map { $0.id }, g.cases[0].activeCriterionRevisionIDs)
        XCTAssertTrue(snapshot.criteria.allSatisfy { $0.state == .confirmed })
        XCTAssertTrue(DomainValidator.validate(snapshot, in: g).isValid)
    }
    func testSnapshotIncludesVerifiedEvidenceAndExcludesDraftNeedsReviewRejected() throws {
        for status in [EvidenceLinkStatus.draft, .needsReview, .rejected, .verified] {
            let f = try Fixture(linkStatus: status), g = manualGraph(f)
            let snapshot = try makeSnapshot(f, g)
            XCTAssertEqual(snapshot.evidenceLinks.map { $0.id }, status == .verified ? [f.evidence.id] : [])
            XCTAssertTrue(snapshot.evidenceLinks.allSatisfy { $0.state == .verified })
        }
    }
    func testSnapshotIncludesSourcesExcerptsAndReferencedActionClosure() throws {
        let f = try Fixture(includeAction: true), g = manualGraph(f)
        let snapshot = try makeSnapshot(f, g)
        XCTAssertEqual(snapshot.sourceVersions.map { $0.id }, [f.sourceVersion.id])
        XCTAssertEqual(snapshot.excerpts.map { $0.id }, [f.excerpt.id])
        XCTAssertEqual(snapshot.actionRevisionIDs, [f.actionRevision.id])
        XCTAssertTrue(DomainValidator.validate(snapshot, in: g).isValid)
    }
    func testSnapshotRejectsMissingHumanReviewer() throws {
        let f = try Fixture(), g = manualGraph(f)
        XCTAssertThrowsError(try DomainChanges.evaluationSnapshot(g.cases[0], cutoff: manualCutoff(),
            review: HumanReview(reviewerID: .init(), reviewedAt: manualTime), at: manualTime, in: g))
    }
    func testSnapshotRequiresEvaluationCutoffRoleAndExplicitValue() throws {
        let f = try Fixture(), g = manualGraph(f)
        XCTAssertThrowsError(try DomainChanges.evaluationSnapshot(g.cases[0], cutoff: .instant(Fixture.cutoff, role: .publication),
            review: f.review, at: manualTime, in: g))
        XCTAssertThrowsError(try DomainChanges.evaluationSnapshot(g.cases[0], cutoff: .unknown(role: .evaluationCutoff, reason: text("Synthetic absent date")),
            review: f.review, at: manualTime, in: g))
    }
    func testSnapshotCannotChangeUnderSameID() throws {
        let f = try Fixture(), g = manualGraph(f)
        let old = try makeSnapshot(f, g)
        let changed = CaseRevision(id: old.id, caseID: old.caseID, promiseRevisionID: old.promiseRevisionID,
            criteria: old.criteria, sourceVersions: old.sourceVersions, excerpts: old.excerpts, metadata: old.metadata)
        XCTAssertThrowsError(try RevisionRules.validateReplacement(old, with: changed))
        XCTAssertEqual(old.evidenceLinks.map { $0.id }, [f.evidence.id])
    }
    func testDraftHasExactlyOneUnreviewedChildPerCriterionAndExplicitOverallValues() throws {
        let f = try Fixture(), pair = try draftPair(f)
        let draft = pair.draft
        XCTAssertEqual(draft.evaluation.status, .draft)
        XCTAssertNil(draft.evaluation.approval)
        XCTAssertNil(draft.evaluation.replacesEvaluationID)
        XCTAssertEqual(draft.criteria.count, 1)
        XCTAssertEqual(draft.criteria[0].criterionRevisionID, f.criterionRevision.id)
        XCTAssertEqual(draft.criteria[0].reviewState, .unreviewed)
        XCTAssertNil(draft.criteria[0].review)
        XCTAssertEqual(draft.evaluation.methodologyVersionID, try MethodologyV1.version().id)
        XCTAssertEqual(draft.evaluation.caseRevisionID, pair.snapshot.id)
        XCTAssertEqual(draft.evaluation.cutoff.role, .evaluationCutoff)
        XCTAssertEqual(draft.politicalCase.workflowState, .evaluated)
    }
    func testDraftRejectsMissingOrDuplicateCriterionAssessments() throws {
        let f = try Fixture(), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        let ready = g.withEvaluations(snapshots: [snapshot])
        for inputs in [[], [manualInput(f), manualInput(f)]] {
            XCTAssertThrowsError(try buildDraft(f, ready, snapshot, inputs: inputs))
        }
    }
    func testDraftRejectsEvidenceOfAnotherCriterionOrMissingEvidenceID() throws {
        let f = try Fixture(), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        let input = ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id,
            assessment: manualAssessment(), evidenceLinkIDs: [.init()])
        XCTAssertThrowsError(try buildDraft(f, g.withEvaluations(snapshots: [snapshot]), snapshot, inputs: [input]))
    }
    func testCounterEvidenceMustBeSubsetOfUsedEvidence() throws {
        let f = try Fixture(), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        let input = ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id,
            assessment: manualAssessment(), counterEvidenceLinkIDs: [f.evidence.id])
        XCTAssertThrowsError(try buildDraft(f, g.withEvaluations(snapshots: [snapshot]), snapshot, inputs: [input]))
    }
    func testNotVerifiableNeedsStructuredReason() throws {
        let f = try Fixture(), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        XCTAssertThrowsError(try buildDraft(f, g.withEvaluations(snapshots: [snapshot]), snapshot,
            assessment: manualAssessment(category: .notVerifiable)))
    }
    func testNotVerifiableWithReasonAndNoEvidenceCanBeReviewedAndApproved() throws {
        let f = try Fixture(), pair = try draftPair(f, assessment: manualAssessment(category: .notVerifiable, reasons: [.missingEvidence]), usedEvidence: false)
        let approved = try approveDraft(pair, f)
        XCTAssertEqual(approved.status, .approved)
        XCTAssertEqual(approved.category, .notVerifiable)
    }
    func testNotFulfilledWithoutRelevantEvidenceIsRejected() throws {
        let f = try Fixture(relationship: .contextualizes), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        XCTAssertThrowsError(try buildDraft(f, g.withEvaluations(snapshots: [snapshot]), snapshot, assessment: manualAssessment(category: .notFulfilled)))
    }
    func testContraryActionWithoutContradictsIsRejected() throws {
        let f = try Fixture(), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        XCTAssertThrowsError(try buildDraft(f, g.withEvaluations(snapshots: [snapshot]), snapshot, assessment: manualAssessment(category: .contraryAction)))
    }
    func testPositiveFinalJudgmentWithoutSupportsIsRejected() throws {
        let f = try Fixture(relationship: .contextualizes)
        for category in [EvaluationCategory.fulfilled, .mostlyFulfilled, .partiallyFulfilled] {
            let pair = try draftPair(f, assessment: manualAssessment(category: category))
            XCTAssertThrowsError(try approveDraft(pair, f))
        }
    }
    func testLowConfidenceFinalNegativeJudgmentsAreRejected() throws {
        let f = try Fixture(relationship: .contradicts)
        for category in [EvaluationCategory.notFulfilled, .contraryAction] {
            let pair = try draftPair(f, assessment: manualAssessment(category: category, confidence: .low))
            XCTAssertThrowsError(try approveDraft(pair, f))
        }
    }
    func testNotFulfilledWithOpenDeadlineIsRejected() throws {
        let f = try Fixture(relationship: .contradicts), g = manualGraph(f), snapshot = try makeSnapshot(f, g)
        XCTAssertThrowsError(try DomainChanges.manualEvaluationDraft(g.cases[0], snapshotID: snapshot.id,
            cutoff: .instant(Fixture.event.addingTimeInterval(-86_400), role: .evaluationCutoff),
            criteria: [manualInput(f, assessment: manualAssessment(category: .notFulfilled))],
            overall: manualAssessment(category: .notFulfilled), facts: [], interpretations: [], reviewerID: f.reviewer.id,
            at: manualTime, in: g.withEvaluations(snapshots: [snapshot])))
        let child = CriterionEvaluation(caseEvaluationID: .init(), criterionRevisionID: f.criterionRevision.id,
            category: .notFulfilled, rationale: text("Synthetic negative assessment"), evidenceLinkIDs: [f.evidence.id], confidence: .high)
        let result = DomainValidator.validate(child, snapshot: snapshot,
            cutoff: try .instant(Fixture.event.addingTimeInterval(-86_400), role: .evaluationCutoff), final: false, in: g)
        XCTAssertTrue(result.errors.contains(.deadlineNotPassed))
    }
    func testCriterionReviewIsExplicitAndPreservesContent() throws {
        let f = try Fixture(), pair = try draftPair(f), old = pair.draft.criteria[0]
        let review = HumanReview(reviewerID: f.reviewer.id, reviewedAt: manualTime.addingTimeInterval(1))
        let next = try DomainChanges.reviewCriterionEvaluation(old, review: review, in: pair.graph)
        XCTAssertEqual(next.reviewState, .reviewed)
        XCTAssertEqual(next.review, review)
        XCTAssertEqual(next.withReview(state: .unreviewed, review: nil), old)
        XCTAssertThrowsError(try DomainChanges.reviewCriterionEvaluation(next, review: review, in: pair.graph))
    }
    func testCriterionReviewRejectsUnknownReviewerAndEarlierTime() throws {
        let f = try Fixture(), pair = try draftPair(f)
        for review in [HumanReview(reviewerID: .init(), reviewedAt: manualTime),
                       HumanReview(reviewerID: f.reviewer.id, reviewedAt: manualTime.addingTimeInterval(-1))] {
            XCTAssertThrowsError(try DomainChanges.reviewCriterionEvaluation(pair.draft.criteria[0], review: review, in: pair.graph))
        }
    }
    func testDraftToReviewIsAllowedButDirectApprovalIsForbidden() throws {
        let f = try Fixture(), pair = try draftPair(f)
        XCTAssertEqual(try DomainChanges.transition(pair.draft.evaluation, to: .needsReview, in: pair.graph).status, .needsReview)
        XCTAssertThrowsError(try DomainChanges.transition(pair.draft.evaluation, to: .approved, approval: f.approval, in: pair.graph))
    }
    func testApprovalNeedsHumanAndReviewedChildren() throws {
        let f = try Fixture(), pair = try draftPair(f)
        let pending = try DomainChanges.transition(pair.draft.evaluation, to: .needsReview, in: pair.graph)
        XCTAssertThrowsError(try DomainChanges.transition(pending, to: .approved, in: pair.graph))
        XCTAssertThrowsError(try DomainChanges.transition(pending, to: .approved,
            approval: HumanReview(reviewerID: f.reviewer.id, reviewedAt: manualTime), in: pair.graph))
        XCTAssertThrowsError(try DomainChanges.transition(pending, to: .approved,
            approval: HumanReview(reviewerID: .init(), reviewedAt: manualTime), in: pair.graph))
    }
    func testApprovalPreservesAllContentAndEnablesCaseApprovedMilestone() throws {
        let f = try Fixture(), pair = try draftPair(f), approved = try approveDraft(pair, f)
        XCTAssertEqual(approved.replacingLifecycle(status: .draft, approval: nil, reviewReason: nil), pair.draft.evaluation)
        let reviewed = try reviewedGraph(pair, f)
        let g = reviewed.withEvaluations(evaluations: [approved])
        let root = try DomainChanges.transition(pair.draft.politicalCase, to: .approved, at: manualTime.addingTimeInterval(3), in: g)
        XCTAssertEqual(root.workflowState, .approved)
        XCTAssertEqual(try CaseReviews.state(of: root, in: g), .upToDate)
    }
    func testRetrospectivePublicationRemainsWarningRatherThanExclusion() throws {
        let f = try Fixture(), pair = try draftPair(f)
        let result = DomainValidator.validate(pair.draft.evaluation, in: pair.graph)
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.warnings.contains(.retrospectivePublication(f.sourceVersion.id)))
    }
    func testOverallNotAutomaticallyAggregatedFromCriterionResult() throws {
        let f = try Fixture(), pair = try draftPair(f,
            overall: manualAssessment(category: .notVerifiable, reasons: [.unclearAttribution]))
        XCTAssertEqual(pair.draft.criteria[0].category, .fulfilled)
        XCTAssertEqual(pair.draft.evaluation.category, .notVerifiable)
    }
    func testPartyIdentityDoesNotChangeEvaluationRules() throws {
        for name in ["Synthetic Group Delta", "Synthetic Group Epsilon"] {
            let f = try Fixture(partyName: name), pair = try draftPair(f)
            XCTAssertTrue(DomainValidator.validate(pair.draft.evaluation, in: pair.graph).isValid)
            XCTAssertEqual(try approveDraft(pair, f).category, .fulfilled)
        }
    }
}

private let manualTime = Fixture.creation.addingTimeInterval(6 * 86_400)
private func manualCutoff() throws -> DatedValue { try .instant(Fixture.cutoff, role: .evaluationCutoff) }
private func manualGraph(_ f: Fixture) -> DomainContext {
    f.context().withEvaluations(cases: [f.politicalCase.replacingLifecycle(workflowState: .readyForEvaluation, modifiedAt: manualTime)],
        snapshots: [], criteria: [], evaluations: [], methodologies: [try! MethodologyV1.version()])
}
private func manualAssessment(category: EvaluationCategory = .fulfilled, confidence: EvidenceConfidence = .high,
                              reasons: [NotVerifiableReason] = []) -> ManualAssessment {
    ManualAssessment(category: category, rationale: text("Synthetic human assessment"), confidence: confidence,
        uncertainties: [text("Synthetic explicitly considered limitation")], notVerifiableReasons: reasons)
}
private func manualInput(_ f: Fixture, assessment: ManualAssessment = manualAssessment(), used: Bool = true) -> ManualCriterionAssessment {
    ManualCriterionAssessment(criterionRevisionID: f.criterionRevision.id, assessment: assessment, evidenceLinkIDs: used ? [f.evidence.id] : [])
}
private func makeSnapshot(_ f: Fixture, _ g: DomainContext) throws -> CaseRevision {
    try DomainChanges.evaluationSnapshot(g.cases[0], cutoff: manualCutoff(), review: f.review, at: manualTime, in: g)
}
private func buildDraft(_ f: Fixture, _ g: DomainContext, _ s: CaseRevision,
    inputs: [ManualCriterionAssessment]? = nil, assessment: ManualAssessment = manualAssessment(),
    overall: ManualAssessment? = nil, usedEvidence: Bool = true) throws -> ManualEvaluationDraft {
    try DomainChanges.manualEvaluationDraft(g.cases[0], snapshotID: s.id, cutoff: manualCutoff(),
        criteria: inputs ?? [manualInput(f, assessment: assessment, used: usedEvidence)], overall: overall ?? assessment,
        facts: [text("Synthetic fact")], interpretations: [text("Synthetic interpretation")], reviewerID: f.reviewer.id, at: manualTime, in: g)
}
private struct DraftPair { let draft: ManualEvaluationDraft; let snapshot: CaseRevision; let graph: DomainContext }
private func draftPair(_ f: Fixture, assessment: ManualAssessment = manualAssessment(),
                       overall: ManualAssessment? = nil, usedEvidence: Bool = true) throws -> DraftPair {
    let g = manualGraph(f), s = try makeSnapshot(f, g), ready = g.withEvaluations(snapshots: [s])
    let draft = try buildDraft(f, ready, s, assessment: assessment, overall: overall, usedEvidence: usedEvidence)
    return DraftPair(draft: draft, snapshot: s,
        graph: ready.withEvaluations(cases: [draft.politicalCase], criteria: draft.criteria, evaluations: [draft.evaluation]))
}
private func reviewedGraph(_ pair: DraftPair, _ f: Fixture) throws -> DomainContext {
    let review = HumanReview(reviewerID: f.reviewer.id, reviewedAt: manualTime.addingTimeInterval(1))
    let children = try pair.draft.criteria.map { try DomainChanges.reviewCriterionEvaluation($0, review: review, in: pair.graph) }
    return pair.graph.withEvaluations(criteria: children)
}
private func approveDraft(_ pair: DraftPair, _ f: Fixture) throws -> CaseEvaluation {
    let g = try reviewedGraph(pair, f)
    let pending = try DomainChanges.transition(pair.draft.evaluation, to: .needsReview, in: g)
    return try DomainChanges.transition(pending, to: .approved,
        approval: HumanReview(reviewerID: f.reviewer.id, reviewedAt: manualTime.addingTimeInterval(2)), in: g)
}
