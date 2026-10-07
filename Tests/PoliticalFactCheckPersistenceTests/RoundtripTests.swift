import Foundation
import SwiftData
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class RoundtripTests: XCTestCase {
    func testEmptyStoreAndUnknownCase() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            XCTAssertEqual(try store.listCases(), [])
            XCTAssertNil(try store.loadCase(id: EntityID<Case>()))
        }
    }

    func testCompleteCaseThroughFreshContext() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            let reopened = LocalCaseStore(container: store.container)
            let loaded = try XCTUnwrap(reopened.loadCase(id: f.politicalCase.id))
            assertGraphsEqual(original, loaded)
            XCTAssertEqual(try reopened.listCases(), original.cases)
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .upToDate)
        }
    }

    func testDiskStoreReopensWithoutChangingIDs() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("roundtrip.store")
            let f = try PersistenceFixture()
            let original = f.context()
            @MainActor func writeAndRelease() throws {
                let store = try LocalCaseStore.at(url: url)
                try store.saveCase(original)
            }
            try writeAndRelease()
            let reopened = try LocalCaseStore.at(url: url)
            assertGraphsEqual(original, try XCTUnwrap(reopened.loadCase(id: f.politicalCase.id)))
        }
    }

    func testMultipleSourceVersionsAndExcerptsRemainDistinct() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context())
            var version = SourceVersionDTO(f.sourceVersion)
            version.id = StoredID(EntityID<SourceVersion>(), kind: "SourceVersion")
            version.archiveURL = "https://synthetic.example.invalid/archive"
            version.localCopyReference = "synthetic-cache/document.txt"
            version.hash = String(repeating: "a", count: 64)
            dto.sourceVersions.append(version)
            var excerpt = SourceExcerptDTO(f.excerpt)
            excerpt.id = StoredID(EntityID<SourceExcerpt>(), kind: "SourceExcerpt")
            excerpt.sourceVersionID = version.id
            excerpt.locator = "paragraph 2"
            dto.excerpts.append(excerpt)
            let graph = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(graph)
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            assertGraphsEqual(graph, loaded)
            XCTAssertEqual(loaded.excerpts[1].sourceVersionID, loaded.sourceVersions[1].id)
            XCTAssertEqual(loaded.caseRevisions[0].sourceVersions[0].id, f.sourceVersion.id)
        }
    }

    func testMultiplePromiseAndCriterionRevisionsPreserveHistoricalSnapshot() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(try approvedGraph(f))
            var promise = PromiseRevisionDTO(f.promiseRevision)
            promise.id = StoredID(EntityID<PromiseRevision>(), kind: "PromiseRevision")
            promise.metadata.number = 2
            promise.metadata.reason = "Synthetic clarification"
            dto.promiseRevisions.append(promise)
            var criterion = CriterionRevisionDTO(f.criterionRevision)
            criterion.id = StoredID(EntityID<CriterionRevision>(), kind: "CriterionRevision")
            criterion.promiseRevisionID = promise.id
            criterion.metadata.number = 2
            dto.criterionRevisions.append(criterion)
            dto.promises[0].currentRevisionID = promise.id
            dto.cases[0].currentPromiseRevisionID = promise.id
            dto.criteria[0].currentRevisionID = criterion.id
            dto.cases[0].activeCriterionRevisionIDs = [criterion.id]
            let graph = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(graph)
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            assertGraphsEqual(graph, loaded)
            XCTAssertEqual(loaded.caseRevisions[0], f.snapshot)
            XCTAssertEqual(loaded.promiseRevisions[0], f.promiseRevision)
            XCTAssertEqual(loaded.criterionRevisions[0], f.criterionRevision)
            XCTAssertNotEqual(loaded.promises[0].currentRevisionID, f.promiseRevision.id)
        }
    }

    func testEvidenceRetainsExactCriterionExcerptAndActionIDs() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.evidenceLinks[0], f.evidence)
            XCTAssertEqual(loaded.evidenceLinks[0].criterionRevisionID, f.criterionRevision.id)
            XCTAssertEqual(loaded.evidenceLinks[0].excerptIDs, [f.excerpt.id])
            XCTAssertEqual(loaded.evidenceLinks[0].actionRevisionID, f.actionRevision.id)
        }
    }

    func testEvaluationAndApprovalSnapshotRemainExact() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.caseEvaluations, [f.evaluation])
            XCTAssertEqual(loaded.criterionEvaluations, [f.criterionEvaluation])
            XCTAssertEqual(loaded.caseRevisions, [f.snapshot])
            XCTAssertEqual(loaded.methodologies, [f.methodology])
            XCTAssertEqual(loaded.reviewers, [f.reviewer])
            XCTAssertEqual(loaded.caseEvaluations[0].approval, f.approval)
        }
    }

    func testDateRolesDoNotExcludeLaterPublication() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(graph.sourceVersions[0].publicationDate.role, .publication)
            XCTAssertEqual(graph.sourceVersions[0].eventDate?.role, .event)
            XCTAssertEqual(graph.sourceVersions[0].retrievedAt.role, .retrieval)
            XCTAssertEqual(graph.caseEvaluations[0].cutoff.role, .evaluationCutoff)
            XCTAssertTrue(DomainValidator.validate(graph).isValid)
            assertGraphsEqual(f.context(), graph)
        }
    }

    func testAncillaryObjectsAndMinimalScriptRoundtrip() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(includeAction: true)
            var dto = CaseGraphDTO(try approvedGraph(f))
            let affiliation = ActorAffiliation(actorID: f.speaker.id, associatedActorID: f.party.id,
                role: text("Synthetic membership"), validity: try .instant(PersistenceFixture.event, role: .validity),
                verification: .verified, excerptIDs: [f.excerpt.id], review: f.review)
            dto.affiliations.append(ActorAffiliationDTO(affiliation))
            dto.actors[0].affiliationIDs = [StoredID(affiliation.id, kind: "ActorAffiliation")]
            let participation = ActionParticipation(actionRevisionID: f.actionRevision.id, actorID: f.speaker.id,
                role: text("Synthetic support"), kind: .politicalSupport, rationale: text("Synthetic attribution"),
                excerptIDs: [f.excerpt.id], verification: .verified, review: f.review)
            dto.participations.append(ActionParticipationDTO(participation))
            dto.actionRevisions[0].participationIDs = [StoredID(participation.id, kind: "ActionParticipation")]
            dto.caseRevisions[0].participations = [StateDTO(id: StoredID(participation.id, kind: "ActionParticipation"), state: "verified")]
            let task = ResearchTask(caseID: f.politicalCase.id, goal: text("Synthetic research task"),
                criterionRevisionIDs: [f.criterionRevision.id], query: "synthetic query", status: .blocked,
                failureKind: "synthetic unavailable", attemptedAt: PersistenceFixture.creation,
                nextStep: "Synthetic manual follow-up", sourceIDs: [f.source.id], author: .human(f.reviewer.id))
            dto.researchTasks.append(ResearchTaskDTO(task))
            let audit = AuditEntry(caseID: f.politicalCase.id, target: ObjectReference(kind: .researchTask, id: task.id),
                operation: text("Synthetic audit"), author: .system, humanRequesterID: f.reviewer.id,
                occurredAt: PersistenceFixture.creation, reason: text("Synthetic audit reason"))
            dto.auditEntries.append(AuditEntryDTO(audit))
            let scriptID = EntityID<ScriptDraft>()
            let statement = ScriptStatement(scriptDraftID: scriptID, position: 0,
                text: text("Synthetic sourced fact"), kind: .fact, excerptIDs: [f.excerpt.id],
                evidenceLinkIDs: [f.evidence.id], review: f.approval)
            let script = ScriptDraft(id: scriptID, caseEvaluationID: f.evaluation.id, version: 1,
                targetDurationSeconds: 20, statementIDs: [statement.id], status: .approved,
                author: .ai(model: text("SYNTHETIC-TEST-MODEL"), templateVersion: nil),
                createdAt: PersistenceFixture.creation, approval: f.approval)
            dto.scripts = [ScriptDraftDTO(script)]; dto.statements = [ScriptStatementDTO(statement)]
            let graph = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(graph)
            assertGraphsEqual(graph, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testUnknownNotApplicableAndProvenanceSurviveMapping() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(try draftGraph(f))
            dto.promiseRevisions[0].party.content = .unknown("Synthetic unknown party")
            dto.promiseRevisions[0].party.verification = "unreviewed"
            dto.promiseRevisions[0].party.provenance = "aiExtracted"
            dto.promiseRevisions[0].party.excerptIDs = []; dto.promiseRevisions[0].party.review = nil
            dto.promiseRevisions[0].conditions.content = .notApplicable("Synthetic unconditional promise")
            let graph = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(graph)
            assertGraphsEqual(graph, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
}
