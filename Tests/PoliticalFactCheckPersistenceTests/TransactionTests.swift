import Foundation
import SwiftData
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence

final class TransactionTests: XCTestCase {
    func testNewEvidenceAtomicallyPersistsReviewRequiredAndAudits() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            var linkDTO = EvidenceLinkDTO(f.evidence)
            linkDTO.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            linkDTO.relationship = "contradicts"
            let link = try linkDTO.domain()
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link,
                reason: text("Synthetic relevant new evidence"), requestedBy: f.reviewer.id,
                at: PersistenceFixture.creation.addingTimeInterval(5 * 86_400))
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.cases[0].workflowState, .approved)
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .reviewRequired)
            XCTAssertEqual(loaded.caseEvaluations[0].status, .reviewRequired)
            XCTAssertEqual(loaded.caseEvaluations[0].category, f.evaluation.category)
            XCTAssertEqual(loaded.caseEvaluations[0].rationale, f.evaluation.rationale)
            XCTAssertEqual(loaded.caseEvaluations[0].caseRevisionID, f.snapshot.id)
            XCTAssertEqual(loaded.caseEvaluations[0].methodologyVersionID, f.methodology.id)
            XCTAssertEqual(loaded.caseEvaluations[0].approval, f.approval)
            XCTAssertEqual(loaded.criterionEvaluations, original.criterionEvaluations)
            XCTAssertEqual(loaded.caseRevisions, original.caseRevisions)
            XCTAssertEqual(loaded.evidenceLinks, [f.evidence, link])
            XCTAssertEqual(loaded.auditEntries.count, 2)
            XCTAssertTrue(loaded.auditEntries.allSatisfy { $0.humanRequesterID == f.reviewer.id })
        }
    }

    func testConfirmedNewCriterionPersistsSeparateHistoricalRevision() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            let date = PersistenceFixture.creation.addingTimeInterval(5 * 86_400)
            try store.reviseCriterion(caseID: f.politicalCase.id, revisionID: f.criterionRevision.id,
                goal: text("Synthetic revised measurable goal"), reason: text("Synthetic documented clarification"),
                requestedBy: f.reviewer.id, at: date,
                confirmation: HumanReview(reviewerID: f.reviewer.id, reviewedAt: date))
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.criterionRevisions.count, 2)
            XCTAssertEqual(loaded.criterionRevisions[0], f.criterionRevision)
            XCTAssertEqual(loaded.criterionRevisions[1].state, .confirmed)
            XCTAssertEqual(loaded.criteria[0].currentRevisionID, loaded.criterionRevisions[1].id)
            XCTAssertEqual(loaded.cases[0].activeCriterionRevisionIDs, [loaded.criterionRevisions[1].id])
            XCTAssertEqual(loaded.cases[0].workflowState, .approved)
            XCTAssertEqual(loaded.caseRevisions, [f.snapshot])
            XCTAssertEqual(loaded.caseEvaluations[0].approval, f.approval)
            XCTAssertEqual(loaded.caseEvaluations[0].category, f.evaluation.category)
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .reviewRequired)
            XCTAssertEqual(loaded.auditEntries.count, 2)
        }
    }

    func testInvalidEvidenceLeavesEverythingUnchanged() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            var dto = EvidenceLinkDTO(f.evidence)
            dto.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            dto.excerptIDs = []
            XCTAssertThrowsError(try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: dto.domain(),
                reason: text("Synthetic invalid evidence"), requestedBy: f.reviewer.id,
                at: PersistenceFixture.creation))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testFailedWriteRollsBackEarlierStagedChanges() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = f.context()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            var dto = CaseGraphDTO(original)
            dto.cases[0].title = "Synthetic changed title staged before immutable source"
            dto.sourceVersions[0].language = "de"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testThrownTransactionRollsBackInsertedRows() async throws {
        try await MainActor.run {
            let store = try LocalCaseStore.inMemory()
            let reviewer = ReviewerIdentity(displayName: text("Synthetic temporary reviewer"))
            XCTAssertThrowsError(try store.transaction("synthetic injected failure") { context in
                context.insert(PersistenceSchemaV1.ReviewerIdentityRecord(id: reviewer.id.rawValue,
                    payload: try PayloadCodec.encode(ReviewerIdentityDTO(reviewer))))
                throw PersistenceError.invalidAggregate
            })
            XCTAssertTrue(try store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.ReviewerIdentityRecord>()).isEmpty)
        }
    }

    func testHistoricalSourceRemovalIsDenied() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            for removeVersion in [true, false] {
                var dto = CaseGraphDTO(f.context())
                if removeVersion { dto.sourceVersions = [] } else { dto.excerpts = [] }
                XCTAssertThrowsError(try store.saveCase(dto.domain()))
                assertGraphsEqual(f.context(), try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            }
        }
    }

    func testHistoricalSnapshotAndEvaluationCannotBeRewritten() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            var dto = CaseGraphDTO(original)
            dto.caseRevisions[0].metadata.reason = "Synthetic attempted historical edit"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            dto = CaseGraphDTO(original)
            dto.caseEvaluations[0].rationale = "Synthetic attempted historical rewrite"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testDraftDeletionRemovesOnlyItsOwnRecords() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(draftGraph(f))
            try store.deleteDraftCase(id: f.politicalCase.id)
            XCTAssertNil(try store.loadCase(id: f.politicalCase.id))
            XCTAssertTrue(try store.listCases().isEmpty)
            XCTAssertTrue(try store.freshContext().fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()).isEmpty)
        }
    }

    func testHistoricalCaseDeletionIsDenied() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            let original = try approvedGraph(f)
            try store.saveCase(original)
            XCTAssertThrowsError(try store.deleteDraftCase(id: f.politicalCase.id)) { error in
                XCTAssertEqual(error as? PersistenceError, .draftDeletionDenied(f.politicalCase.id.rawValue))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testSharedActorSurvivesOtherDraftDeletion() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let other = try PersistenceFixture(partyName: "Synthetic Party Beta")
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            var dto = CaseGraphDTO(try draftGraph(other))
            dto.actors.append(ActorDTO(f.party))
            try store.saveCase(dto.domain())
            try store.deleteDraftCase(id: other.politicalCase.id)
            assertGraphsEqual(f.context(), try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testExistingSharedIDCannotBeOverwrittenByAnotherCase() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let other = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            var dto = CaseGraphDTO(try draftGraph(other))
            var actor = ActorDTO(f.party); actor.name = "Synthetic conflicting name"
            dto.actors.append(actor)
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertNil(try store.loadCase(id: other.politicalCase.id))
            assertGraphsEqual(f.context(), try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testGraphSaveCannotBypassEvidenceReviewUpdate() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let original = try approvedGraph(f)
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            var dto = CaseGraphDTO(original)
            var link = EvidenceLinkDTO(f.evidence)
            link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            dto.evidenceLinks.append(link)
            XCTAssertThrowsError(try store.saveCase(dto.domain())) { error in
                XCTAssertEqual(error as? PersistenceError, .reviewUpdateRequired(f.evaluation.id.rawValue))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testRemovingUnreferencedHistoricalExcerptIsAlsoDenied() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            var dto = CaseGraphDTO(f.context())
            var extra = SourceExcerptDTO(f.excerpt)
            extra.id = StoredID(EntityID<SourceExcerpt>(), kind: "SourceExcerpt")
            dto.excerpts.append(extra)
            let original = try dto.domain()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(original)
            dto.excerpts.removeLast()
            XCTAssertThrowsError(try store.saveCase(dto.domain())) { error in
                XCTAssertEqual(error as? PersistenceError, .historyRemovalDenied(kind: "SourceExcerpt", id: extra.id.value))
            }
            assertGraphsEqual(original, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }

    func testNewHumanApprovedReplacementResolvesReviewAfterReload() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            var linkDTO = EvidenceLinkDTO(f.evidence)
            linkDTO.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            let link = try linkDTO.domain()
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link,
                reason: text("Synthetic relevant addition"), requestedBy: f.reviewer.id,
                at: PersistenceFixture.creation.addingTimeInterval(5 * 86_400))
            let pending = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            var dto = CaseGraphDTO(pending)
            let id = EntityID<CaseEvaluation>()
            let metadata = RevisionMetadata(number: 2, reason: text("Synthetic human reassessment"),
                author: .human(f.reviewer.id), createdAt: PersistenceFixture.creation.addingTimeInterval(6 * 86_400))
            let approval = HumanReview(reviewerID: f.reviewer.id,
                reviewedAt: PersistenceFixture.creation.addingTimeInterval(7 * 86_400))
            let snapshot = CaseRevision(caseID: f.politicalCase.id, promiseRevisionID: f.promiseRevision.id,
                criteria: f.snapshot.criteria, sourceVersions: f.snapshot.sourceVersions, excerpts: f.snapshot.excerpts,
                evidenceLinks: pending.evidenceLinks.map { .init(id: $0.id, state: .verified) }, metadata: metadata)
            let child = CriterionEvaluation(caseEvaluationID: id, criterionRevisionID: f.criterionRevision.id,
                category: .fulfilled, rationale: text("Synthetic human reassessment"),
                evidenceLinkIDs: pending.evidenceLinks.map { $0.id }, confidence: .high, reviewState: .reviewed, review: approval)
            let evaluation = CaseEvaluation(id: id, caseID: f.politicalCase.id, caseRevisionID: snapshot.id,
                cutoff: f.evaluation.cutoff, methodologyVersionID: f.methodology.id, criterionEvaluationIDs: [child.id],
                category: .fulfilled, rationale: text("Synthetic human reassessment"), confidence: .high,
                metadata: metadata, status: .approved, approval: approval, replacesEvaluationID: f.evaluation.id)
            dto.caseRevisions.append(CaseRevisionDTO(snapshot))
            dto.criterionEvaluations.append(CriterionEvaluationDTO(child))
            dto.caseEvaluations.append(CaseEvaluationDTO(evaluation))
            try store.saveCase(dto.domain())
            let loaded = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(try CaseReviews.state(of: loaded.cases[0], in: loaded), .upToDate)
            XCTAssertEqual(loaded.caseRevisions[0], f.snapshot)
            XCTAssertEqual(loaded.caseEvaluations[0], pending.caseEvaluations[0])
            XCTAssertEqual(loaded.caseEvaluations[1], evaluation)
        }
    }

    func testDependentApprovedScriptPreservesTextAndApprovalWhenSuperseded() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let scriptID = EntityID<ScriptDraft>()
            let statement = ScriptStatement(scriptDraftID: scriptID, position: 0,
                text: text("Synthetic sourced fact"), kind: .fact, excerptIDs: [f.excerpt.id], review: f.approval)
            let script = ScriptDraft(id: scriptID, caseEvaluationID: f.evaluation.id, version: 1,
                targetDurationSeconds: 20, statementIDs: [statement.id], status: .approved,
                author: .human(f.reviewer.id), createdAt: PersistenceFixture.creation, approval: f.approval)
            var dto = CaseGraphDTO(try approvedGraph(f))
            dto.scripts = [ScriptDraftDTO(script)]; dto.statements = [ScriptStatementDTO(statement)]
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(dto.domain())
            var link = EvidenceLinkDTO(f.evidence)
            link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link.domain(),
                reason: text("Synthetic new information"), requestedBy: f.reviewer.id,
                at: PersistenceFixture.creation.addingTimeInterval(5 * 86_400))
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.scripts[0].status, .superseded)
            var normalized = ScriptDraftDTO(loaded.scripts[0]); normalized.status = "approved"
            XCTAssertEqual(try normalized.domain(), script)
            XCTAssertEqual(loaded.statements, [statement])
            XCTAssertEqual(loaded.caseEvaluations[0].approval, f.approval)
            XCTAssertEqual(loaded.auditEntries.count, 3)
        }
    }

    func testSharedActorUpdateCannotBreakAnotherCase() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let other = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            var otherDTO = CaseGraphDTO(try draftGraph(other))
            otherDTO.actors.append(ActorDTO(f.party))
            let otherOriginal = try otherDTO.domain()
            try store.saveCase(otherOriginal)
            var dto = CaseGraphDTO(f.context())
            let affiliation = ActorAffiliation(actorID: f.party.id, role: text("Synthetic association"),
                validity: try .instant(PersistenceFixture.event, role: .validity))
            dto.affiliations.append(ActorAffiliationDTO(affiliation))
            dto.actors[1].affiliationIDs = [StoredID(affiliation.id, kind: "ActorAffiliation")]
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            assertGraphsEqual(f.context(), try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
            assertGraphsEqual(otherOriginal, try XCTUnwrap(store.loadCase(id: other.politicalCase.id)))
        }
    }

    func testDraftDeletionStopsWhenAnotherManifestIsDamaged() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let other = try PersistenceFixture()
            let store = try LocalCaseStore.inMemory()
            try store.saveCase(f.context())
            let draft = try draftGraph(other)
            try store.saveCase(draft)
            let context = store.freshContext()
            let row = try XCTUnwrap(context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
                .first { $0.id == f.politicalCase.id.rawValue })
            var manifest = try PayloadCodec.decode(CaseManifest.self, from: row.manifest)
            manifest.sourceVersions = []
            row.manifest = try PayloadCodec.encode(manifest); try context.save()
            XCTAssertThrowsError(try store.deleteDraftCase(id: other.politicalCase.id))
            assertGraphsEqual(draft, try XCTUnwrap(store.loadCase(id: other.politicalCase.id)))
        }
    }

}
