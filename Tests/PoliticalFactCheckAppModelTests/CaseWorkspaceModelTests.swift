import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

final class CaseWorkspaceModelTests: XCTestCase {
    func testLoadsEmptyStoreWithoutCreatingDemoCase() async throws {
        try await MainActor.run {
            let workspace = CaseWorkspaceModel(store: try LocalCaseStore.inMemory(), defaults: isolatedDefaults())
            XCTAssertTrue(workspace.cases.isEmpty)
            XCTAssertNil(workspace.selectedContext)
            XCTAssertNil(workspace.errorMessage)
        }
    }

    func testCreatesUnverifiedDraftAndLoadsItAgain() async throws {
        try await MainActor.run {
            let defaults = isolatedDefaults()
            let store = try LocalCaseStore.inMemory()
            let workspace = CaseWorkspaceModel(store: store, defaults: defaults)
            workspace.reviewerName = "Synthetic Reviewer"
            let id = try XCTUnwrap(workspace.createDraftCase(title: "Synthetic case", quote: "Synthetic promise",
                thesis: "Check a synthetic measurable outcome", speakerName: "Synthetic speaker",
                partyName: "Synthetic party", statementDate: nil))

            let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
            XCTAssertEqual(reopened.cases.count, 1)
            XCTAssertEqual(reopened.selectedCaseID, id)
            let graph = try XCTUnwrap(reopened.selectedContext)
            XCTAssertEqual(graph.cases[0].workflowState, .candidate)
            XCTAssertEqual(graph.promiseRevisions[0].quote.verification, .unreviewed)
            XCTAssertTrue(graph.promiseRevisions[0].quote.excerptIDs.isEmpty)
            XCTAssertTrue(graph.sourceVersions.isEmpty)
            XCTAssertTrue(graph.excerpts.isEmpty)
            XCTAssertEqual(graph.reviewers.first?.displayName, text("Synthetic Reviewer"))
        }
    }

    func testBlankInputShowsValidationErrorAndDoesNotSave() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let workspace = CaseWorkspaceModel(store: store, defaults: isolatedDefaults())
            workspace.reviewerName = "Synthetic Reviewer"
            XCTAssertNil(workspace.createDraftCase(title: " ", quote: "Synthetic promise",
                thesis: "Synthetic thesis", speakerName: "Synthetic speaker",
                partyName: "Synthetic party", statementDate: nil))
            XCTAssertEqual(workspace.errorMessage, "Bitte fülle alle erforderlichen Textfelder aus.")
            XCTAssertTrue(try store.listCases().isEmpty)
        }
    }

    func testCreatesAndConfirmsCriterionDraftWithoutChangingPromiseHistory() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let workspace = CaseWorkspaceModel(store: store, defaults: isolatedDefaults())
            workspace.reviewerName = "Synthetic Reviewer"
            let caseID = try XCTUnwrap(workspace.createDraftCase(title: "Synthetic case", quote: "Synthetic promise",
                thesis: "Check a synthetic outcome", speakerName: "Synthetic speaker",
                partyName: "Synthetic party", statementDate: nil))
            let originalPromiseRevision = try XCTUnwrap(workspace.selectedContext?.promiseRevisions.first)
            let revisionID = try XCTUnwrap(workspace.addCriterionDraft(caseID: caseID,
                goal: "Synthetic goal", targetGroup: "Synthetic group", deadline: nil,
                isCore: true, materialityRule: "This is the core measurable condition."))

            let draftGraph = try XCTUnwrap(workspace.selectedContext)
            XCTAssertEqual(draftGraph.find(revisionID)?.state, .draft)
            XCTAssertEqual(draftGraph.promiseRevisions.first, originalPromiseRevision)
            XCTAssertTrue(workspace.confirmCriterion(revisionID))
            let confirmedGraph = try XCTUnwrap(workspace.selectedContext)
            XCTAssertEqual(confirmedGraph.find(revisionID)?.state, .confirmed)
            XCTAssertEqual(confirmedGraph.find(revisionID)?.confirmation?.reviewerID, confirmedGraph.reviewers[0].id)
            XCTAssertEqual(confirmedGraph.promiseRevisions.first, originalPromiseRevision)
        }
    }

    func testReviewRequiredFromPersistenceAppearsInWorkspace() async throws {
        try await MainActor.run {
            let fixture = try AppWorkspaceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(try approvedGraph(fixture))
            let workspace = CaseWorkspaceModel(store: store, defaults: isolatedDefaults())
            XCTAssertEqual(workspace.selectedReviewState, .upToDate)
            XCTAssertEqual(workspace.reviewStates[fixture.politicalCase.id], .upToDate)

            let date = AppWorkspaceFixture.creation.addingTimeInterval(5 * 86_400)
            let newLink = EvidenceLink(criterionRevisionID: fixture.criterionRevision.id,
                excerptIDs: [fixture.excerpt.id], relationship: .contextualizes, directness: .direct,
                rationale: text("Synthetic new contextual evidence"), temporalReference: try .instant(date, role: .event),
                status: .verified, review: HumanReview(reviewerID: fixture.reviewer.id, reviewedAt: date),
                metadata: RevisionMetadata(number: 2, reason: text("Synthetic new evidence"),
                    author: .human(fixture.reviewer.id), createdAt: date.addingTimeInterval(-60)))
            try store.addVerifiedEvidence(caseID: fixture.politicalCase.id, link: newLink,
                reason: text("Synthetic material update"), requestedBy: fixture.reviewer.id,
                at: date.addingTimeInterval(60))

            workspace.reload()
            XCTAssertEqual(workspace.selectedReviewState, .reviewRequired)
            XCTAssertEqual(workspace.reviewStates[fixture.politicalCase.id], .reviewRequired)
            XCTAssertEqual(workspace.selectedCase?.workflowState, .approved)
            XCTAssertEqual(workspace.selectedContext?.caseEvaluations[0].category, fixture.evaluation.category)
        }
    }

    func testAddingSourceAndVerifyingItUsesNewRevisions() async throws {
        try await MainActor.run {
            let defaults = isolatedDefaults()
            let store = try LocalCaseStore.inMemory()
            let workspace = CaseWorkspaceModel(store: store, defaults: defaults)
            workspace.reviewerName = "Synthetic Reviewer"
            let caseID = try XCTUnwrap(workspace.createDraftCase(title: "Synthetic case", quote: "Synthetic original quote",
                thesis: "Check a synthetic outcome", speakerName: "Synthetic speaker",
                partyName: "Synthetic party", statementDate: nil))
            let originalPromiseRevision = try XCTUnwrap(workspace.selectedContext?.promiseRevisions.first)

            XCTAssertTrue(workspace.addSource(caseID: caseID, urlText: "https://synthetic.example.invalid/source",
                documentIdentifier: "", title: "Synthetic source", publisher: "Synthetic publisher",
                publicationDate: nil, locator: "paragraph 1", excerptText: "Synthetic original quote",
                excerptContext: "Synthetic surrounding context", language: "en"))
            var graph = try XCTUnwrap(workspace.selectedContext)
            XCTAssertEqual(graph.promiseRevisions.first, originalPromiseRevision)
            XCTAssertEqual(graph.promiseRevisions.count, 2)
            XCTAssertEqual(graph.promiseRevisions.last?.quote.verification, .unreviewed)
            let oldExcerpt = try XCTUnwrap(graph.excerpts.first)
            XCTAssertEqual(oldExcerpt.state, .unverified)

            XCTAssertTrue(workspace.verifyExcerpt(oldExcerpt.id))
            graph = try XCTUnwrap(workspace.selectedContext)
            XCTAssertEqual(graph.excerpts.first?.state, .unverified)
            XCTAssertEqual(graph.excerpts.last?.state, .verified)
            XCTAssertEqual(graph.promiseRevisions.last?.quote.verification, .unreviewed)
            XCTAssertTrue(workspace.verifyOriginalQuote())
            graph = try XCTUnwrap(workspace.selectedContext)
            XCTAssertEqual(graph.promiseRevisions.last?.quote.verification, .verified)
            XCTAssertEqual(graph.promiseRevisions.first, originalPromiseRevision)
            XCTAssertTrue(workspace.markDocumented())
            XCTAssertEqual(workspace.selectedCase?.workflowState, .documented)
        }
    }

    func testStartupFailureIsVisible() async {
        await MainActor.run {
            let workspace = CaseWorkspaceModel(startupError: "Synthetic store open failure", defaults: isolatedDefaults())
            XCTAssertEqual(workspace.errorMessage, "Synthetic store open failure")
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        let suite = "PoliticalFactCheckAppModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
