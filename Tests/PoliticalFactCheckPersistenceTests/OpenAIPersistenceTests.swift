import Foundation
import XCTest
@testable import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckScripting

final class OpenAIPersistenceTests: XCTestCase {
    func testChangeTokenStableAcrossFreshContexts() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            let original = try store.scriptGenerationChangeToken(caseID: f.politicalCase.id)
            XCTAssertEqual(original.count, 64)
            let reopened = LocalCaseStore(container: store.container)
            XCTAssertEqual(try reopened.scriptGenerationChangeToken(caseID: f.politicalCase.id), original)
            XCTAssertEqual(try reopened.loadCase(id: f.politicalCase.id)?.caseRevisions, [f.snapshot])
        }
    }
    func testNewScriptChangesLocalTokenWithoutChangingSnapshot() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            let token = try store.scriptGenerationChangeToken(caseID: f.politicalCase.id)
            _ = try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic fact", kind: .fact, referencedExcerptKeys: ["EX-1"])]),
                providerIdentifier: text("openai/synthetic-model/openai-script-prompt-v1"), reviewer: f.reviewer,
                at: PersistenceFixture.creation.addingTimeInterval(5 * 86400))
            XCTAssertNotEqual(try store.scriptGenerationChangeToken(caseID: f.politicalCase.id), token)
            let loaded = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
            XCTAssertEqual(loaded.caseRevisions, [f.snapshot]); XCTAssertEqual(loaded.caseEvaluations, [f.evaluation])
            XCTAssertEqual(loaded.excerpts, [f.excerpt]); XCTAssertEqual(loaded.evidenceLinks, [f.evidence])
            XCTAssertEqual(loaded.scripts[0].status, .draft); XCTAssertTrue(loaded.statements.allSatisfy { $0.review == nil })
        }
    }
    func testProviderIdentifierAuditAndRequesterRemainSeparateWithoutCredentialField() async throws {
        try await MainActor.run {
            let f = try PersistenceFixture(), store = try LocalCaseStore.inMemory()
            try store.saveCase(approvedGraph(f))
            let provider = text("openai/synthetic-model/openai-script-prompt-v1")
            let draft = try store.saveGeneratedScriptDraft(caseID: f.politicalCase.id, evaluationID: f.evaluation.id,
                output: .init(statements: [.init(position: 0, text: "Synthetic interpretation", kind: .interpretation)]),
                providerIdentifier: provider, reviewer: f.reviewer, at: PersistenceFixture.creation.addingTimeInterval(5 * 86400))
            let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)), audit = try XCTUnwrap(graph.auditEntries.first)
            XCTAssertEqual(draft.author, .ai(model: provider, templateVersion: "script-contract-1"))
            XCTAssertEqual(audit.author, draft.author); XCTAssertEqual(audit.humanRequesterID, f.reviewer.id)
            XCTAssertNil(draft.approval)
            let data = try JSONEncoder().encode(CaseGraphDTO(graph)), storedText = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertFalse(storedText.contains("OPENAI_API_KEY")); XCTAssertFalse(storedText.contains("Authorization"))
            XCTAssertFalse(storedText.contains("test-key-not-real")); XCTAssertFalse(storedText.contains("input_tokens"))
        }
    }
}
