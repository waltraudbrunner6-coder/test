import XCTest
@testable import PoliticalFactCheckCore

final class ScriptTests: XCTestCase {
    func testApprovedFactNeedsVerifiedExcerpt() throws {
        let f = try Fixture()
        let id = EntityID<ScriptDraft>()
        let statement = ScriptStatement(scriptDraftID: id, position: 0, text: text("Synthetic factual sentence"),
            kind: .fact, excerptIDs: [f.excerpt.id], review: f.approval)
        let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
            statementIDs: [statement.id], status: .approved, author: .human(f.reviewer.id), approval: f.approval)
        XCTAssertTrue(DomainValidator.validate(script, in: f.context(scripts: [script], statements: [statement])).isValid)
    }
    func testApprovedFactWithoutExcerptIsRejected() throws {
        let f = try Fixture()
        let id = EntityID<ScriptDraft>()
        let statement = ScriptStatement(scriptDraftID: id, position: 0, text: text("Unbacked synthetic fact"), kind: .fact, review: f.approval)
        let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
            statementIDs: [statement.id], status: .approved, author: .human(f.reviewer.id), approval: f.approval)
        XCTAssertTrue(DomainValidator.validate(script, in: f.context(scripts: [script], statements: [statement])).errors.contains(.scriptFactWithoutExcerpt))
    }
    func testApprovedFactWithUnverifiedExcerptIsRejected() throws {
        let f = try Fixture(excerptState: .unverified)
        let id = EntityID<ScriptDraft>()
        let statement = ScriptStatement(scriptDraftID: id, position: 0, text: text("Synthetic fact"),
            kind: .fact, excerptIDs: [f.excerpt.id], review: f.approval)
        let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
            statementIDs: [statement.id], status: .approved, author: .human(f.reviewer.id), approval: f.approval)
        XCTAssertTrue(DomainValidator.validate(script, in: f.context(scripts: [script], statements: [statement])).errors.contains(.excerptNotVerified(f.excerpt.id)))
    }
}
