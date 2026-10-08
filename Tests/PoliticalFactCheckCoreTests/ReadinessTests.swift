import Foundation
import XCTest
@testable import PoliticalFactCheckCore

final class ReadinessTests: XCTestCase {
    func testContextAndSameSpeakerAreVerifiedInNewPromiseRevision() throws {
        let f = try Fixture()
        let speakerExcerpt = SourceExcerpt(sourceVersionID: f.sourceVersion.id, locator: text("Synthetic speaker locator"),
            text: text("Synthetic speaker attribution"), context: text("Synthetic attribution context"), language: text("en"),
            state: .verified, review: f.review)
        let graph = try readinessGraph(f, extraExcerpts: [speakerExcerpt])
        let old = try XCTUnwrap(graph.promiseRevisions.first)
        let change = try readinessChange(graph, f, speakerIDs: [speakerExcerpt.id])
        XCTAssertNotEqual(change.revision.id, old.id)
        XCTAssertEqual(change.revision.promiseID, old.promiseID)
        XCTAssertEqual(change.revision.metadata.number, old.metadata.number + 1)
        XCTAssertEqual(change.revision.metadata.author, .human(f.reviewer.id))
        XCTAssertEqual(change.revision.context.content.knownValue, text("Synthetic checked context"))
        XCTAssertEqual(change.revision.context.provenance, .humanEntered)
        XCTAssertEqual(change.revision.context.verification, .verified)
        XCTAssertEqual(change.revision.context.excerptIDs, [f.excerpt.id])
        XCTAssertEqual(change.revision.context.review, readinessReview(f))
        XCTAssertEqual(change.revision.speaker.content.knownValue, old.speaker.content.knownValue)
        XCTAssertEqual(change.revision.speaker.verification, .verified)
        XCTAssertEqual(change.revision.speaker.excerptIDs, [speakerExcerpt.id])
        XCTAssertEqual(change.revision.speaker.review, readinessReview(f))
        XCTAssertEqual(graph.promiseRevisions[0], old)
        XCTAssertEqual(old.context.verification, .unreviewed)
        XCTAssertEqual(old.speaker.verification, .unreviewed)
    }

    func testOriginalQuoteAndOtherFieldsAreCopiedExactlyWithoutPartyVerification() throws {
        let f = try Fixture()
        let graph = try readinessGraph(f)
        let old = graph.promiseRevisions[0]
        let change = try readinessChange(graph, f)
        XCTAssertEqual(change.revision.quote, old.quote)
        XCTAssertEqual(change.revision.quote.verification, .verified)
        XCTAssertEqual(change.revision.quote.review, old.quote.review)
        XCTAssertEqual(change.revision.thesis, old.thesis)
        XCTAssertEqual(change.revision.statementDate, old.statementDate)
        XCTAssertEqual(change.revision.targetGroup, old.targetGroup)
        XCTAssertEqual(change.revision.conditions, old.conditions)
        XCTAssertEqual(change.revision.responsibility, old.responsibility)
        XCTAssertEqual(change.revision.topics, old.topics)
        XCTAssertEqual(change.revision.party, old.party)
        XCTAssertEqual(change.revision.party.verification, .unreviewed)
        XCTAssertEqual(change.promise.id, f.promise.id)
        XCTAssertEqual(change.promise.currentRevisionID, change.revision.id)
        XCTAssertEqual(change.politicalCase.currentPromiseRevisionID, change.revision.id)
        XCTAssertEqual(change.politicalCase.workflowState, .documented)
    }

    func testConfirmedCriterionIsReboundAsUnconfirmedDraftWithSameMeasurement() throws {
        let f = try Fixture()
        let input = f.criterionRevision
        let old = CriterionRevision(id: input.id, criterionID: input.criterionID, promiseRevisionID: input.promiseRevisionID,
            goal: input.goal, targetGroup: input.targetGroup, baseline: .known(text("Synthetic baseline")),
            deadline: input.deadline, conditions: .known([text("Synthetic condition")]), isCore: input.isCore,
            materialityRule: input.materialityRule, weight: 2, weightReason: text("Synthetic predeclared weight"),
            metadata: input.metadata, state: input.state, confirmation: input.confirmation)
        let graph = try readinessGraph(f, criterionOverride: old)
        let change = try readinessChange(graph, f)
        let next = try XCTUnwrap(change.criterionRevisions.first)
        XCTAssertNotEqual(next.id, old.id)
        XCTAssertEqual(next.criterionID, old.criterionID)
        XCTAssertEqual(next.promiseRevisionID, change.revision.id)
        XCTAssertEqual(next.metadata.number, old.metadata.number + 1)
        XCTAssertEqual(next.goal, old.goal)
        XCTAssertEqual(next.targetGroup, old.targetGroup)
        XCTAssertEqual(next.baseline, old.baseline)
        XCTAssertEqual(next.deadline, old.deadline)
        XCTAssertEqual(next.conditions, old.conditions)
        XCTAssertEqual(next.isCore, old.isCore)
        XCTAssertEqual(next.materialityRule, old.materialityRule)
        XCTAssertEqual(next.weight, old.weight)
        XCTAssertEqual(next.weightReason, old.weightReason)
        XCTAssertEqual(next.state, .draft)
        XCTAssertNil(next.confirmation)
        XCTAssertEqual(change.criteria[0].id, f.criterion.id)
        XCTAssertEqual(change.criteria[0].currentRevisionID, next.id)
        XCTAssertEqual(change.politicalCase.activeCriterionRevisionIDs, [next.id])
        XCTAssertEqual(graph.criterionRevisions[0], old)
        XCTAssertEqual(old.state, .confirmed)
    }

    func testDraftCriterionAlsoGetsNewRevisionAndNoConfirmation() throws {
        let f = try Fixture(criterionState: .draft)
        let graph = try readinessGraph(f)
        let change = try readinessChange(graph, f)
        XCTAssertNotEqual(change.criterionRevisions[0].id, f.criterionRevision.id)
        XCTAssertEqual(change.criterionRevisions[0].promiseRevisionID, change.revision.id)
        XCTAssertEqual(change.criterionRevisions[0].state, .draft)
        XCTAssertNil(change.criterionRevisions[0].confirmation)
        XCTAssertEqual(graph.criterionRevisions[0].state, .draft)
    }

    func testUnverifiedContextExcerptCannotBeUsed() throws {
        let f = try Fixture()
        let extra = SourceExcerpt(sourceVersionID: f.sourceVersion.id, locator: text("Synthetic locator"),
            text: text("Synthetic context"), context: text("Synthetic context"), language: text("en"))
        let graph = try readinessGraph(f, extraExcerpts: [extra])
        XCTAssertThrowsError(try readinessChange(graph, f, contextIDs: [extra.id])) { error in
            XCTAssertEqual(error as? DomainValidationError, .excerptNotVerified(extra.id))
        }
    }

    func testUnverifiedSpeakerExcerptCannotBeUsed() throws {
        let f = try Fixture()
        let extra = SourceExcerpt(sourceVersionID: f.sourceVersion.id, locator: text("Synthetic locator"),
            text: text("Synthetic speaker"), context: text("Synthetic context"), language: text("en"))
        let graph = try readinessGraph(f, extraExcerpts: [extra])
        XCTAssertThrowsError(try readinessChange(graph, f, speakerIDs: [extra.id])) { error in
            XCTAssertEqual(error as? DomainValidationError, .excerptNotVerified(extra.id))
        }
    }

    func testUnverifiedAndSupersededSourceVersionsCannotVerifyLiveReadiness() throws {
        let f = try Fixture()
        for state in [FactVerificationState.unreviewed, .superseded] {
            let version = SourceVersion(sourceID: f.source.id, kind: .original,
                publicationDate: f.sourceVersion.publicationDate, retrievedAt: f.sourceVersion.retrievedAt,
                availability: .available, verification: state, review: state == .superseded ? f.review : nil,
                contentType: text("text/plain"), language: text("en"))
            let extra = SourceExcerpt(sourceVersionID: version.id, locator: text("Synthetic locator"),
                text: text("Synthetic context"), context: text("Synthetic context"), language: text("en"),
                state: .verified, review: f.review)
            let graph = try readinessGraph(f, extraVersions: [version], extraExcerpts: [extra])
            XCTAssertThrowsError(try readinessChange(graph, f, contextIDs: [extra.id])) { error in
                XCTAssertEqual(error as? DomainValidationError, .sourceVersionNotVerified(version.id))
            }
        }
    }

    func testOriginalQuoteMustAlreadyBeVerified() throws {
        let f = try Fixture()
        let graph = try readinessGraph(f, quoteVerified: false)
        XCTAssertThrowsError(try readinessChange(graph, f)) { error in
            XCTAssertEqual(error as? DomainValidationError, .originalQuoteNotVerified)
        }
    }

    func testKnownSpeakerAndHumanReviewerAreRequired() throws {
        let f = try Fixture()
        XCTAssertThrowsError(try readinessChange(readinessGraph(f, speakerKnown: false), f)) { error in
            XCTAssertEqual(error as? DomainValidationError, .speakerAssignmentUnavailable)
        }
        let graph = try readinessGraph(f)
        XCTAssertThrowsError(try DomainChanges.verifyPromiseForReadiness(graph.cases[0], contextText: text("Synthetic context"),
            contextExcerptIDs: [f.excerpt.id], speakerExcerptIDs: [f.excerpt.id],
            review: HumanReview(reviewerID: EntityID<ReviewerIdentity>(), reviewedAt: readinessDate),
            reason: text("Synthetic review"), at: readinessDate, in: graph))
    }

    func testDocumentedToVerifiedFailsIfContextOrSpeakerIsUnreviewed() throws {
        let f = try Fixture()
        for (contextChecked, speakerChecked) in [(false, true), (true, false), (false, false)] {
            let graph = try readinessGraph(f, contextVerified: contextChecked, speakerVerified: speakerChecked)
            XCTAssertThrowsError(try DomainChanges.transition(graph.cases[0], to: .verified, at: readinessDate, in: graph))
        }
    }

    func testReadinessRequiresFreshHumanCriterionConfirmationAfterRebinding() throws {
        let f = try Fixture()
        let original = try readinessGraph(f)
        let change = try readinessChange(original, f)
        let graph = applying(change, to: original)
        let verified = try DomainChanges.transition(change.politicalCase, to: .verified, at: readinessDate, in: graph)
        XCTAssertThrowsError(try DomainChanges.transition(verified, to: .readyForEvaluation, at: readinessDate, in: graph)) { error in
            XCTAssertEqual(error as? DomainValidationError, .criterionNotConfirmed(change.criterionRevisions[0].id))
        }
        let confirmed = try DomainChanges.transition(change.criterionRevisions[0], to: .confirmed,
            review: readinessReview(f), in: graph)
        let readyGraph = applying(change, to: original, confirmed: confirmed)
        let ready = try DomainChanges.transition(verified, to: .readyForEvaluation, at: readinessDate, in: readyGraph)
        XCTAssertEqual(ready.workflowState, .readyForEvaluation)
        XCTAssertTrue(readyGraph.caseRevisions.isEmpty)
        XCTAssertTrue(readyGraph.caseEvaluations.isEmpty)
        XCTAssertTrue(readyGraph.criterionEvaluations.isEmpty)
        XCTAssertTrue(readyGraph.methodologies.isEmpty)
    }

    func testStaleConfirmedCriterionCannotMakeNewPromiseHeadReady() throws {
        let f = try Fixture()
        let original = try readinessGraph(f)
        let change = try readinessChange(original, f)
        let staleCase = Case(id: change.politicalCase.id, title: change.politicalCase.title, promiseID: change.promise.id,
            currentPromiseRevisionID: change.revision.id, activeCriterionRevisionIDs: [f.criterionRevision.id], workflowState: .verified)
        let graph = DomainContext(reviewers: original.reviewers, cases: [staleCase], actors: original.actors,
            promises: [change.promise], promiseRevisions: original.promiseRevisions + [change.revision],
            criteria: original.criteria, criterionRevisions: original.criterionRevisions,
            sources: original.sources, sourceVersions: original.sourceVersions, excerpts: original.excerpts)
        XCTAssertThrowsError(try DomainChanges.transition(staleCase, to: .readyForEvaluation, at: readinessDate, in: graph))
    }

    func testHistoricalSnapshotOrEvaluationBlocksRebinding() throws {
        let f = try Fixture()
        let base = try readinessGraph(f)
        for snapshotOnly in [true, false] {
            let graph = DomainContext(reviewers: base.reviewers, cases: base.cases, actors: base.actors,
                promises: base.promises, promiseRevisions: base.promiseRevisions,
                caseRevisions: snapshotOnly ? [f.snapshot] : [], caseEvaluations: snapshotOnly ? [] : [f.evaluation])
            XCTAssertThrowsError(try readinessChange(graph, f)) { error in
                XCTAssertEqual(error as? DomainValidationError, .historicalReadinessChangeDenied)
            }
        }
    }

    func testReadyForEvaluationStillRequiresAtLeastOneActiveCriterion() throws {
        let f = try Fixture()
        let base = try readinessGraph(f)
        let politicalCase = Case(id: f.politicalCase.id, title: f.politicalCase.title, promiseID: f.promise.id,
            currentPromiseRevisionID: f.promiseRevision.id, workflowState: .documented)
        let graph = DomainContext(reviewers: base.reviewers, cases: [politicalCase], actors: base.actors,
            promises: base.promises, promiseRevisions: base.promiseRevisions,
            sources: base.sources, sourceVersions: base.sourceVersions, excerpts: base.excerpts)
        let change = try readinessChange(graph, f)
        let nextGraph = applying(change, to: graph)
        let verified = try DomainChanges.transition(change.politicalCase, to: .verified, at: readinessDate, in: nextGraph)
        XCTAssertThrowsError(try DomainChanges.transition(verified, to: .readyForEvaluation, at: readinessDate, in: nextGraph)) { error in
            XCTAssertEqual(error as? DomainValidationError, .missingCriteria)
        }
    }

    func testDirectRebindingRequiresDocumentedWorkflowAndValidReviewTime() throws {
        let f = try Fixture()
        XCTAssertThrowsError(try readinessChange(f.context(), f)) // Historical data is protected first.
        let base = try readinessGraph(f)
        let candidate = base.cases[0].replacingLifecycle(workflowState: .candidate, modifiedAt: readinessDate)
        let graph = DomainContext(reviewers: base.reviewers, cases: [candidate], actors: base.actors,
            promises: base.promises, promiseRevisions: base.promiseRevisions, sources: base.sources,
            sourceVersions: base.sourceVersions, excerpts: base.excerpts)
        XCTAssertThrowsError(try readinessChange(graph, f)) { error in
            XCTAssertEqual(error as? DomainValidationError, .readinessRequiresDocumentedCase)
        }
        XCTAssertThrowsError(try DomainChanges.verifyPromiseForReadiness(base.cases[0], contextText: text("Synthetic context"),
            contextExcerptIDs: [f.excerpt.id], speakerExcerptIDs: [f.excerpt.id], review: f.review,
            reason: text("Synthetic premature review"), at: readinessDate, in: base)) { error in
            XCTAssertEqual(error as? DomainValidationError, .invalidReviewTime)
        }
    }

    func testEmptyOrDuplicateExcerptSelectionIsRejected() throws {
        let f = try Fixture()
        let graph = try readinessGraph(f)
        XCTAssertThrowsError(try readinessChange(graph, f, contextIDs: []))
        XCTAssertThrowsError(try readinessChange(graph, f, speakerIDs: []))
        XCTAssertThrowsError(try readinessChange(graph, f, contextIDs: [f.excerpt.id, f.excerpt.id]))
    }
}

private var readinessDate: Date { Fixture.creation.addingTimeInterval(5 * 86_400) }
private func readinessReview(_ f: Fixture) -> HumanReview { HumanReview(reviewerID: f.reviewer.id, reviewedAt: readinessDate) }
private func readinessChange(_ graph: DomainContext, _ f: Fixture,
    contextIDs: [EntityID<SourceExcerpt>]? = nil, speakerIDs: [EntityID<SourceExcerpt>]? = nil) throws -> PromiseReadinessChange {
    try DomainChanges.verifyPromiseForReadiness(graph.cases[0], contextText: text("Synthetic checked context"),
        contextExcerptIDs: contextIDs ?? [f.excerpt.id], speakerExcerptIDs: speakerIDs ?? [f.excerpt.id],
        review: readinessReview(f), reason: text("Synthetic readiness confirmation"), at: readinessDate, in: graph)
}

private func readinessGraph(_ f: Fixture, contextVerified: Bool = false, speakerVerified: Bool = false,
    quoteVerified: Bool = true, speakerKnown: Bool = true, extraVersions: [SourceVersion] = [], extraExcerpts: [SourceExcerpt] = [],
    criterionOverride: CriterionRevision? = nil) throws -> DomainContext {
    let old = f.promiseRevision
    let quote = try AssertedValue(content: old.quote.content, provenance: old.quote.provenance,
        verification: quoteVerified ? .verified : .unreviewed, excerptIDs: old.quote.excerptIDs, review: quoteVerified ? old.quote.review : nil)
    let revision = try PromiseRevision(id: old.id, promiseID: old.promiseID, quote: quote, thesis: old.thesis,
        statementDate: old.statementDate,
        context: AssertedValue(content: old.context.content, provenance: .humanEntered,
            verification: contextVerified ? .verified : .unreviewed, excerptIDs: contextVerified ? [f.excerpt.id] : [], review: contextVerified ? f.review : nil),
        targetGroup: old.targetGroup, conditions: old.conditions, responsibility: old.responsibility,
        speaker: AssertedValue(content: speakerKnown ? .known(f.speaker.id) : .unknown(reason: text("Synthetic unknown speaker")),
            provenance: .humanEntered, verification: speakerVerified ? .verified : .unreviewed,
            excerptIDs: speakerVerified ? [f.excerpt.id] : [], review: speakerVerified ? f.review : nil),
        party: AssertedValue(content: old.party.content, provenance: .humanEntered), topics: old.topics, metadata: old.metadata)
    let politicalCase = f.politicalCase.replacingLifecycle(workflowState: .documented, modifiedAt: Fixture.creation)
    return DomainContext(reviewers: [f.reviewer], cases: [politicalCase], actors: [f.speaker, f.party],
        promises: [f.promise], promiseRevisions: [revision], criteria: [f.criterion], criterionRevisions: [criterionOverride ?? f.criterionRevision],
        sources: [f.source], sourceVersions: [f.sourceVersion] + extraVersions, excerpts: [f.excerpt] + extraExcerpts)
}

private func applying(_ change: PromiseReadinessChange, to graph: DomainContext, confirmed: CriterionRevision? = nil) -> DomainContext {
    DomainContext(reviewers: graph.reviewers, cases: [change.politicalCase], actors: graph.actors,
        promises: [change.promise], promiseRevisions: graph.promiseRevisions + [change.revision],
        criteria: change.criteria, criterionRevisions: graph.criterionRevisions + (confirmed.map { [$0] } ?? change.criterionRevisions),
        sources: graph.sources, sourceVersions: graph.sourceVersions, excerpts: graph.excerpts)
}
