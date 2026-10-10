import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckScripting

final class ScriptReviewPlanTests: XCTestCase {
    func testApprovedEvaluationWithoutScriptOffersGeneration() throws {
        let f = try ScriptFixture(), plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: f.context())
        XCTAssertTrue(plan.generationAvailable); XCTAssertNil(plan.scriptID)
        XCTAssertFalse(plan.readyForApproval); XCTAssertFalse(plan.readyForVideo)
    }
    func testDraftContinuesReviewInsteadOfGeneration() throws { try assertReviewState(.draft) }
    func testNeedsReviewContinuesReviewInsteadOfGeneration() throws { try assertReviewState(.needsReview) }
    private func assertReviewState(_ state: ScriptStatus) throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: state, reviewed: false)
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertEqual(plan.scriptStatus, state); XCTAssertFalse(plan.generationAvailable)
        XCTAssertEqual(plan.reviewedCount, 0); XCTAssertEqual(plan.totalCount, 2)
        XCTAssertFalse(plan.readyForApproval); XCTAssertFalse(plan.readyForVideo)
        XCTAssertTrue(graph.statements.allSatisfy { $0.review == nil })
    }
    func testApprovedScriptIsReadyForVideo() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved)
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertTrue(plan.readyForVideo); XCTAssertFalse(plan.readyForApproval); XCTAssertEqual(plan.reviewedCount, 2)
    }
    func testSupersededScriptIsHistoricalOnly() throws {
        let f = try ScriptFixture(), plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: reviewedGraph(f, status: .superseded))
        XCTAssertFalse(plan.readyForVideo); XCTAssertFalse(plan.readyForApproval); XCTAssertFalse(plan.generationAvailable)
    }
    func testAllReviewedDraftIsReadyForApprovalWithoutCreatingApproval() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .draft)
        let before = graph.statements
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertTrue(plan.readyForApproval); XCTAssertFalse(plan.readyForVideo)
        XCTAssertEqual(graph.statements, before); XCTAssertNil(graph.scripts[0].approval)
    }
    func testFactSourcesAndEvidenceResolveExactly() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .draft, reviewed: false)
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        let fact = try XCTUnwrap(plan.statementItems.first), summary = try XCTUnwrap(fact.sourceSummaries.first)
        XCTAssertEqual(fact.kind, .fact); XCTAssertEqual(fact.excerptIDs, [f.excerpt.id])
        XCTAssertEqual(summary.exactExcerptText, f.excerpt.text.value); XCTAssertEqual(summary.locator, f.excerpt.locator.value)
        XCTAssertEqual(summary.url, f.source.canonicalURL); XCTAssertNil(summary.title); XCTAssertNil(summary.publisher)
        XCTAssertEqual(summary.relationships, [.supports]); XCTAssertEqual(fact.reviewState, .unreviewed)
    }
    func testInterpretationNeedsNoSourceAndRetainsUncertainty() throws {
        let f = try ScriptFixture(), plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: reviewedGraph(f, status: .draft))
        let item = plan.statementItems[1]
        XCTAssertEqual(item.kind, .interpretation); XCTAssertTrue(item.sourceSummaries.isEmpty)
        XCTAssertEqual(item.uncertainty, "Synthetic uncertainty")
    }
    func testInvalidFactProducesBlocker() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .draft, factSource: false)
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertTrue(plan.blockingIssues.contains(.invalidScript)); XCTAssertFalse(plan.readyForApproval)
    }
    func testReviewRequiredEvaluationBlocksSelection() throws {
        let f = try ScriptFixture(status: .reviewRequired)
        XCTAssertThrowsError(try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: f.context()))
    }
    func testNonapprovedEvaluationStatesCannotGenerate() throws {
        for status in [EvaluationStatus.draft, .needsReview, .superseded] {
            let f = try ScriptFixture(status: status, hasApproval: status == .superseded)
            XCTAssertThrowsError(try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: f.context()))
        }
    }
    func testNewestVersionIsSelectedWithoutAlteringHistoricalApprovedScript() throws {
        let f = try ScriptFixture(), old = reviewedGraph(f, status: .approved)
        let newer = reviewedGraph(f, status: .draft, reviewed: false, version: 2)
        let graph = old.withScripts(old.scripts + newer.scripts, statements: old.statements + newer.statements)
        let plan = try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)
        XCTAssertEqual(plan.scriptID, newer.scripts[0].id); XCTAssertEqual(plan.scriptVersion, 2)
        XCTAssertFalse(plan.readyForVideo); XCTAssertEqual(graph.scripts[0], old.scripts[0])
        XCTAssertTrue(newer.statements.allSatisfy { $0.review == nil })
    }
    func testDuplicateLatestVersionBlocksRatherThanGuessing() throws {
        let f = try ScriptFixture(), first = reviewedGraph(f, status: .draft), second = reviewedGraph(f, status: .draft)
        let graph = first.withScripts(first.scripts + second.scripts, statements: first.statements + second.statements)
        XCTAssertThrowsError(try ScriptReviewPlan.build(caseID: f.politicalCase.id, in: graph)) { error in
            XCTAssertEqual(error as? ScriptReviewError, .ambiguousScript)
        }
    }
    func testUnrelatedApprovalsAreAmbiguousEvenWithDifferentRevisionNumbers() throws {
        let f = try ScriptFixture(), graph = evaluationPair(f, replaces: false)
        XCTAssertThrowsError(try CurrentScriptContext.evaluation(caseID: f.politicalCase.id, in: graph)) { error in
            XCTAssertEqual(error as? ScriptReviewError, .ambiguousEvaluation)
        }
    }
    func testExplicitApprovedReplacementIsSelectedWithoutTimestampGuessing() throws {
        let f = try ScriptFixture(), graph = evaluationPair(f, replaces: true)
        let current = try CurrentScriptContext.evaluation(caseID: f.politicalCase.id, in: graph)
        XCTAssertEqual(current.id, graph.caseEvaluations[1].id)
        XCTAssertEqual(current.replacesEvaluationID, f.evaluation.id)
        XCTAssertEqual(graph.caseEvaluations[0], f.evaluation)
    }
}

private func evaluationPair(_ f: ScriptFixture, replaces: Bool) -> DomainContext {
    let id = EntityID<CaseEvaluation>()
    let child = CriterionEvaluation(caseEvaluationID: id, criterionRevisionID: f.criterionRevision.id,
        category: .fulfilled, rationale: text("Synthetic second reviewed assessment"), evidenceLinkIDs: [f.evidence.id],
        confidence: .high, reviewState: .reviewed, review: f.approval)
    let next = CaseEvaluation(id: id, caseID: f.politicalCase.id, caseRevisionID: f.snapshot.id,
        cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id, criterionEvaluationIDs: [child.id],
        category: .fulfilled, rationale: child.rationale, confidence: .high,
        metadata: .init(number: 2, reason: text("Synthetic replacement"), author: .human(f.reviewer.id), createdAt: f.evaluation.metadata.createdAt),
        status: .approved, approval: f.approval, replacesEvaluationID: replaces ? f.evaluation.id : nil)
    return DomainContext(reviewers: [f.reviewer], cases: [f.politicalCase], actors: [f.speaker, f.party],
        promises: [f.promise], promiseRevisions: [f.promiseRevision], criteria: [f.criterion], criterionRevisions: [f.criterionRevision],
        sources: [f.source], sourceVersions: [f.sourceVersion], excerpts: [f.excerpt], evidenceLinks: [f.evidence],
        caseRevisions: [f.snapshot], criterionEvaluations: [f.criterionEvaluation, child],
        caseEvaluations: [f.evaluation, next], methodologies: [f.methodology])
}

func reviewedGraph(_ f: ScriptFixture, status: ScriptStatus, reviewed: Bool = true,
                   factSource: Bool = true, version: Int = 1) -> DomainContext {
    let id = EntityID<ScriptDraft>(), date = ScriptFixture.creation.addingTimeInterval(5 * 86_400)
    let review = reviewed ? HumanReview(reviewerID: f.reviewer.id, reviewedAt: date.addingTimeInterval(100)) : nil
    let fact = ScriptStatement(scriptDraftID: id, position: 0, text: text("Synthetic source fact"), kind: .fact,
        excerptIDs: factSource ? [f.excerpt.id] : [], evidenceLinkIDs: factSource ? [f.evidence.id] : [], review: review)
    let interpretation = ScriptStatement(scriptDraftID: id, position: 1, text: text("Synthetic interpretation with several words"),
        kind: .interpretation, uncertainty: text("Synthetic uncertainty"), review: review)
    let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: version, targetDurationSeconds: 45,
        statementIDs: [interpretation.id, fact.id], status: status, author: .ai(model: text("synthetic-test-only"), templateVersion: nil),
        createdAt: date, approval: status == .approved || status == .superseded ? review : nil)
    return f.context(scripts: [script], statements: [interpretation, fact])
}
