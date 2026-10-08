import XCTest
@testable import PoliticalFactCheckCore

final class ScriptReviewTests: XCTestCase {
    func testHumanReviewOnlyChangesReviewMetadata() throws {
        let (f, graph, script, statement) = try scriptReviewFixture()
        let reviewed = try DomainChanges.reviewScriptStatement(statement, review: f.approval, in: graph)
        XCTAssertEqual(reviewed.id, statement.id)
        XCTAssertEqual(reviewed.withReview(nil), statement)
        XCTAssertEqual(reviewed.review, f.approval)
        XCTAssertEqual(graph.find(script.id), script)
        XCTAssertNil(graph.find(statement.id)?.review)
    }
    func testMissingHumanReviewerRejected() throws {
        let (_, graph, _, statement) = try scriptReviewFixture()
        XCTAssertThrowsError(try DomainChanges.reviewScriptStatement(statement,
            review: HumanReview(reviewerID: EntityID<ReviewerIdentity>(), reviewedAt: Fixture.creation.addingTimeInterval(9 * 86400)), in: graph))
    }
    func testReviewBeforeCreationRejected() throws {
        let (f, graph, _, statement) = try scriptReviewFixture()
        XCTAssertThrowsError(try DomainChanges.reviewScriptStatement(statement,
            review: HumanReview(reviewerID: f.reviewer.id, reviewedAt: Fixture.creation.addingTimeInterval(-1)), in: graph))
    }
    func testReviewedStatementCannotBeReviewedAgain() throws {
        let (f, graph, _, statement) = try scriptReviewFixture()
        let reviewed = try DomainChanges.reviewScriptStatement(statement, review: f.approval, in: graph)
        XCTAssertThrowsError(try DomainChanges.reviewScriptStatement(reviewed, review: f.approval,
            in: graph.withScripts(graph.scripts, statements: [reviewed])))
    }
    func testReplacementCannotChangeStatementText() throws {
        let (f, _, _, statement) = try scriptReviewFixture()
        let changed = ScriptStatement(id: statement.id, scriptDraftID: statement.scriptDraftID, position: statement.position,
            text: text("Synthetic changed content"), kind: statement.kind, excerptIDs: statement.excerptIDs, review: f.approval)
        XCTAssertThrowsError(try RevisionRules.validateReplacement(statement, with: changed))
    }
    func testDraftCannotSkipReviewSubmission() throws {
        let (f, graph, script, _) = try scriptReviewFixture()
        XCTAssertThrowsError(try DomainChanges.transition(script, to: .approved, approval: f.approval, in: graph))
        XCTAssertEqual(try DomainChanges.transition(script, to: .needsReview, in: graph).status, .needsReview)
    }
}
private func scriptReviewFixture() throws -> (Fixture, DomainContext, ScriptDraft, ScriptStatement) {
    let f = try Fixture(), id = EntityID<ScriptDraft>()
    let statement = ScriptStatement(scriptDraftID: id, position: 0, text: text("Synthetic fact"), kind: .fact, excerptIDs: [f.excerpt.id])
    let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
        statementIDs: [statement.id], author: .ai(model: text("synthetic provider"), templateVersion: "test-only"), createdAt: Fixture.creation)
    return (f, f.context(scripts: [script], statements: [statement]), script, statement)
}
