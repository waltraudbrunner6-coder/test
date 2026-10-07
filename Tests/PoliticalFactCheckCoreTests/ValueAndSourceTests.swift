import Foundation
import XCTest
@testable import PoliticalFactCheckCore

final class ValueAndSourceTests: XCTestCase {
    func testWhitespaceIsNotUnknown() {
        XCTAssertThrowsError(try NonEmptyText(" \n "))
        XCTAssertThrowsError(try AssertedValue(content: .known(""), provenance: .humanEntered))
    }
    func testUnknownAndNotApplicableAreDistinct() throws {
        let unknown = try AssertedValue<String>(content: .unknown(reason: text("Missing")), provenance: .aiExtracted)
        let notApplicable = try AssertedValue<String>(content: .notApplicable(reason: text("No condition")), provenance: .humanEntered)
        XCTAssertNil(unknown.content.knownValue)
        XCTAssertNotEqual(unknown.content, notApplicable.content)
    }
    func testProvenanceDoesNotVerifyAIExtraction() throws {
        let value = try AssertedValue(content: .known("Synthetic extracted text"), provenance: .aiExtracted)
        XCTAssertEqual(value.provenance, .aiExtracted)
        XCTAssertEqual(value.verification, .unreviewed)
    }
    func testTypedIDsCannotBeUsedAsOtherEntities() {
        let raw = UUID()
        let actorID: Any = EntityID<Actor>(raw)
        XCTAssertFalse(actorID is EntityID<ReviewerIdentity>)
        XCTAssertEqual(EntityID<Actor>(raw).rawValue, raw)
    }
    func testReviewerTypeIsAlwaysHuman() throws {
        let fixture = try Fixture()
        XCTAssertEqual(fixture.reviewer.kind, .human)
        let author: Any = Authorship.ai(model: text("synthetic-model"), templateVersion: "test")
        XCTAssertFalse(author is ReviewerIdentity)
    }
    func testInvalidHashIsRejected() {
        XCTAssertThrowsError(try ContentHash(sha256: "wrong"))
    }
    func testHashHasExplicitValidatedSHA256Shape() throws {
        let hash = try ContentHash(sha256: String(repeating: "A", count: 64))
        XCTAssertEqual(hash.sha256, String(repeating: "a", count: 64))
    }
    func testDateRolesAreDistinct() throws {
        let publication = try DatedValue.instant(Fixture.event, role: .publication)
        let event = try DatedValue.instant(Fixture.event, role: .event)
        XCTAssertNotEqual(publication, event)
        XCTAssertEqual(publication.role, .publication)
        XCTAssertEqual(event.role, .event)
    }
    func testInvalidDateRangeIsRejected() {
        XCTAssertThrowsError(try PoliticalFactCheckCore.DateInterval(start: Fixture.cutoff, end: Fixture.event))
        XCTAssertThrowsError(try PoliticalFactCheckCore.DateInterval(start: nil, end: nil))
    }
    func testPrecisionCannotPretendAnIntervalIsAnInstant() throws {
        let interval = try PoliticalFactCheckCore.DateInterval(start: Fixture.event, end: Fixture.cutoff)
        XCTAssertThrowsError(try DatedValue(role: .event, precision: .instant, content: .known(interval)))
    }
    func testUnknownDateNeedsHumanTemporalInterpretation() throws {
        let unknown = try DatedValue.unknown(role: .event, reason: text("Not documented"))
        XCTAssertEqual(unknown.eligibility(at: try .instant(Fixture.cutoff, role: .evaluationCutoff)), .requiresHumanReview)
    }
    func testFutureEventIsAfterCutoff() throws {
        XCTAssertEqual(try DatedValue.instant(Fixture.publication, role: .event)
            .eligibility(at: .instant(Fixture.cutoff, role: .evaluationCutoff)), .afterCutoff)
    }
    func testSpanningIntervalDoesNotPretendToBeCompleted() throws {
        let span = try PoliticalFactCheckCore.DateInterval(start: Fixture.event, end: Fixture.publication)
        let date = try DatedValue(role: .event, precision: .interval, content: .known(span))
        XCTAssertEqual(date.eligibility(at: try .instant(Fixture.cutoff, role: .evaluationCutoff)), .requiresHumanReview)
    }
    func testValidSourceVersionAndExcerpt() throws {
        let f = try Fixture()
        XCTAssertTrue(DomainValidator.validate(f.sourceVersion, in: f.context()).isValid)
        XCTAssertTrue(DomainValidator.validate(f.excerpt, in: f.context()).isValid)
        XCTAssertEqual(f.excerpt.sourceVersionID, f.sourceVersion.id)
    }
    func testExcerptWithoutResolvableSourceVersionIsRejected() throws {
        let f = try Fixture(sourcePresent: false)
        XCTAssertTrue(DomainValidator.validate(f.excerpt, in: f.context()).errors.contains(
            .missingReference(ObjectReference(kind: .sourceVersion, id: f.sourceVersion.id))))
    }
    func testVerifiedExcerptNeedsHumanReview() throws {
        let f = try Fixture(excerptReview: false)
        XCTAssertTrue(DomainValidator.validate(f.excerpt, in: f.context()).errors.contains(.missingHumanReview))
    }
    func testExcerptDataCannotBeBlank() {
        XCTAssertThrowsError(try NonEmptyText("")) // Excerpt text/locator/context all use this value type.
    }
    func testSourceNeedsIdentityBeyondVersionContent() {
        XCTAssertTrue(DomainValidator.validate(Source(), in: DomainContext()).errors.contains(.missingSourceIdentity))
    }
    func testPublicationCannotBePassedAsRetrievalDate() throws {
        let f = try Fixture()
        let wrong = SourceVersion(sourceID: f.source.id,
            publicationDate: try .instant(Fixture.publication, role: .publication),
            retrievedAt: try .instant(Fixture.creation, role: .publication), contentType: text("text/plain"), language: text("en"))
        XCTAssertTrue(DomainValidator.validate(wrong, in: f.context()).errors.contains(
            .invalidDateRole(expected: .retrieval, actual: .publication)))
    }
    func testHistoricalEventWithLaterPublicationIsAllowed() throws {
        let f = try Fixture()
        XCTAssertEqual(f.sourceVersion.publicationDate.role, .publication)
        XCTAssertEqual(f.evidence.temporalReference.role, .event)
        XCTAssertEqual(f.evaluation.cutoff.role, .evaluationCutoff)
        let result = DomainValidator.validate(f.evaluation, in: f.context())
        XCTAssertTrue(result.isValid, "\(result.errors)")
        XCTAssertTrue(result.warnings.contains(.retrospectivePublication(f.sourceVersion.id)))
    }
    func testActualFutureEventIsRejectedDespiteValidPublicationRole() throws {
        let f = try Fixture(eventDate: Fixture.publication)
        XCTAssertTrue(DomainValidator.validate(f.evaluation, in: f.context()).errors.contains(.eventAfterCutoff))
    }
}
