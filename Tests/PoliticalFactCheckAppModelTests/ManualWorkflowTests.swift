import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
@testable import PoliticalFactCheckAppModel

final class ManualWorkflowTests: XCTestCase {
    func testFullManualActionAndEvidenceWorkflowReloadsWithoutEvaluations() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let defaults = manualDefaults()
            let workspace = try preparedWorkspace(store: store, defaults: defaults)
            let graph = try XCTUnwrap(workspace.selectedContext)
            let criterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            let oldWorkflow = graph.cases[0].workflowState
            let actionID = try XCTUnwrap(workspace.addAction(type: .implementation, title: "Synthetic action",
                description: "Synthetic implementation", eventDate: try .instant(Date(), role: .event),
                proceduralState: "Synthetic completion", scope: "Synthetic group", excerptIDs: [excerpt.id]))
            XCTAssertEqual(workspace.selectedContext?.find(actionID)?.description.verification, .unreviewed)
            XCTAssertTrue(workspace.verifyAction(actionID, excerptIDs: [excerpt.id]))
            let revisedID = try XCTUnwrap(workspace.selectedCase?.currentActionRevisionIDs.first)
            XCTAssertNotEqual(revisedID, actionID)
            let evidenceID = try XCTUnwrap(workspace.addEvidenceDraft(criterionRevisionID: criterion.id,
                excerptIDs: [excerpt.id], actionRevisionID: revisedID, relationship: .contradicts,
                directness: .direct, rationale: "Synthetic association, not an assessment", temporalReference: try .instant(Date(), role: .event)))
            let draft = try XCTUnwrap(workspace.selectedContext?.find(evidenceID))
            XCTAssertEqual(draft.status, .draft)
            XCTAssertNil(draft.review)
            XCTAssertFalse(workspace.canTransitionEvidence(draft, to: .verified))
            XCTAssertTrue(workspace.canTransitionEvidence(draft, to: .needsReview))
            XCTAssertTrue(workspace.requestEvidenceReview(evidenceID))
            let pending = try XCTUnwrap(workspace.selectedContext?.find(evidenceID))
            XCTAssertTrue(workspace.canTransitionEvidence(pending, to: .verified))
            XCTAssertTrue(workspace.verifyEvidence(evidenceID))
            let reopened = CaseWorkspaceModel(store: LocalCaseStore(container: store.container), defaults: defaults)
            let loaded = try XCTUnwrap(reopened.selectedContext)
            XCTAssertEqual(loaded.find(evidenceID)?.status, .verified)
            XCTAssertEqual(loaded.find(evidenceID)?.review?.reviewerID, loaded.reviewers[0].id)
            XCTAssertEqual(loaded.find(evidenceID)?.actionRevisionID, revisedID)
            XCTAssertEqual(loaded.find(evidenceID)?.criterionRevisionID, criterion.id)
            XCTAssertEqual(loaded.find(evidenceID)?.excerptIDs, [excerpt.id])
            XCTAssertEqual(loaded.find(actionID)?.description.verification, .unreviewed)
            XCTAssertEqual(loaded.find(revisedID)?.description.verification, .verified)
            XCTAssertEqual(loaded.cases[0].workflowState, oldWorkflow)
            XCTAssertTrue(loaded.caseEvaluations.isEmpty)
            XCTAssertTrue(loaded.criterionEvaluations.isEmpty)
            XCTAssertTrue(loaded.caseRevisions.isEmpty)
            XCTAssertTrue(loaded.methodologies.isEmpty)
            XCTAssertTrue(loaded.participations.isEmpty)
            XCTAssertTrue(loaded.auditEntries.contains { $0.operation == text("verifyAction") })
            XCTAssertTrue(loaded.auditEntries.contains { $0.operation == text("addEvidenceDraft") })
            XCTAssertTrue(loaded.auditEntries.contains { $0.operation == text("requestEvidenceReview") })
            XCTAssertTrue(loaded.auditEntries.contains { $0.operation == text("addVerifiedEvidence") })
        }
    }

    func testEmptyEvidenceExcerptsShowErrorAndDoNotSave() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let workspace = try preparedWorkspace(store: store)
            let criterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            XCTAssertNil(workspace.addEvidenceDraft(criterionRevisionID: criterion.id, excerptIDs: [],
                relationship: .supports, directness: .direct, rationale: "Synthetic reason", temporalReference: try .instant(Date(), role: .event)))
            XCTAssertEqual(workspace.errorMessage, "Für die Evidenz fehlt eine Fundstelle.")
            let caseID = try XCTUnwrap(workspace.selectedCaseID)
            let loaded = try XCTUnwrap(try store.loadCase(id: caseID))
            XCTAssertTrue(loaded.evidenceLinks.isEmpty)
        }
    }

    func testMissingCriterionAndActionShowSpecificErrors() async throws {
        try await MainActor.run {
            let workspace = try preparedWorkspace(store: LocalCaseStore.inMemory())
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertNil(workspace.addEvidenceDraft(criterionRevisionID: EntityID<CriterionRevision>(), excerptIDs: [excerpt.id],
                relationship: .supports, directness: .direct, rationale: "Synthetic reason", temporalReference: try .instant(Date(), role: .event)))
            XCTAssertEqual(workspace.errorMessage, "Das Kriterium fehlt oder gehört nicht zu den aktiven Kriterien dieses Falls.")
            let criterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            XCTAssertNil(workspace.addEvidenceDraft(criterionRevisionID: criterion.id, excerptIDs: [excerpt.id],
                actionRevisionID: EntityID<ActionRevision>(), relationship: .supports, directness: .direct,
                rationale: "Synthetic reason", temporalReference: try .instant(Date(), role: .event)))
            XCTAssertEqual(workspace.errorMessage, "Die Handlungsrevision fehlt oder gehört nicht zu diesem Fall.")
        }
    }

    func testEvidenceVerificationCannotSkipDraftReviewStepAndErrorIsVisible() async throws {
        try await MainActor.run {
            let workspace = try preparedWorkspace(store: LocalCaseStore.inMemory())
            let criterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            let id = try XCTUnwrap(workspace.addEvidenceDraft(criterionRevisionID: criterion.id, excerptIDs: [excerpt.id],
                relationship: .contextualizes, directness: .indirect, rationale: "Synthetic context", temporalReference: try .instant(Date(), role: .event)))
            XCTAssertFalse(workspace.verifyEvidence(id))
            XCTAssertEqual(workspace.errorMessage, "Dieser Evidenz-Übergang ist nicht zulässig.")
            XCTAssertEqual(workspace.selectedContext?.find(id)?.status, .draft)
            XCTAssertNil(workspace.selectedContext?.find(id)?.review)
        }
    }

    func testReviewerNameRequiredAndUnverifiedExcerptNotOffered() async throws {
        try await MainActor.run {
            let workspace = try preparedWorkspace(store: LocalCaseStore.inMemory())
            XCTAssertEqual(workspace.selectedContext?.excerpts.count, 2)
            XCTAssertEqual(workspace.verifiedExcerpts.count, 1)
            workspace.reviewerName = " "
            XCTAssertNil(workspace.addAction(type: .other, title: "Synthetic action", description: "Synthetic description",
                eventDate: try .instant(Date(), role: .event), proceduralState: "Synthetic state", scope: "Synthetic scope"))
            XCTAssertEqual(workspace.errorMessage, "Trage zuerst unter „Prüfername“ den Namen der menschlichen prüfenden Person ein.")
            XCTAssertTrue(try XCTUnwrap(workspace.selectedContext).actions.isEmpty)
        }
    }

    func testInvalidTemporalRoleAndBlankActionShowErrors() async throws {
        try await MainActor.run {
            let workspace = try preparedWorkspace(store: LocalCaseStore.inMemory())
            XCTAssertNil(workspace.addAction(type: .vote, title: " ", description: "Synthetic description",
                eventDate: try .instant(Date(), role: .event), proceduralState: "Synthetic state", scope: "Synthetic scope"))
            XCTAssertEqual(workspace.errorMessage, "Bitte fülle alle erforderlichen Textfelder aus.")
            let criterion = try XCTUnwrap(workspace.confirmedCriteria.first)
            let excerpt = try XCTUnwrap(workspace.verifiedExcerpts.first)
            XCTAssertNil(workspace.addEvidenceDraft(criterionRevisionID: criterion.id, excerptIDs: [excerpt.id],
                relationship: .supports, directness: .direct, rationale: "Synthetic reason", temporalReference: try .instant(Date(), role: .publication)))
            XCTAssertEqual(workspace.errorMessage, "Das Datum hat eine unpassende fachliche Rolle. Evidenz benötigt einen Ereignis- oder Gültigkeitsbezug, kein Publikationsdatum.")
            XCTAssertTrue(try XCTUnwrap(workspace.selectedContext).evidenceLinks.isEmpty)
        }
    }
}

@MainActor
private func preparedWorkspace(store: LocalCaseStore, defaults: UserDefaults = manualDefaults()) throws -> CaseWorkspaceModel {
    let workspace = CaseWorkspaceModel(store: store, defaults: defaults)
    workspace.reviewerName = "Synthetic manual reviewer"
    let id = try XCTUnwrap(workspace.createDraftCase(title: "Synthetic case", quote: "Synthetic promise",
        thesis: "Synthetic measurable thesis", speakerName: "Synthetic speaker", partyName: "Synthetic party", statementDate: nil))
    let criterionID = try XCTUnwrap(workspace.addCriterionDraft(caseID: id, goal: "Synthetic goal", targetGroup: "Synthetic group",
        deadline: nil, isCore: true, materialityRule: "Synthetic materiality rule"))
    XCTAssertTrue(workspace.confirmCriterion(criterionID))
    XCTAssertTrue(workspace.addSource(caseID: id, urlText: "", documentIdentifier: "synthetic-manual-source",
        title: "Synthetic source", publisher: "Synthetic publisher", publicationDate: nil,
        locator: "Synthetic paragraph", excerptText: "Synthetic promise", excerptContext: "Synthetic context", language: "en"))
    let excerpt = try XCTUnwrap(workspace.selectedContext?.excerpts.first)
    XCTAssertTrue(workspace.verifyExcerpt(excerpt.id))
    return workspace
}

private func manualDefaults() -> UserDefaults {
    UserDefaults(suiteName: "ManualWorkflowTests.\(UUID().uuidString)")!
}
