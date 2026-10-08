import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

final class ReadinessWorkspaceTests: XCTestCase {
    func testDocumentedCaseReachesReadinessOnlyAfterExplicitReconfirmation() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let defaults = readinessDefaults()
            let workspace = try readinessWorkspace(store: store, defaults: defaults)
            let original = try XCTUnwrap(workspace.selectedContext)
            let oldPromise = try XCTUnwrap(original.find(original.cases[0].currentPromiseRevisionID))
            let oldCriterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertEqual(workspace.selectedCase?.workflowState, .documented)
            XCTAssertFalse(workspace.canAdvanceReadiness(to: .verified))
            XCTAssertFalse(workspace.markVerified())
            XCTAssertEqual(workspace.errorMessage, "Prüfe Originalzitat, Kontext und Sprecherzuordnung, bevor der Fall als geprüft markiert wird.")
            XCTAssertTrue(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic checked announcement context",
                contextExcerptIDs: [excerpt.id], speakerExcerptIDs: [excerpt.id]))
            let graph = try XCTUnwrap(workspace.selectedContext)
            let revised = try XCTUnwrap(graph.find(graph.cases[0].currentPromiseRevisionID))
            XCTAssertEqual(graph.find(oldPromise.id), oldPromise)
            XCTAssertEqual(revised.quote, oldPromise.quote)
            XCTAssertEqual(revised.party, oldPromise.party)
            XCTAssertEqual(revised.speaker.content, oldPromise.speaker.content)
            XCTAssertEqual(revised.context.verification, .verified)
            XCTAssertEqual(revised.speaker.verification, .verified)
            let criterion = try XCTUnwrap(graph.find(graph.cases[0].activeCriterionRevisionIDs[0]))
            XCTAssertNotEqual(criterion.id, oldCriterion.id)
            XCTAssertEqual(graph.find(oldCriterion.id), oldCriterion)
            XCTAssertEqual(criterion.state, .draft)
            XCTAssertNil(criterion.confirmation)
            XCTAssertTrue(workspace.canAdvanceReadiness(to: .verified))
            XCTAssertTrue(workspace.markVerified())
            XCTAssertEqual(workspace.selectedCase?.workflowState, .verified)
            XCTAssertFalse(workspace.canAdvanceReadiness(to: .readyForEvaluation))
            XCTAssertFalse(workspace.prepareForEvaluation())
            XCTAssertEqual(workspace.errorMessage, "Das Kriterium ist noch nicht menschlich bestätigt. Nach einer Neubindung muss es erneut bestätigt werden.")
            XCTAssertTrue(workspace.confirmCriterion(criterion.id))
            XCTAssertTrue(workspace.canAdvanceReadiness(to: .readyForEvaluation))
            XCTAssertTrue(workspace.prepareForEvaluation())
            let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
            let loaded = try XCTUnwrap(reopened.selectedContext)
            XCTAssertEqual(loaded.cases[0].workflowState, .readyForEvaluation)
            XCTAssertEqual(loaded.find(oldPromise.id), oldPromise)
            XCTAssertEqual(loaded.find(oldCriterion.id), oldCriterion)
            XCTAssertEqual(loaded.find(criterion.id)?.promiseRevisionID, revised.id)
            XCTAssertEqual(loaded.find(criterion.id)?.confirmation?.reviewerID, loaded.reviewers[0].id)
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
            XCTAssertTrue(loaded.criterionEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.methodologies.isEmpty)
        }
    }

    func testUncheckedContextOrSpeakerSelectionShowsErrorWithoutChangingHeads() async throws {
        try await MainActor.run {
            let workspace = try readinessWorkspace(store: LocalCaseStore.inMemory())
            let before = try XCTUnwrap(workspace.selectedContext)
            let unverified = try XCTUnwrap(before.excerpts.first { $0.state == .unverified })
            let verified = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic context",
                contextExcerptIDs: [unverified.id], speakerExcerptIDs: [verified.id]))
            XCTAssertEqual(workspace.errorMessage, "Die Fundstelle muss zuerst menschlich geprüft werden.")
            XCTAssertEqual(workspace.selectedContext?.promiseRevisions, before.promiseRevisions)
            XCTAssertEqual(workspace.selectedContext?.criterionRevisions, before.criterionRevisions)
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic context",
                contextExcerptIDs: [verified.id], speakerExcerptIDs: [unverified.id]))
            XCTAssertEqual(workspace.errorMessage, "Die Fundstelle muss zuerst menschlich geprüft werden.")
            XCTAssertEqual(workspace.selectedContext?.auditEntries, before.auditEntries)
        }
    }

    func testBlankContextAndMissingSelectionsShowErrors() async throws {
        try await MainActor.run {
            let workspace = try readinessWorkspace(store: LocalCaseStore.inMemory())
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: " ",
                contextExcerptIDs: [excerpt.id], speakerExcerptIDs: [excerpt.id]))
            XCTAssertEqual(workspace.errorMessage, "Bitte fülle alle erforderlichen Textfelder aus.")
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic context",
                contextExcerptIDs: [], speakerExcerptIDs: [excerpt.id]))
            XCTAssertEqual(workspace.errorMessage, "Für die Evidenz fehlt eine Fundstelle.")
        }
    }

    func testExistingHistoricalEvaluationBlocksDirectReadinessEdit() async throws {
        try await MainActor.run {
            let fixture = try AppWorkspaceFixture()
            let store = try LocalCaseStore.inMemory()
            let original = try approvedGraph(fixture)
            try store.saveCase(original)
            let workspace = CaseWorkspaceModel(store: store, defaults: readinessDefaults())
            workspace.reviewerName = "Synthetic readiness reviewer"
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic new context",
                contextExcerptIDs: [fixture.excerpt.id], speakerExcerptIDs: [fixture.excerpt.id]))
            XCTAssertEqual(workspace.errorMessage, "Dieser Fall besitzt bereits einen Bewertungssnapshot oder eine Bewertung. Die direkte Neubindung ist gesperrt; eine spätere Neubewertung benötigt einen eigenen Vorgang.")
            let loaded = try XCTUnwrap(store.loadCase(id: fixture.politicalCase.id))
            XCTAssertEqual(loaded.caseRevisions, original.caseRevisions)
            XCTAssertEqual(loaded.caseEvaluations, original.caseEvaluations)
            XCTAssertEqual(loaded.promiseRevisions, original.promiseRevisions)
            XCTAssertEqual(loaded.criterionRevisions, original.criterionRevisions)
            XCTAssertEqual(loaded.reviewers, original.reviewers)
            XCTAssertEqual(loaded.auditEntries, original.auditEntries)
        }
    }

    func testReadyForEvaluationFailsWithoutAnyCriterion() async throws {
        try await MainActor.run {
            let workspace = try readinessWorkspace(store: LocalCaseStore.inMemory(), withCriterion: false)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertTrue(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic context",
                contextExcerptIDs: [excerpt.id], speakerExcerptIDs: [excerpt.id]))
            XCTAssertTrue(workspace.markVerified())
            XCTAssertFalse(workspace.prepareForEvaluation())
            XCTAssertEqual(workspace.errorMessage, "Lege mindestens ein Prüfkriterium an.")
            XCTAssertEqual(workspace.selectedCase?.workflowState, .verified)
        }
    }

    func testOriginalQuoteMustBeCheckedBeforeFrameConfirmation() async throws {
        try await MainActor.run {
            let workspace = try readinessWorkspace(store: LocalCaseStore.inMemory(), checkQuote: false)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertFalse(workspace.verifyPromiseForEvaluationReadiness(contextText: "Synthetic context",
                contextExcerptIDs: [excerpt.id], speakerExcerptIDs: [excerpt.id]))
            XCTAssertEqual(workspace.errorMessage, "Prüfe zuerst das Originalzitat anhand einer geprüften Fundstelle.")
            XCTAssertEqual(workspace.selectedCase?.workflowState, .documented)
        }
    }
}

@MainActor
private func readinessWorkspace(store: LocalCaseStore, defaults: UserDefaults = readinessDefaults(),
    withCriterion: Bool = true, checkQuote: Bool = true) throws -> CaseWorkspaceModel {
    let workspace = CaseWorkspaceModel(store: store, defaults: defaults)
    workspace.reviewerName = "Synthetic readiness reviewer"
    let id = try XCTUnwrap(workspace.createDraftCase(title: "Synthetic readiness case", quote: "Synthetic promise",
        thesis: "Synthetic measurable thesis", speakerName: "Synthetic speaker", partyName: "Synthetic party", statementDate: nil))
    if withCriterion {
        let criterionID = try XCTUnwrap(workspace.addCriterionDraft(caseID: id, goal: "Synthetic goal", targetGroup: "Synthetic group",
            deadline: nil, isCore: true, materialityRule: "Synthetic materiality condition"))
        XCTAssertTrue(workspace.confirmCriterion(criterionID))
    }
    XCTAssertTrue(workspace.addSource(caseID: id, urlText: "", documentIdentifier: "synthetic-readiness-document",
        title: "Synthetic source", publisher: "Synthetic publisher", publicationDate: nil,
        locator: "Synthetic paragraph", excerptText: "Synthetic promise", excerptContext: "Synthetic surrounding context", language: "en"))
    let excerpt = try XCTUnwrap(workspace.selectedContext?.excerpts.first)
    XCTAssertTrue(workspace.verifyExcerpt(excerpt.id))
    if checkQuote { XCTAssertTrue(workspace.verifyOriginalQuote()) }
    XCTAssertTrue(workspace.markDocumented())
    return workspace
}
private func readinessDefaults() -> UserDefaults {
    UserDefaults(suiteName: "ReadinessWorkspaceTests.\(UUID().uuidString)")!
}
