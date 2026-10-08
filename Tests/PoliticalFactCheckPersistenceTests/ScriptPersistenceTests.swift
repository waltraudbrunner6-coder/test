import Foundation
import XCTest
@testable import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckScripting

final class ScriptPersistenceTests: XCTestCase {
    func testGeneratedDraftStartsUnreviewedWithVersionOne() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore()
            let script = try generate(f, store)
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(script.status, .draft); XCTAssertEqual(script.version, 1); XCTAssertNil(script.approval)
            XCTAssertTrue(graph.statements.allSatisfy { $0.review == nil })
            XCTAssertEqual(graph.statements[0].excerptIDs, [f.excerpt.id])
            XCTAssertEqual(graph.statements[0].evidenceLinkIDs, [f.evidence.id])
        }
    }
    func testSecondVersionPreservesFirstAndGetsNewIDs() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), first = try generate(f, store)
            let statements = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).statements
            let second = try generate(f, store)
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(second.version, 2); XCTAssertNotEqual(first.id, second.id)
            XCTAssertEqual(graph.find(first.id), first)
            XCTAssertEqual(first.statementIDs.compactMap { graph.find($0) }, statements)
            XCTAssertTrue(Set(first.statementIDs).isDisjoint(with: second.statementIDs))
            XCTAssertTrue(graph.auditEntries.contains { $0.operation.value == "createScriptVersion" })
        }
    }
    func testGeneratedOutputCannotCreateSourcesEvidenceOrChangeEvaluation() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore()
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            _ = try generate(f, store)
            let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(after.sources, before.sources); XCTAssertEqual(after.sourceVersions, before.sourceVersions)
            XCTAssertEqual(after.excerpts, before.excerpts); XCTAssertEqual(after.actions, before.actions)
            XCTAssertEqual(after.actionRevisions, before.actionRevisions); XCTAssertEqual(after.evidenceLinks, before.evidenceLinks)
            XCTAssertEqual(after.caseEvaluations, before.caseEvaluations); XCTAssertEqual(after.criterionEvaluations, before.criterionEvaluations)
            XCTAssertEqual(after.caseRevisions, before.caseRevisions); XCTAssertEqual(after.methodologies, before.methodologies)
            XCTAssertEqual(after.cases, before.cases)
        }
    }
    func testUnknownProviderReferencesRollbackEntireDraftIncludingRequester() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let output = ScriptGenerationOutput(statements: [.init(position: 0, text: "Synthetic valid fact", kind: .fact, referencedExcerptKeys: ["EX-1"]),
                .init(position: 1, text: "Synthetic invented reference", kind: .fact, referencedExcerptKeys: ["EX-999"])])
            XCTAssertThrowsError(try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: output, reviewer: ReviewerIdentity(displayName: text("Synthetic new requester")), at: scriptDate(5)))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testManualFactWithoutExcerptRejectedAtomically() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic unsupported fact", kind: .fact)]), reviewer: f.reviewer, at: scriptDate(5)))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testManualDraftUsesSameDomainAndHumanAuthorship() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore()
            let script = try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: scriptOutput(), reviewer: f.reviewer, at: scriptDate(5))
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(script.author, .human(f.reviewer.id)); XCTAssertNil(script.approval)
            XCTAssertTrue(DomainValidator.validate(script, in: graph).isValid)
            XCTAssertTrue(graph.statements.allSatisfy { $0.review == nil })
        }
    }
    func testInterpretationWithoutExcerptPersistsAsDraft() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore()
            _ = try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic interpretation", kind: .interpretation)]),
                reviewer: f.reviewer, at: scriptDate(5))
            XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).statements[0].excerptIDs.isEmpty)
        }
    }
    func testHumanStatementReviewPreservesContentAndHasAudit() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).statements[0]
            try store.reviewScriptStatement(caseID: f.politicalCase.id, statementID: script.statementIDs[0], reviewer: f.reviewer, at: scriptDate(6))
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)), after = try XCTUnwrap(graph.find(before.id))
            XCTAssertEqual(after.withReview(nil), before)
            XCTAssertEqual(after.review?.reviewerID, f.reviewer.id)
            XCTAssertTrue(graph.auditEntries.contains { $0.operation.value == "reviewScriptStatement" })
        }
    }
    func testReviewIsSeparateFromScriptSubmissionAndApproval() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try store.reviewScriptStatement(caseID: f.politicalCase.id, statementID: script.statementIDs[0], reviewer: f.reviewer, at: scriptDate(6))
            XCTAssertEqual(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts[0].status, .draft)
            try store.submitScriptForReview(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(7))
            XCTAssertEqual(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts[0].status, .needsReview)
        }
    }
    func testDraftApprovalShortcutRejected() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            XCTAssertThrowsError(try store.approveScript(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(8)))
            XCTAssertEqual(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts[0], script)
        }
    }
    func testApprovalRequiresEveryHumanReviewedStatement() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try store.submitScriptForReview(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(7))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.approveScript(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(8)))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testFullyReviewedScriptCanBeHumanApproved() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try approve(f, store, script)
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)), approved = graph.scripts[0]
            XCTAssertEqual(approved.status, .approved); XCTAssertEqual(approved.approval?.reviewerID, f.reviewer.id)
            XCTAssertEqual(approved.approval?.reviewedAt, scriptDate(8))
            XCTAssertTrue(graph.statements.allSatisfy { $0.review != nil })
            XCTAssertEqual(graph.find(graph.statements[0].excerptIDs[0])?.state, .verified)
        }
    }
    func testNewDraftDoesNotSupersedeApprovedVersion() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try approve(f, store, script)
            let approved = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts[0]
            _ = try generate(f, store)
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(graph.find(script.id), approved); XCTAssertEqual(graph.scripts[1].status, .draft)
        }
    }
    func testActualStoreCloseAndReopenKeepsIDsTextsReviewsAndSnapshot() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture()
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("SyntheticScripts.store")
            var original: DomainContext?
            do {
                let store = try LocalCaseStore.at(url: url)
                try store.saveCase(approvedGraph(f))
                let script = try generate(f, store)
                try approve(f, store, script)
                original = try store.loadCase(id: f.politicalCase.id)
            }
            let reopened = try LocalCaseStore.at(url: url)
            assertGraphsEqual(try XCTUnwrap(original), try XCTUnwrap(reopened.loadCase(id: f.politicalCase.id)))
        }
    }
    func testNewEvidenceSupersedesApprovedScriptWithoutChangingHistoricalContent() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try approve(f, store, script)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            var link = EvidenceLinkDTO(f.evidence); link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link.domain(), reason: text("Synthetic relevant later evidence"),
                requestedBy: f.reviewer.id, at: scriptDate(9))
            let after = try XCTUnwrap(LocalCaseStore(container: store.container).loadCase(id: f.politicalCase.id))
            XCTAssertEqual(after.cases[0].workflowState, .approved)
            XCTAssertEqual(after.caseEvaluations[0].status, .reviewRequired)
            XCTAssertEqual(after.caseEvaluations[0].category, before.caseEvaluations[0].category)
            XCTAssertEqual(after.caseEvaluations[0].approval, before.caseEvaluations[0].approval)
            XCTAssertEqual(after.caseRevisions, before.caseRevisions)
            XCTAssertEqual(after.scripts[0].status, .superseded)
            XCTAssertEqual(after.scripts[0].replacingLifecycle(status: .approved, approval: after.scripts[0].approval), before.scripts[0])
            XCTAssertEqual(after.statements, before.statements)
            XCTAssertThrowsError(try generate(f, store))
        }
    }
    func testReviewRequiredBlocksDraftApprovalAndGeneration() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try store.submitScriptForReview(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(7))
            var link = EvidenceLinkDTO(f.evidence); link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link.domain(), reason: text("Synthetic additional evidence"),
                requestedBy: f.reviewer.id, at: scriptDate(9))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertThrowsError(try store.approveScript(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(10)))
            XCTAssertThrowsError(try generate(f, store))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testCompleteGraphSaveCannotAddReviewAfterEvaluationNeedsReview() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            var link = EvidenceLinkDTO(f.evidence); link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
            try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link.domain(), reason: text("Synthetic new evidence"),
                requestedBy: f.reviewer.id, at: scriptDate(9))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            var dto = CaseGraphDTO(before)
            let reviewed = before.statements[0].withReview(HumanReview(reviewerID: f.reviewer.id, reviewedAt: scriptDate(10)))
            dto.statements[0] = ScriptStatementDTO(reviewed)
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            XCTAssertEqual(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).find(script.id)?.status, .draft)
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testNewConfirmedCriterionSupersedesApprovedScriptAndBlocksGeneration() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try approve(f, store, script)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            try store.reviseCriterion(caseID: f.politicalCase.id, revisionID: f.criterionRevision.id,
                goal: text("Synthetic revised scope"), reason: text("Synthetic necessary revision"), requestedBy: f.reviewer.id,
                at: scriptDate(9), confirmation: HumanReview(reviewerID: f.reviewer.id, reviewedAt: scriptDate(9)))
            let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(after.caseEvaluations[0].status, .reviewRequired)
            XCTAssertEqual(after.scripts[0].status, .superseded)
            XCTAssertEqual(after.scripts[0].approval, before.scripts[0].approval)
            XCTAssertEqual(after.statements, before.statements)
            XCTAssertEqual(after.caseRevisions, before.caseRevisions)
            XCTAssertEqual(after.criterionRevisions[1].state, .confirmed)
            XCTAssertThrowsError(try generate(f, store))
        }
    }
    func testGeneratedAuditSeparatesProviderAuthorFromHumanRequester() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore()
            _ = try generate(f, store)
            let audit = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).auditEntries[0]
            XCTAssertEqual(audit.operation.value, "createScriptDraft")
            XCTAssertEqual(audit.humanRequesterID, f.reviewer.id)
            if case .ai(let provider, let version) = audit.author {
                XCTAssertEqual(provider.value, "local-test-provider-no-ai"); XCTAssertEqual(version, "script-contract-1")
            } else { XCTFail("Provider authorship must remain distinct from human request") }
        }
    }
    func testReviewedContentCannotBeOverwrittenThroughSaveCase() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try store.reviewScriptStatement(caseID: f.politicalCase.id, statementID: script.statementIDs[0], reviewer: f.reviewer, at: scriptDate(6))
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            var dto = CaseGraphDTO(before); dto.statements[0].text = "Synthetic changed historical text"
            XCTAssertThrowsError(try store.saveCase(dto.domain()))
            assertGraphsEqual(before, try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        }
    }
    func testManualEditedVersionResetsReviewsAndPreservesApprovedOriginal() async throws {
        try await MainActor.run {
            let (f, store) = try scriptStore(), script = try generate(f, store)
            try approve(f, store, script)
            let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            let edited = try store.saveManualScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic rewritten fact", kind: .fact, referencedExcerptKeys: ["EX-1"])]),
                reviewer: f.reviewer, at: scriptDate(10))
            let after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(edited.version, 2); XCTAssertNil(edited.approval)
            XCTAssertNil(after.find(edited.statementIDs[0])?.review)
            XCTAssertEqual(after.find(script.id), before.find(script.id))
            XCTAssertEqual(script.statementIDs.compactMap { after.find($0) }, before.statements)
        }
    }
}
@MainActor private func scriptStore() throws -> (PersistenceFixture, LocalCaseStore) {
    let f = try PersistenceFixture(), store = try LocalCaseStore.inMemory()
    try store.saveCase(approvedGraph(f)); return (f, store)
}
private func scriptDate(_ day: Double) -> Date { PersistenceFixture.creation.addingTimeInterval(day * 86400) }
private func scriptOutput() -> ScriptGenerationOutput {
    .init(statements: [.init(position: 0, text: "Synthetic sourced fact", kind: .fact,
        referencedExcerptKeys: ["EX-1"], referencedEvidenceKeys: ["EV-1"])])
}
@MainActor private func generate(_ f: PersistenceFixture, _ store: LocalCaseStore) throws -> ScriptDraft {
    try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
        output: scriptOutput(), reviewer: f.reviewer, at: scriptDate(5))
}
@MainActor private func approve(_ f: PersistenceFixture, _ store: LocalCaseStore, _ script: ScriptDraft) throws {
    for id in script.statementIDs { try store.reviewScriptStatement(caseID: f.politicalCase.id, statementID: id, reviewer: f.reviewer, at: scriptDate(6)) }
    try store.submitScriptForReview(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(7))
    try store.approveScript(caseID: f.politicalCase.id, scriptID: script.id, reviewer: f.reviewer, at: scriptDate(8))
}
