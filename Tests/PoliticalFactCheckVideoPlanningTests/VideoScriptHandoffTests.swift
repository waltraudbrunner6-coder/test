import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckVideoPlanning

final class VideoScriptHandoffTests: XCTestCase {
    func testApprovedScriptBuildsExactDeterministicHandoff() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved), script = graph.scripts[0]
        let handoff = try VideoScriptHandoffBuilder.build(scriptID: script.id, in: graph)
        XCTAssertEqual(handoff.caseID, f.politicalCase.id); XCTAssertEqual(handoff.evaluationID, f.evaluation.id)
        XCTAssertEqual(handoff.scriptID, script.id); XCTAssertEqual(handoff.scriptVersion, 1)
        XCTAssertEqual(handoff, try VideoScriptHandoffBuilder.build(scriptID: script.id, in: graph))
        let ordered = graph.statements.sorted { $0.position < $1.position }
        XCTAssertEqual(handoff.scenes.map { $0.statementID }, ordered.map { $0.id })
        XCTAssertEqual(handoff.scenes.map { $0.narrationText }, ordered.map { $0.text.value })
        XCTAssertEqual(handoff.scenes.map { $0.kind }, ordered.map { $0.kind })
        XCTAssertEqual(handoff.scenes.map { $0.uncertainty }, ordered.map { $0.uncertainty?.value })
        XCTAssertEqual(handoff.scenes.map { $0.excerptIDs }, ordered.map { $0.excerptIDs })
        XCTAssertEqual(handoff.scenes.map { $0.evidenceLinkIDs }, ordered.map { $0.evidenceLinkIDs })
    }
    func testDraftCannotBuild() throws { try rejectedStatus(.draft) }
    func testNeedsReviewCannotBuild() throws { try rejectedStatus(.needsReview) }
    func testSupersededCannotBuild() throws { try rejectedStatus(.superseded) }
    private func rejectedStatus(_ status: ScriptStatus) throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: status)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph)) { error in
            XCTAssertEqual(error as? VideoHandoffError, .scriptNotApproved)
        }
    }
    func testMissingApprovalBlocks() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved, reviewed: false)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph))
    }
    func testMissingStatementHumanReviewBlocksEvenWithApproval() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved)
        let s = graph.statements[0]
        let unreviewed = ScriptStatement(id: s.id, scriptDraftID: s.scriptDraftID, position: s.position,
            text: s.text, kind: s.kind, excerptIDs: s.excerptIDs, evidenceLinkIDs: s.evidenceLinkIDs, uncertainty: s.uncertainty)
        let invalid = graph.withScripts(graph.scripts, statements: [unreviewed, graph.statements[1]])
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: invalid)) { error in
            XCTAssertEqual(error as? VideoHandoffError, .statementNotReviewed)
        }
    }
    func testFactWithoutSourceBlocks() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved, factSource: false)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph))
    }
    func testOverlaysContainOnlyExactExistingSourceMetadata() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved)
        let handoff = try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph)
        let overlay = try XCTUnwrap(handoff.scenes.first?.sourceOverlays.first)
        XCTAssertEqual(overlay.excerptID, f.excerpt.id); XCTAssertEqual(overlay.sourceVersionID, f.sourceVersion.id)
        XCTAssertEqual(overlay.locator, f.excerpt.locator.value); XCTAssertEqual(overlay.url, f.source.canonicalURL)
        XCTAssertNil(overlay.sourceTitle); XCTAssertNil(overlay.publisher)
        XCTAssertTrue(handoff.scenes[1].sourceOverlays.isEmpty)
    }
    func testProportionalDurationSumsToTargetAndIsPositive() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved)
        let handoff = try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph)
        XCTAssertEqual(handoff.scenes.reduce(0) { $0 + $1.estimatedDurationSeconds }, 45, accuracy: 0.000000001)
        XCTAssertTrue(handoff.scenes.allSatisfy { $0.estimatedDurationSeconds > 0 })
        XCTAssertEqual(handoff.scenes[0].estimatedDurationSeconds, 45 * 3.0 / 8.0, accuracy: 0.000000001)
    }
    func testHistoricalApprovedVersionCannotSupplantNewerDraft() throws {
        let f = try ScriptFixture(), old = reviewedGraph(f, status: .approved), newer = reviewedGraph(f, status: .draft, version: 2)
        let graph = old.withScripts(old.scripts + newer.scripts, statements: old.statements + newer.statements)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: old.scripts[0].id, in: graph)) { error in
            XCTAssertEqual(error as? VideoHandoffError, .evaluationNotCurrent)
        }
    }
    func testMissingScriptBlocks() throws {
        let f = try ScriptFixture()
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: EntityID<ScriptDraft>(), in: f.context()))
    }
    func testRejectedExcerptCannotBecomeOverlay() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved)
        let e = f.excerpt
        let invalid = SourceExcerpt(id: e.id, sourceVersionID: e.sourceVersionID, locator: e.locator,
            text: e.text, context: e.context, language: e.language, state: .rejected, createdAt: e.createdAt)
        let changed = f.context(excerptOverride: invalid, scripts: graph.scripts, statements: graph.statements)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: changed))
    }
    func testReviewRequiredEvaluationBlocksApprovedHistoricalScript() throws {
        let f = try ScriptFixture(status: .reviewRequired), graph = reviewedGraph(f, status: .approved)
        XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: graph.scripts[0].id, in: graph)) { error in
            XCTAssertEqual(error as? VideoHandoffError, .evaluationNotCurrent)
        }
    }
    func testAllFourKindsRetainExactTextAndOptionalNonfactReferences() throws {
        let f = try ScriptFixture(), id = EntityID<ScriptDraft>()
        let date = ScriptFixture.creation.addingTimeInterval(6 * 86400)
        let review = HumanReview(reviewerID: f.reviewer.id, reviewedAt: date)
        let statements = [ScriptStatementKind.fact, .interpretation, .question, .qualification].enumerated().map { index, kind in
            ScriptStatement(scriptDraftID: id, position: index, text: text("Synthetic text \(index)"), kind: kind,
                excerptIDs: index < 2 ? [f.excerpt.id] : [], uncertainty: index == 3 ? text("Synthetic limit") : nil, review: review)
        }
        let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
            statementIDs: statements.reversed().map { $0.id }, status: .approved, author: .human(f.reviewer.id),
            createdAt: date.addingTimeInterval(-100), approval: review)
        let handoff = try VideoScriptHandoffBuilder.build(scriptID: id, in: f.context(scripts: [script], statements: statements))
        XCTAssertEqual(handoff.scenes.map { $0.kind }, statements.map { $0.kind })
        XCTAssertEqual(handoff.scenes.map { $0.narrationText }, statements.map { $0.text.value })
        XCTAssertEqual(handoff.scenes[1].sourceOverlays.count, 1)
        XCTAssertTrue(handoff.scenes[2].sourceOverlays.isEmpty); XCTAssertEqual(handoff.scenes[3].uncertainty, "Synthetic limit")
    }
    func testInvalidDurationCannotProduceVideoInput() throws {
        let f = try ScriptFixture(), graph = reviewedGraph(f, status: .approved), old = graph.scripts[0]
        for duration in [Double.nan, 0, 29, 61] {
            let invalid = ScriptDraft(id: old.id, caseEvaluationID: old.caseEvaluationID, version: old.version,
                targetDurationSeconds: duration, statementIDs: old.statementIDs, status: .approved,
                author: old.author, createdAt: old.createdAt, approval: old.approval)
            XCTAssertThrowsError(try VideoScriptHandoffBuilder.build(scriptID: old.id,
                in: graph.withScripts([invalid], statements: graph.statements)))
        }
    }
}
