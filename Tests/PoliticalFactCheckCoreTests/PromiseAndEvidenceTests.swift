import XCTest
@testable import PoliticalFactCheckCore

final class PromiseAndEvidenceTests: XCTestCase {
    func testVerifiedOriginalQuoteHasConcreteExcerptVersion() throws {
        let f = try Fixture()
        XCTAssertTrue(DomainValidator.validate(f.promiseRevision, in: f.context()).isValid)
        XCTAssertEqual(f.promiseRevision.quote.excerptIDs, [f.excerpt.id])
    }
    func testVerifiedQuoteWithoutExcerptIsRejected() throws {
        let f = try Fixture(quoteHasExcerpt: false)
        XCTAssertTrue(DomainValidator.validate(f.promiseRevision, in: f.context()).errors.contains(.missingOriginalExcerpt))
    }
    func testEvidenceWithVerifiedExcerptIsValid() throws {
        let f = try Fixture()
        XCTAssertTrue(DomainValidator.validate(f.evidence, in: f.context()).isValid)
    }
    func testVerifiedEvidenceWithoutExcerptIsRejected() throws {
        let f = try Fixture(linkHasExcerpt: false)
        XCTAssertTrue(DomainValidator.validate(f.evidence, in: f.context()).errors.contains(.missingEvidenceExcerpt))
    }
    func testEvidenceWithUnverifiedExcerptIsRejected() throws {
        let f = try Fixture(excerptState: .unverified)
        XCTAssertTrue(DomainValidator.validate(f.evidence, in: f.context()).errors.contains(.excerptNotVerified(f.excerpt.id)))
    }
    func testEvidenceNeedsResolvableSpecificCriterionRevision() throws {
        let f = try Fixture()
        let link = EvidenceLink(criterionRevisionID: .init(), excerptIDs: [f.excerpt.id], relationship: .supports,
            directness: .direct, rationale: text("Synthetic relation"), temporalReference: f.evidence.temporalReference,
            status: .verified, review: f.review, metadata: f.evidence.metadata)
        XCTAssertTrue(DomainValidator.validate(link, in: f.context()).errors.contains(
            .missingReference(ObjectReference(kind: .criterionRevision, id: link.criterionRevisionID))))
    }
    func testResearchTaskIsNotAnEvidenceReference() throws {
        let f = try Fixture()
        let task = ResearchTask(caseID: f.politicalCase.id, goal: text("Find a synthetic source"), author: .human(f.reviewer.id))
        let taskID: Any = task.id
        XCTAssertFalse(taskID is EntityID<SourceExcerpt>)
        // Even manually erasing/rebuilding the UUID cannot manufacture a registered excerpt.
        let fakeExcerpt = EntityID<SourceExcerpt>(task.id.rawValue)
        let link = EvidenceLink(criterionRevisionID: f.criterionRevision.id, excerptIDs: [fakeExcerpt],
            relationship: .supports, directness: .direct, rationale: text("Synthetic invalid mapping"),
            temporalReference: f.evidence.temporalReference, status: .verified, review: f.review, metadata: f.evidence.metadata)
        XCTAssertTrue(DomainValidator.validate(link, in: f.context()).errors.contains(
            .missingReference(ObjectReference(kind: .excerpt, id: fakeExcerpt))))
    }
    func testActionAloneDoesNotReplaceExcerpts() throws {
        let f = try Fixture(linkHasExcerpt: false, includeAction: true, actionHasExcerpt: false)
        XCTAssertNotNil(f.evidence.actionRevisionID)
        XCTAssertTrue(DomainValidator.validate(f.evidence, in: f.context()).errors.contains(.missingEvidenceExcerpt))
    }
    func testPartyNamesDoNotAffectValidationOrPrerequisites() throws {
        let alpha = try Fixture(partyName: "Synthetic Party Alpha", relationship: .contradicts, category: .contraryAction)
        let beta = try Fixture(partyName: "Synthetic Party Beta", relationship: .contradicts, category: .contraryAction)
        XCTAssertNotEqual(alpha.party.name, beta.party.name)
        XCTAssertEqual(DomainValidator.validate(alpha.evaluation, in: alpha.context()).isValid,
                       DomainValidator.validate(beta.evaluation, in: beta.context()).isValid)
        XCTAssertEqual(DomainValidator.validate(alpha.evaluation, in: alpha.context()).errors,
                       DomainValidator.validate(beta.evaluation, in: beta.context()).errors)
    }
    func testPartyNamesDoNotExcuseMissingEvidence() throws {
        let alpha = try Fixture(partyName: "Synthetic Party Alpha", includeEvidence: false, category: .notFulfilled)
        let beta = try Fixture(partyName: "Synthetic Party Beta", includeEvidence: false, category: .notFulfilled)
        XCTAssertTrue(DomainValidator.validate(alpha.evaluation, in: alpha.context()).errors.contains(.emptyEvidenceForNegativeJudgment))
        XCTAssertTrue(DomainValidator.validate(beta.evaluation, in: beta.context()).errors.contains(.emptyEvidenceForNegativeJudgment))
    }
    func testCausalAttributionNeedsEvidenceAndHumanReview() throws {
        let f = try Fixture(includeAction: true)
        let participation = ActionParticipation(actionRevisionID: f.actionRevision.id, actorID: f.party.id,
            role: text("Synthetic responsible actor"), kind: .causalResponsibility)
        XCTAssertTrue(DomainValidator.validate(participation, in: f.context()).errors.contains(.causalAttributionWithoutEvidence))
    }
}
