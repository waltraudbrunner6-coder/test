import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckScripting

final class ScriptGenerationTests: XCTestCase {
    func testInputRequiresApprovedEvaluation() throws {
        let f = try ScriptFixture(), input = try build(f)
        XCTAssertEqual(input.evaluation.id, f.evaluation.id)
        XCTAssertEqual(input.evaluation.category, f.evaluation.category)
        XCTAssertEqual(input.evaluation.confidence, f.evaluation.confidence)
        XCTAssertEqual(input.methodology, f.methodology)
        XCTAssertEqual(input.promise, f.promiseRevision)
        XCTAssertEqual(input.targetDurationSeconds, 45)
    }
    func testDraftEvaluationRejected() throws { try rejects(status: .draft) }
    func testNeedsReviewEvaluationRejected() throws { try rejects(status: .needsReview) }
    func testReviewRequiredEvaluationRejected() throws { try rejects(status: .reviewRequired) }
    func testSupersededEvaluationRejected() throws { try rejects(status: .superseded) }
    func testMissingEvaluationRejected() throws {
        XCTAssertThrowsError(try ScriptInputBuilder.build(evaluationID: EntityID<CaseEvaluation>(), in: DomainContext())) {
            XCTAssertEqual($0 as? ScriptGenerationError, .evaluationUnavailable)
        }
    }
    func testInputKeepsConcreteManifestAndActionRevisionIDs() throws {
        let f = try ScriptFixture(includeAction: true), input = try build(f)
        XCTAssertEqual(input.snapshotID, f.snapshot.id)
        XCTAssertEqual(input.actions, [f.actionRevision])
        XCTAssertEqual(input.criteria.map { $0.id }, f.snapshot.criteria.map { $0.id })
    }
    func testNewEvidenceDoesNotLeakIntoInput() throws {
        let f = try ScriptFixture()
        let extra = EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [f.excerpt.id],
            relationship: .contextualizes, directness: .indirect, rationale: text("Synthetic later evidence"),
            temporalReference: f.evidence.temporalReference, status: .verified, review: f.review, metadata: f.evidence.metadata)
        let input = try ScriptInputBuilder.build(evaluationID: f.evaluation.id, in: f.context(extraLinks: [extra]))
        XCTAssertEqual(input.evidence.map { $0.link.id }, [f.evidence.id])
        XCTAssertFalse(input.evidence.contains { $0.link.id == extra.id })
    }
    func testNewSourceAndExcerptDoNotLeakIntoInput() throws {
        let f = try ScriptFixture(), g = f.context()
        let source = Source(documentIdentifier: text("Synthetic later document"))
        let version = SourceVersion(sourceID: source.id, publicationDate: f.sourceVersion.publicationDate,
            retrievedAt: f.sourceVersion.retrievedAt, verification: .verified, review: f.review,
            contentType: text("text/plain"), language: text("en"))
        let excerpt = SourceExcerpt(sourceVersionID: version.id, locator: text("later"), text: text("Synthetic later text"),
            context: text("Synthetic later context"), language: text("en"), state: .verified, review: f.review)
        let graph = DomainContext(reviewers: g.reviewers, cases: g.cases, actors: g.actors, promises: g.promises,
            promiseRevisions: g.promiseRevisions, criteria: g.criteria, criterionRevisions: g.criterionRevisions,
            sources: g.sources + [source], sourceVersions: g.sourceVersions + [version], excerpts: g.excerpts + [excerpt],
            evidenceLinks: g.evidenceLinks, caseRevisions: g.caseRevisions, criterionEvaluations: g.criterionEvaluations,
            caseEvaluations: g.caseEvaluations, methodologies: g.methodologies)
        XCTAssertEqual(try ScriptInputBuilder.build(evaluationID: f.evaluation.id, in: graph), try build(f))
    }
    func testKeysDeterministicUniqueAndResolveConcreteIDs() throws {
        let f = try ScriptFixture(), a = try build(f), b = try build(f)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.sources.map { $0.key }, ["SRC-1"])
        XCTAssertEqual(a.excerpts.map { $0.key }, ["EX-1"])
        XCTAssertEqual(a.evidence.map { $0.key }, ["EV-1"])
        XCTAssertEqual(a.excerpts[0].excerpt.id, f.excerpt.id)
        XCTAssertEqual(a.excerpts[0].sourceKey, a.sources[0].key)
        XCTAssertEqual(a.evidence[0].excerptKeys, ["EX-1"])
    }
    func testPublicationAfterCutoffIsNotExcluded() throws {
        let f = try ScriptFixture(), input = try build(f)
        XCTAssertEqual(input.sources[0].version.publicationDate, f.sourceVersion.publicationDate)
        XCTAssertEqual(input.evaluation.cutoff, f.evaluation.cutoff)
    }
    func testInvalidDurationRejected() throws {
        let f = try ScriptFixture()
        for duration in [29.0, 61.0, Double.nan, Double.infinity] {
            XCTAssertThrowsError(try ScriptInputBuilder.build(evaluationID: f.evaluation.id, targetDurationSeconds: duration, in: f.context()))
        }
    }
    func testUnknownExcerptRejected() throws { try outputRejected(.init(position: 0, text: "Synthetic fact", kind: .fact, referencedExcerptKeys: ["EX-invented"]), expected: .unknownExcerptKey("EX-invented")) }
    func testUnknownEvidenceRejected() throws { try outputRejected(.init(position: 0, text: "Synthetic interpretation", kind: .interpretation, referencedEvidenceKeys: ["EV-invented"]), expected: .unknownEvidenceKey("EV-invented")) }
    func testFactWithoutExcerptRejected() throws { try outputRejected(.init(position: 0, text: "Synthetic fact", kind: .fact), expected: .factWithoutExcerpt) }
    func testUnverifiedExcerptCannotBecomeGenerationInput() throws {
        let f = try ScriptFixture(excerptState: .unverified)
        XCTAssertThrowsError(try build(f)) { XCTAssertEqual($0 as? ScriptGenerationError, .invalidSnapshot) }
    }
    func testForeignSnapshotKeyRejected() throws { try outputRejected(.init(position: 0, text: "Synthetic fact", kind: .fact, referencedExcerptKeys: [UUID().uuidString]), expected: nil) }
    func testInterpretationQuestionAndQualificationMayOmitExcerpts() throws {
        let f = try ScriptFixture()
        try ScriptOutputValidator.validate(.init(statements: [.init(position: 0, text: "Synthetic interpretation", kind: .interpretation),
            .init(position: 1, text: "Synthetic question?", kind: .question), .init(position: 2, text: "Synthetic limitation", kind: .qualification)]), input: build(f))
    }
    func testEvidenceRequiresItsReferencedExcerpts() throws { try outputRejected(.init(position: 0, text: "Synthetic interpretation", kind: .interpretation, referencedEvidenceKeys: ["EV-1"]), expected: .inconsistentEvidence("EV-1")) }
    func testConsistentFactAndEvidenceAccepted() throws {
        try ScriptOutputValidator.validate(.init(statements: [.init(position: 0, text: "Synthetic fact", kind: .fact,
            referencedExcerptKeys: ["EX-1"], referencedEvidenceKeys: ["EV-1"])]), input: build(ScriptFixture()))
    }
    func testBlankOutputTextAndUncertaintyRejected() throws {
        try outputRejected(.init(position: 0, text: "  ", kind: .question), expected: .blankText)
        try outputRejected(.init(position: 0, text: "Synthetic question", kind: .question, uncertainty: "  "), expected: .blankText)
    }
    func testPositionsMustBeNonnegativeAndUnique() throws {
        let f = try ScriptFixture()
        let statement = GeneratedScriptStatement(position: 0, text: "Synthetic statement", kind: .interpretation)
        XCTAssertThrowsError(try ScriptOutputValidator.validate(.init(statements: [statement, statement]), input: build(f)))
        try outputRejected(.init(position: -1, text: "Synthetic statement", kind: .interpretation), expected: .invalidPosition)
    }
    func testDuplicateReferencesAndEmptyBatchRejected() throws {
        try outputRejected(.init(position: 0, text: "Synthetic fact", kind: .fact, referencedExcerptKeys: ["EX-1", "EX-1"]), expected: .duplicateKey)
        XCTAssertThrowsError(try ScriptOutputValidator.validate(.init(statements: []), input: build(ScriptFixture())))
    }
    func testFakeProviderDeterministicAndOutputNeverContainsDomainMutations() async throws {
        let input = try build(ScriptFixture()), provider = FakeScriptGenerationProvider()
        let a = try await provider.generateScript(input: input), b = try await provider.generateScript(input: input)
        XCTAssertEqual(a, b)
        try ScriptOutputValidator.validate(a, input: input)
        XCTAssertEqual(a.statements[0].text, input.excerpts[0].excerpt.text.value)
        XCTAssertEqual(a.statements[1].text, input.evaluation.rationale.value)
        XCTAssertTrue(provider.identifier.value.contains("no-ai"))
    }
}
private func build(_ f: ScriptFixture) throws -> ScriptGenerationInput {
    try ScriptInputBuilder.build(evaluationID: f.evaluation.id, in: f.context())
}
private func rejects(status: EvaluationStatus) throws {
    let f = try ScriptFixture(status: status)
    XCTAssertThrowsError(try build(f)) { XCTAssertEqual($0 as? ScriptGenerationError, .evaluationNotApproved(status)) }
}
private func outputRejected(_ statement: GeneratedScriptStatement, expected: ScriptGenerationError?) throws {
    let input = try build(ScriptFixture())
    XCTAssertThrowsError(try ScriptOutputValidator.validate(.init(statements: [statement]), input: input)) {
        if let expected { XCTAssertEqual($0 as? ScriptGenerationError, expected) }
    }
}
