import Foundation
import XCTest
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckCore
import PoliticalFactCheckAppModel
import PoliticalFactCheckScripting

final class OpenAIWorkspaceTests: XCTestCase {
    override func tearDown() { AppOpenAIHTTPStub.reset(); super.tearDown() }
    @MainActor func testPreviewDoesNotSendAndContainsExactSnapshotData() throws {
        let (f, store, model, defaults) = try openAIWorkspace()
        defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let preview = try XCTUnwrap(model.openAITransmissionPreview)
        XCTAssertEqual(preview.input.snapshotID, f.snapshot.id)
        XCTAssertEqual(preview.input.evaluation, f.evaluation)
        XCTAssertTrue(preview.contentJSON.contains("EX-1")); XCTAssertTrue(preview.contentJSON.contains(f.excerpt.text.value))
        XCTAssertEqual(AppOpenAIHTTPStub.count, 0)
        XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts.isEmpty)
    }
    @MainActor func testSendWithoutPreviewDoesNotInvokeHTTP() async throws {
        let (_, _, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertEqual(AppOpenAIHTTPStub.count, 0)
        XCTAssertTrue(model.errorMessage?.contains("Vorschau") == true)
    }
    @MainActor func testCancelledPreviewDoesNotSend() async throws {
        let (f, _, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        model.dismissOpenAIPreview()
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertNil(model.openAITransmissionPreview); XCTAssertEqual(AppOpenAIHTTPStub.count, 0)
    }
    @MainActor func testExplicitSendPersistsDraftWithoutChangingFactsOrReviews() async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        let before = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let previewText = try XCTUnwrap(model.openAITransmissionPreview).contentJSON
        AppOpenAIHTTPStub.onRequest = { request in
            do {
                let bytes = try appRequestBytes(request)
                let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
                let input = try XCTUnwrap(body["input"] as? [[String: Any]])
                let parts = try XCTUnwrap(input.first?["content"] as? [[String: Any]])
                XCTAssertEqual(parts.first?["text"] as? String, previewText)
            } catch { XCTFail("Offline request content could not be inspected") }
        }
        let result = await model.sendOpenAIScript(provider: appProvider())
        let id = try XCTUnwrap(result), after = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)), draft = try XCTUnwrap(after.find(id))
        XCTAssertEqual(draft.status, .draft); XCTAssertNil(draft.approval); XCTAssertEqual(draft.version, 1)
        XCTAssertTrue(after.statements.allSatisfy { $0.review == nil })
        XCTAssertEqual(after.caseEvaluations, before.caseEvaluations); XCTAssertEqual(after.criterionEvaluations, before.criterionEvaluations)
        XCTAssertEqual(after.caseRevisions, before.caseRevisions); XCTAssertEqual(after.methodologies, before.methodologies)
        XCTAssertEqual(after.promiseRevisions, before.promiseRevisions); XCTAssertEqual(after.evidenceLinks, before.evidenceLinks)
        XCTAssertEqual(after.excerpts, before.excerpts); XCTAssertEqual(after.sources, before.sources)
        XCTAssertNil(model.openAITransmissionPreview); XCTAssertNil(model.errorMessage)
        XCTAssertTrue(after.scripts[0].author == .ai(model: appProvider().identifier, templateVersion: "script-contract-1"))
        for entry in after.auditEntries {
            XCTAssertFalse(String(describing: entry).contains("test-key-not-real"))
        }
        for value in defaults.dictionaryRepresentation().values { XCTAssertFalse(String(describing: value).contains("test-key-not-real")) }
    }
    @MainActor func testSecondGenerationCreatesNewVersionWithoutReplacingFirst() async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let result1 = await model.sendOpenAIScript(provider: appProvider()), id1 = try XCTUnwrap(result1)
        let first = try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).find(id1)
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let result2 = await model.sendOpenAIScript(provider: appProvider()), id2 = try XCTUnwrap(result2)
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertNotEqual(id1, id2); XCTAssertEqual(graph.find(id2)?.version, 2); XCTAssertEqual(graph.find(id1), first)
    }
    @MainActor func testMissingAPIKeyRetainsPreviewAndManualWorkflow() async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let preview = model.openAITransmissionPreview
        let provider = OpenAIScriptGenerationProvider(session: appSession(), safetyIdentifier: model.openAISafetyIdentifier, environment: { _ in nil })
        let result = await model.sendOpenAIScript(provider: provider)
        XCTAssertNil(result); XCTAssertEqual(AppOpenAIHTTPStub.count, 0)
        XCTAssertEqual(model.openAITransmissionPreview, preview)
        XCTAssertTrue(model.errorMessage?.contains("OpenAI API key is not configured") == true)
        XCTAssertTrue(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)).scripts.isEmpty)
        let manual = PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0, text: "Synthetic manual fact", kind: .fact, referencedExcerptKeys: ["EX-1"])])
        XCTAssertNotNil(model.createManualScript(evaluationID: f.evaluation.id, output: manual))
    }
    @MainActor func testRefusalNeverCreatesDraft() async throws { try await workspaceFailure(body: refusalBody, message: "Das Modell hat die Anfrage nicht ausgeführt") }
    @MainActor func testIncompleteNeverCreatesDraft() async throws { try await workspaceFailure(body: Data("{\"status\":\"incomplete\",\"output\":[]}".utf8), message: "unvollständig") }
    @MainActor func testUnknownExcerptNeverCreatesDraft() async throws { try await workspaceFailure(body: appResponse(excerptKey: "EX-invented"), message: "ungültige Referenzen") }
    @MainActor func testUnknownEvidenceNeverCreatesDraft() async throws { try await workspaceFailure(body: appResponse(evidenceKey: "EV-invented"), message: "ungültige Referenzen") }
    @MainActor func testNoRawSensitiveErrorBodyShown() async throws {
        let (f, _, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        AppOpenAIHTTPStub.status = 401; AppOpenAIHTTPStub.body = Data("test-key-not-real SYNTHETIC PRIVATE BODY".utf8)
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertTrue(model.errorMessage?.contains("Authentifizierung") == true)
        XCTAssertFalse(model.errorMessage?.contains("test-key-not-real") == true)
        XCTAssertFalse(model.errorMessage?.contains("PRIVATE BODY") == true)
    }
    @MainActor func testReviewRequiredBetweenPreviewAndSendBlocksNetwork() async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        var link = EvidenceLinkDTO(f.evidence); link.id = StoredID(EntityID<EvidenceLink>(), kind: "EvidenceLink")
        try store.addVerifiedEvidence(caseID: f.politicalCase.id, link: link.domain(), reason: text("Synthetic relevant new evidence"), requestedBy: f.reviewer.id, at: Date())
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertEqual(AppOpenAIHTTPStub.count, 0); XCTAssertNil(model.openAITransmissionPreview)
        XCTAssertTrue(model.errorMessage?.contains("Bewertung muss erneut geprüft werden") == true)
    }
    @MainActor func testCaseChangesOutsideSnapshotAlsoInvalidatePreview() async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        var dto = CaseGraphDTO(try XCTUnwrap(store.loadCase(id: f.politicalCase.id)))
        dto.cases[0].title = "Synthetic renamed case"
        try store.saveCase(dto.domain())
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertEqual(AppOpenAIHTTPStub.count, 0); XCTAssertNil(model.openAITransmissionPreview)
        XCTAssertTrue(model.errorMessage?.contains("Vorschau") == true)
    }
    @MainActor func testModelMismatchRequiresNewPreview() async throws {
        let (f, _, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let result = await model.sendOpenAIScript(provider: appProvider(configuration: .init(model: "gpt-6-luna")))
        XCTAssertNil(result); XCTAssertEqual(AppOpenAIHTTPStub.count, 0)
    }
    @MainActor func testSafetyIdentifierStableAcrossWorkspaceReopenAndIndependentOfReviewer() throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        let id = model.openAISafetyIdentifier
        let reopened = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertEqual(reopened.openAISafetyIdentifier, id); XCTAssertNotNil(UUID(uuidString: id))
        XCTAssertNotEqual(id, f.reviewer.id.rawValue.uuidString); XCTAssertFalse(id.contains("@"))
        XCTAssertFalse(id.contains(f.reviewer.displayName.value))
    }
    @MainActor func testBusyStateVisibleAndDuplicateSendBlocked() async throws {
        let (f, _, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        AppOpenAIHTTPStub.hold = true
        let started = expectation(description: "Offline request started")
        AppOpenAIHTTPStub.onRequest = { _ in started.fulfill() }
        let task = Task { await model.sendOpenAIScript(provider: appProvider()) }
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(model.isGeneratingScript)
        let duplicate = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(duplicate); XCTAssertEqual(AppOpenAIHTTPStub.count, 1)
        AppOpenAIHTTPStub.release()
        let result = await task.value
        XCTAssertNotNil(result); XCTAssertFalse(model.isGeneratingScript)
    }
    func testErrorsAreControlledAndReadable() {
        for error in [OpenAIProviderError.missingAPIKey, .authenticationFailed, .permissionDenied, .rateLimited, .serviceUnavailable,
                      .networkFailure, .timeout, .malformedResponse, .structuredOutputMissing, .refused, .incompleteResponse,
                      .invalidProviderReferences, .previewChanged, .invalidRequest] {
            XCTAssertFalse(WorkspaceErrorMessage.describe(error).isEmpty)
            XCTAssertFalse(WorkspaceErrorMessage.describe(error).contains("test-key-not-real"))
        }
    }
    @MainActor private func workspaceFailure(body: Data, message: String) async throws {
        let (f, store, model, defaults) = try openAIWorkspace(); defer { removeDefaults(defaults) }
        XCTAssertTrue(model.prepareOpenAIPreview(evaluationID: f.evaluation.id))
        let preview = model.openAITransmissionPreview
        AppOpenAIHTTPStub.body = body
        let result = await model.sendOpenAIScript(provider: appProvider())
        XCTAssertNil(result); XCTAssertTrue(model.errorMessage?.contains(message) == true)
        XCTAssertEqual(model.openAITransmissionPreview, preview)
        let graph = try XCTUnwrap(store.loadCase(id: f.politicalCase.id))
        XCTAssertTrue(graph.scripts.isEmpty); XCTAssertTrue(graph.statements.isEmpty); XCTAssertTrue(graph.auditEntries.isEmpty)
        XCTAssertEqual(graph.caseEvaluations[0], f.evaluation)
    }
}
@MainActor private func openAIWorkspace() throws -> (AppWorkspaceFixture, LocalCaseStore, CaseWorkspaceModel, UserDefaults) {
    let f = try AppWorkspaceFixture(), store = try LocalCaseStore.inMemory()
    var dto = CaseGraphDTO(f.context()); dto.cases[0].workflowState = "approved"
    try store.saveCase(dto.domain())
    let suite = "SyntheticOpenAIWorkspace-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
    defaults.set(suite, forKey: "openAITestSuite")
    defaults.set(f.reviewer.displayName.value, forKey: "politicalFactCheck.reviewerName")
    defaults.set(f.reviewer.id.rawValue.uuidString, forKey: "politicalFactCheck.reviewerID")
    return (f, store, CaseWorkspaceModel(store: store, defaults: defaults), defaults)
}
private func removeDefaults(_ defaults: UserDefaults) {
    defaults.removePersistentDomain(forName: defaults.string(forKey: "openAITestSuite")!)
}
private func appRequestBytes(_ request: URLRequest) throws -> Data {
    if let data = request.httpBody { return data }
    let stream = try XCTUnwrap(request.httpBodyStream)
    stream.open(); defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while true {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count >= 0 else { throw URLError(.cannotDecodeRawData) }
        if count == 0 { break }
        data.append(contentsOf: buffer.prefix(count))
    }
    return data
}
private func appSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [AppOpenAIHTTPStub.self]
    return URLSession(configuration: config)
}
private func appProvider(configuration: PoliticalFactCheckScripting.OpenAIScriptProviderConfiguration = .init()) -> OpenAIScriptGenerationProvider {
    .init(configuration: configuration, session: appSession(), safetyIdentifier: "2CC73EC5-B74C-463D-A80C-56CC7EA61087", environment: { _ in "test-key-not-real" })
}
private var refusalBody: Data {
    try! JSONSerialization.data(withJSONObject: ["status": "completed", "output": [["type": "message", "role": "assistant", "status": "completed",
        "content": [["type": "refusal", "refusal": "Synthetic refusal"]]]]])
}
private func appResponse(excerptKey: String = "EX-1", evidenceKey: String = "EV-1") -> Data {
    let text = String(data: try! JSONSerialization.data(withJSONObject: ["statements": [["position": 0, "text": "Synthetic sourced fact", "kind": "fact",
        "referencedExcerptKeys": [excerptKey], "referencedEvidenceKeys": [evidenceKey], "uncertainty": NSNull()]]]), encoding: .utf8)!
    return try! JSONSerialization.data(withJSONObject: ["status": "completed", "output": [["type": "message", "role": "assistant", "status": "completed",
        "content": [["type": "output_text", "text": text]]]], "usage": ["input_tokens": 123, "output_tokens": 45]])
}
private final class AppOpenAIHTTPStub: URLProtocol {
    static var status = 200
    static var body = appResponse()
    static var onRequest: ((URLRequest) -> Void)?
    static var hold = false
    private static var pending: AppOpenAIHTTPStub?
    private static let lock = NSLock()
    private static var requests = 0
    static var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    static func reset() { status = 200; body = appResponse(); onRequest = nil; hold = false; pending = nil; lock.lock(); requests = 0; lock.unlock() }
    static func release() { lock.lock(); let value = pending; pending = nil; lock.unlock(); value?.finish() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.requests += 1
        if Self.hold { Self.pending = self }
        Self.lock.unlock()
        Self.onRequest?(request)
        if !Self.hold { finish() }
    }
    private func finish() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
