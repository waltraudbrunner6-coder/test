import Foundation
import XCTest
@testable import PoliticalFactCheckCore

final class CaseReviewTests: XCTestCase {
    private func approvedCase(_ f: Fixture, criteria: [EntityID<CriterionRevision>]? = nil) -> Case {
        Case(id: f.politicalCase.id, title: f.politicalCase.title, promiseID: f.promise.id,
            currentPromiseRevisionID: f.promiseRevision.id,
            activeCriterionRevisionIDs: criteria ?? [f.criterionRevision.id], workflowState: .approved,
            createdAt: Fixture.creation, modifiedAt: Fixture.creation)
    }

    private func context(_ f: Fixture, politicalCase: Case? = nil,
                         evaluations: [CaseEvaluation]? = nil, snapshots: [CaseRevision]? = nil,
                         criteria: [CriterionRevision]? = nil, links: [EvidenceLink]? = nil,
                         children: [CriterionEvaluation]? = nil) -> DomainContext {
        DomainContext(reviewers: [f.reviewer], cases: [politicalCase ?? approvedCase(f)], actors: [f.speaker, f.party],
            promises: [f.promise], promiseRevisions: [f.promiseRevision], criteria: [f.criterion],
            criterionRevisions: criteria ?? [f.criterionRevision], sources: [f.source],
            sourceVersions: [f.sourceVersion], excerpts: [f.excerpt], evidenceLinks: links ?? [f.evidence],
            caseRevisions: snapshots ?? [f.snapshot], criterionEvaluations: children ?? [f.criterionEvaluation],
            caseEvaluations: evaluations ?? [f.evaluation], methodologies: [f.methodology])
    }

    private func requiringReview(_ f: Fixture) throws -> CaseEvaluation {
        try DomainChanges.transition(f.evaluation, to: .reviewRequired,
            reason: text("Synthetic relevant information"), in: f.context())
    }

    private func additionalEvidence(_ f: Fixture) -> EvidenceLink {
        EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [f.excerpt.id],
            relationship: .contextualizes, directness: .direct, rationale: text("Synthetic new context"),
            temporalReference: f.evidence.temporalReference, status: .verified,
            review: HumanReview(reviewerID: f.reviewer.id, reviewedAt: Fixture.creation.addingTimeInterval(6 * 86_400)),
            metadata: RevisionMetadata(number: 1, reason: text("Synthetic new evidence"),
                author: .human(f.reviewer.id), createdAt: Fixture.creation.addingTimeInterval(5 * 86_400)))
    }

    private func replacement(_ f: Fixture, old: CaseEvaluation, links: [EvidenceLink],
                             status: EvaluationStatus = .approved, replaces: Bool = true)
        -> (CaseRevision, CriterionEvaluation, CaseEvaluation) {
        let id = EntityID<CaseEvaluation>()
        let metadata = RevisionMetadata(number: 2, reason: text("Synthetic reassessment"),
            author: .human(f.reviewer.id), createdAt: Fixture.creation.addingTimeInterval(6 * 86_400))
        let approval = HumanReview(reviewerID: f.reviewer.id,
            reviewedAt: Fixture.creation.addingTimeInterval(7 * 86_400))
        let snapshot = CaseRevision(caseID: f.politicalCase.id, promiseRevisionID: f.promiseRevision.id,
            criteria: f.snapshot.criteria, sourceVersions: f.snapshot.sourceVersions, excerpts: f.snapshot.excerpts,
            evidenceLinks: links.map { .init(id: $0.id, state: .verified) }, metadata: metadata)
        let child = CriterionEvaluation(caseEvaluationID: id, criterionRevisionID: f.criterionRevision.id,
            category: .fulfilled, rationale: text("Synthetic rechecked criterion"), evidenceLinkIDs: links.map { $0.id },
            confidence: .high, reviewState: .reviewed, review: approval)
        let evaluation = CaseEvaluation(id: id, caseID: f.politicalCase.id, caseRevisionID: snapshot.id,
            cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id, criterionEvaluationIDs: [child.id],
            category: .fulfilled, rationale: text("Synthetic rechecked assessment"), confidence: .high,
            metadata: metadata, status: status, approval: status == .approved ? approval : nil,
            replacesEvaluationID: replaces ? old.id : nil)
        return (snapshot, child, evaluation)
    }

    func testApprovedCaseWithApprovedEvaluationIsValidAndUpToDate() throws {
        let f = try Fixture()
        XCTAssertTrue(DomainValidator.validate(approvedCase(f), in: context(f)).isValid)
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: context(f)), .upToDate)
    }

    func testApprovedCaseRemainsHistoricallyApprovedDuringReview() throws {
        let f = try Fixture()
        let reviewed = try requiringReview(f)
        let graph = context(f, evaluations: [reviewed])
        XCTAssertTrue(DomainValidator.validate(graph).isValid)
        XCTAssertEqual(approvedCase(f).workflowState, .approved)
        XCTAssertTrue(reviewed.hasHistoricalApproval)
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: graph), .reviewRequired)
    }

    func testReviewRetainsAllHistoricalDecisionAndApprovalFields() throws {
        let f = try Fixture()
        let reviewed = try requiringReview(f)
        XCTAssertEqual(reviewed.category, f.evaluation.category)
        XCTAssertEqual(reviewed.rationale, f.evaluation.rationale)
        XCTAssertEqual(reviewed.caseRevisionID, f.evaluation.caseRevisionID)
        XCTAssertEqual(reviewed.criterionEvaluationIDs, f.evaluation.criterionEvaluationIDs)
        XCTAssertEqual(reviewed.methodologyVersionID, f.evaluation.methodologyVersionID)
        XCTAssertEqual(reviewed.approval?.reviewerID, f.evaluation.approval?.reviewerID)
        XCTAssertEqual(reviewed.approval?.reviewedAt, f.evaluation.approval?.reviewedAt)
        XCTAssertEqual(reviewed.replacingLifecycle(status: .approved, approval: reviewed.approval, reviewReason: nil), f.evaluation)
        XCTAssertNoThrow(try RevisionRules.validateReplacement(f.evaluation, with: reviewed))
    }

    func testNewRelevantEvidenceMarksReviewWithoutChangingWorkflow() throws {
        let f = try Fixture()
        let link = additionalEvidence(f)
        let change = try DomainChanges.addingEvidence(link, reason: text("Synthetic review trigger"), in: context(f))
        let reviewed = try XCTUnwrap(change.evaluationUpdates.first)
        let graph = context(f, evaluations: [reviewed], links: [f.evidence, link])
        XCTAssertEqual(reviewed.status, .reviewRequired)
        XCTAssertTrue(DomainValidator.validate(approvedCase(f), in: graph).isValid)
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: graph), .reviewRequired)
    }

    func testConfirmedNewCriterionRequiresReviewAndPreservesHistoricalApproval() throws {
        let f = try Fixture()
        let change = try DomainChanges.revise(f.criterionRevision, goal: text("Synthetic changed scope"),
            reason: text("Synthetic criteria change"), author: .human(f.reviewer.id),
            at: Fixture.creation.addingTimeInterval(5 * 86_400), in: context(f))
        let confirmation = HumanReview(reviewerID: f.reviewer.id,
            reviewedAt: Fixture.creation.addingTimeInterval(6 * 86_400))
        let confirmed = try DomainChanges.transition(change.revision, to: .confirmed, review: confirmation,
            in: context(f, criteria: [f.criterionRevision, change.revision]))
        let politicalCase = approvedCase(f, criteria: [confirmed.id])
        let graph = context(f, politicalCase: politicalCase, evaluations: change.evaluationUpdates,
            criteria: [f.criterionRevision, confirmed])
        XCTAssertEqual(confirmed.state, .confirmed)
        XCTAssertEqual(change.evaluationUpdates.first?.status, .reviewRequired)
        XCTAssertTrue(DomainValidator.validate(politicalCase, in: graph).isValid)
        XCTAssertEqual(try CaseReviews.state(of: politicalCase, in: graph), .reviewRequired)
    }

    func testNewDraftCriterionDoesNotUndoReachedWorkflowMilestone() throws {
        let f = try Fixture()
        let change = try DomainChanges.revise(f.criterionRevision, goal: text("Synthetic draft scope"),
            reason: text("Synthetic draft change"), author: .human(f.reviewer.id), at: Fixture.creation, in: context(f))
        let politicalCase = approvedCase(f, criteria: [change.revision.id])
        let graph = context(f, politicalCase: politicalCase, evaluations: change.evaluationUpdates,
            criteria: [f.criterionRevision, change.revision])
        XCTAssertTrue(DomainValidator.validate(politicalCase, in: graph).isValid)
        XCTAssertEqual(try CaseReviews.state(of: politicalCase, in: graph), .reviewRequired)
    }

    func testNewHumanApprovedSnapshotResolvesExplicitlyReplacedReview() throws {
        let f = try Fixture()
        let old = try requiringReview(f)
        let link = additionalEvidence(f)
        let (snapshot, child, draft) = replacement(f, old: old, links: [f.evidence, link], status: .needsReview)
        let before = context(f, evaluations: [old, draft], snapshots: [f.snapshot, snapshot],
            links: [f.evidence, link], children: [f.criterionEvaluation, child])
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: before), .reviewRequired)
        let approval = HumanReview(reviewerID: f.reviewer.id,
            reviewedAt: Fixture.creation.addingTimeInterval(7 * 86_400))
        let approved = try DomainChanges.transition(draft, to: .approved, approval: approval, in: before)
        let after = context(f, evaluations: [old, approved], snapshots: [f.snapshot, snapshot],
            links: [f.evidence, link], children: [f.criterionEvaluation, child])
        XCTAssertTrue(DomainValidator.validate(after).isValid)
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: after), .upToDate)
        XCTAssertEqual(old.status, .reviewRequired)
        XCTAssertEqual(old.caseRevisionID, f.snapshot.id)
        XCTAssertEqual(old.approval, f.evaluation.approval)
        XCTAssertNotEqual(approved.id, old.id)
        XCTAssertNotEqual(approved.caseRevisionID, old.caseRevisionID)
        let superseded = try DomainChanges.transition(old, to: .superseded, in: after)
        let archived = context(f, evaluations: [superseded, approved], snapshots: [f.snapshot, snapshot],
            links: [f.evidence, link], children: [f.criterionEvaluation, child])
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: archived), .upToDate)
    }

    func testUnrelatedNewApprovalCannotClearOutstandingReview() throws {
        let f = try Fixture()
        let old = try requiringReview(f)
        let (snapshot, child, unrelated) = replacement(f, old: old, links: [f.evidence], replaces: false)
        let graph = context(f, evaluations: [old, unrelated], snapshots: [f.snapshot, snapshot],
            children: [f.criterionEvaluation, child])
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: graph), .reviewRequired)
    }

    func testCurrentManifestMustIncludeAdditionalVerifiedEvidence() throws {
        let f = try Fixture()
        let graph = context(f, links: [f.evidence, additionalEvidence(f)])
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: graph), .reviewRequired)
    }

    func testSupersededHistoryWithoutApprovedReplacementDoesNotPretendToBeCurrent() throws {
        let f = try Fixture()
        let reviewed = try requiringReview(f)
        let superseded = try DomainChanges.transition(reviewed, to: .superseded, in: f.context())
        let graph = context(f, evaluations: [superseded])
        XCTAssertTrue(DomainValidator.validate(approvedCase(f), in: graph).isValid)
        XCTAssertEqual(try CaseReviews.state(of: approvedCase(f), in: graph), .reviewRequired)
    }

    func testNoApprovalDoesNotPretendToBeUpToDate() throws {
        let f = try Fixture(status: .draft, hasApproval: false)
        XCTAssertEqual(try CaseReviews.state(of: f.politicalCase, in: f.context()), .notYetApproved)
    }

    func testFirstCaseApprovalRequiresAHistoricalHumanApproval() throws {
        let f = try Fixture(status: .needsReview, hasApproval: false)
        let evaluated = f.politicalCase.replacingLifecycle(workflowState: .evaluated, modifiedAt: Fixture.creation)
        XCTAssertThrowsError(try DomainChanges.transition(evaluated, to: .approved, at: Fixture.creation, in: f.context()))
        XCTAssertFalse(DomainValidator.validate(approvedCase(f), in: context(f)).isValid)
    }

    func testMissingOriginalApprovalInvalidatesReviewRequiredEvaluation() throws {
        let f = try Fixture()
        let invalid = f.evaluation.replacingLifecycle(status: .reviewRequired, approval: nil, reviewReason: text("Synthetic reason"))
        let graph = context(f, evaluations: [invalid])
        XCTAssertFalse(DomainValidator.validate(approvedCase(f), in: graph).isValid)
        XCTAssertThrowsError(try CaseReviews.state(of: approvedCase(f), in: graph))
    }

    func testAIAuthorCannotReplaceHumanApproval() throws {
        let f = try Fixture()
        let ai = CaseEvaluation(caseID: f.politicalCase.id, caseRevisionID: f.snapshot.id, cutoff: f.evaluation.cutoff,
            methodologyVersionID: f.methodology.id, criterionEvaluationIDs: [f.criterionEvaluation.id],
            category: .fulfilled, rationale: text("Synthetic AI-authored draft"), confidence: .high,
            metadata: RevisionMetadata(number: 1, reason: text("Synthetic AI draft"),
                author: .ai(model: text("synthetic-model"), templateVersion: "test"), createdAt: Fixture.creation),
            status: .approved)
        XCTAssertTrue(DomainValidator.validate(ai, in: context(f, evaluations: [ai])).errors.contains(.missingHumanReview))
        let actorID: Any = f.party.id
        XCTAssertFalse(actorID is EntityID<ReviewerIdentity>)
    }

    func testReviewCannotMutateHistoricalRationaleOrApproval() throws {
        let f = try Fixture()
        let mutated = CaseEvaluation(id: f.evaluation.id, caseID: f.politicalCase.id, caseRevisionID: f.snapshot.id,
            cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id,
            criterionEvaluationIDs: f.evaluation.criterionEvaluationIDs, category: f.evaluation.category,
            rationale: text("Forbidden historical rewrite"), confidence: f.evaluation.confidence,
            metadata: f.evaluation.metadata, status: .reviewRequired, approval: f.approval, reviewReason: text("Synthetic reason"))
        XCTAssertThrowsError(try RevisionRules.validateReplacement(f.evaluation, with: mutated))
        let alteredApproval = HumanReview(reviewerID: f.reviewer.id, reviewedAt: f.approval.reviewedAt.addingTimeInterval(1))
        let changedTime = f.evaluation.replacingLifecycle(status: .reviewRequired, approval: alteredApproval, reviewReason: text("Synthetic reason"))
        XCTAssertThrowsError(try RevisionRules.validateReplacement(f.evaluation, with: changedTime))
    }

    func testHistoricalReviewCannotReturnToApprovedInPlace() {
        XCTAssertThrowsError(try TransitionRules.validate(EvaluationStatus.reviewRequired, to: .approved))
        XCTAssertThrowsError(try TransitionRules.validate(CaseWorkflowState.approved, to: .evaluated))
    }

    func testReplacementCannotReferToItself() throws {
        let f = try Fixture()
        let invalid = CaseEvaluation(id: f.evaluation.id, caseID: f.politicalCase.id, caseRevisionID: f.snapshot.id,
            cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id,
            criterionEvaluationIDs: f.evaluation.criterionEvaluationIDs, category: .fulfilled,
            rationale: f.evaluation.rationale, confidence: .high, metadata: f.evaluation.metadata,
            status: .approved, approval: f.approval, replacesEvaluationID: f.evaluation.id)
        XCTAssertFalse(DomainValidator.validate(invalid, in: context(f, evaluations: [invalid])).isValid)
    }
}
