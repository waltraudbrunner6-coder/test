import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import PoliticalFactCheckResearch

final class CaseResearchProviderTests: XCTestCase {
    func provider(key: String = "synthetic-test-key") -> OpenAICaseResearchProvider { OpenAICaseResearchProvider(session: DiscoveryHTTPStub.session(), environment: { ["OPENAI_API_KEY": key] }) }
    func body(_ f: DeepResearchFixture, _ intent: ResearchIntent) throws -> [String: Any] {
        let criterion = try f.result().proposedCriteria[0]
        let request = try provider().makeRequest(f.request, intent: intent, criterion: intent == .original ? nil : criterion, material: nil, key: "synthetic-test-key")
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses"); XCTAssertEqual(request.httpMethod, "POST")
        return try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any]
    }
    func testResponsesModelReasoningNoStoreOrHistory() throws {
        let f = try DeepResearchFixture(), b = try body(f, .support)
        XCTAssertEqual(b["model"] as? String, "gpt-6.1-sol"); XCTAssertEqual((b["reasoning"] as? [String: Any])?["effort"] as? String, "medium")
        XCTAssertEqual(b["store"] as? Bool, false); XCTAssertNil(b["conversation"]); XCTAssertNil(b["previous_response_id"])
    }
    func testOnlyRealWebSearchRequiredExternalAccessAndSources() throws {
        let f = try DeepResearchFixture(), b = try body(f, .support), tools = try XCTUnwrap(b["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1); XCTAssertEqual(tools[0]["type"] as? String, "web_search")
        XCTAssertEqual(tools[0]["external_web_access"] as? Bool, true); XCTAssertEqual(b["tool_choice"] as? String, "required")
        XCTAssertEqual(b["include"] as? [String], ["web_search_call.action.sources"])
        XCTAssertEqual((tools[0]["filters"] as? [String: Any])?["allowed_domains"] as? [String], ["records.invalid", "source.invalid"])
    }
    func testSupportContradictionSymmetryOnlyIntentDiffers() throws {
        let f = try DeepResearchFixture(), support = try body(f, .support), contra = try body(f, .contradiction)
        for field in ["instructions", "model", "tool_choice"] { XCTAssertEqual(support[field] as? String, contra[field] as? String) }
        XCTAssertEqual(support["max_tool_calls"] as? Int, contra["max_tool_calls"] as? Int)
        XCTAssertEqual(support["max_output_tokens"] as? Int, contra["max_output_tokens"] as? Int)
        for field in ["tools", "text"] { XCTAssertEqual(try JSONSerialization.data(withJSONObject: support[field]!, options: [.sortedKeys]), try JSONSerialization.data(withJSONObject: contra[field]!, options: [.sortedKeys])) }
        var a = try JSONSerialization.jsonObject(with: Data((support["input"] as! String).utf8)) as! [String: Any]
        var b = try JSONSerialization.jsonObject(with: Data((contra["input"] as! String).utf8)) as! [String: Any]
        XCTAssertEqual(a.removeValue(forKey: "intent") as? String, "support"); XCTAssertEqual(b.removeValue(forKey: "intent") as? String, "contradiction")
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: a, options: [.sortedKeys]), try JSONSerialization.data(withJSONObject: b, options: [.sortedKeys]))
    }
    func testStrictSchemaAndResourcePromptMethodologyMatch() throws {
        let f = try DeepResearchFixture(), b = try body(f, .original), text = try XCTUnwrap(b["text"] as? [String: Any]), format = try XCTUnwrap(text["format"] as? [String: Any])
        XCTAssertEqual(format["strict"] as? Bool, true); XCTAssertEqual(CaseResearchSchema.schema["additionalProperties"] as? Bool, false)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let prompt = try String(contentsOf: root.appendingPathComponent("docs/openai-case-research-prompt-v1.md"), encoding: .utf8)
        let methodology = try String(contentsOf: root.appendingPathComponent("docs/methodology-v1.0.md"), encoding: .utf8)
        XCTAssertEqual(b["instructions"] as? String, prompt + "\n\n" + methodology)
    }
    func testCompletedActualSearchNamespacesEvidence() throws {
        let f = try DeepResearchFixture(), criterion = try f.result().proposedCriteria[0]
        let lane = try provider().decode(f.envelope(.support), request: f.request, intent: .support, criterion: criterion)
        XCTAssertTrue(lane.sources[0].searchSource.fromSearch); XCTAssertEqual(lane.output.evidenceProposals[0].evidenceKey, "criterion-1:SUPPORT:ev1")
        XCTAssertEqual(lane.output.evidenceProposals[0].criterionKey, "criterion-1")
    }
    func testMissingActualSearchFails() throws {
        let f = try DeepResearchFixture(); XCTAssertThrowsError(try provider().decode(f.envelope(.support, search: false), request: f.request, intent: .support, criterion: nil))
    }
    func testSourceAbsentFromActualSearchFails() throws {
        let f = try DeepResearchFixture(); XCTAssertThrowsError(try provider().decode(f.envelope(.support, url: "https://records.invalid/other"), request: f.request, intent: .support, criterion: nil))
    }
    func testMissingRequiredNullableFieldRejected() throws {
        let f = try DeepResearchFixture(); var wire = try f.wire(intent: .support); wire.removeValue(forKey: "originalSourceReview")
        XCTAssertThrowsError(try CaseResearchSchema.validateJSON(wire, schema: CaseResearchSchema.schema))
    }
    func testAdditionalReviewStatusFieldRejected() throws {
        let f = try DeepResearchFixture(); var wire = try f.wire(intent: .support); wire["humanReview"] = true
        XCTAssertThrowsError(try CaseResearchSchema.validateJSON(wire, schema: CaseResearchSchema.schema))
    }
    func testWholeProviderRunsOriginalThreeDirectionsThenAssessment() async throws {
        let f = try DeepResearchFixture()
        DiscoveryHTTPStub.reset { request in
            let input = try JSONSerialization.jsonObject(with: Data(((try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any])["input"] as! String).utf8)) as! [String: Any]
            let intent = ResearchIntent(rawValue: input["intent"] as! String)!
            return (200, try f.envelope(intent))
        }
        let result = try await provider().researchCase(request: f.request)
        XCTAssertEqual(DiscoveryHTTPStub.captured().count, 5); XCTAssertEqual(result.proposedCriteria.count, 1)
        XCTAssertTrue(result.coverage[0].permitsRecommendation); XCTAssertEqual(result.overallAssessmentDraft.suggestedCategory, .notVerifiable)
        XCTAssertTrue(result.sources.allSatisfy { $0.searchSource.fromSearch })
    }
    func testTechnicalContradictionFailureSkipsAssessmentAndRecommendsNothing() async throws {
        let f = try DeepResearchFixture()
        DiscoveryHTTPStub.reset { request in
            let input = try JSONSerialization.jsonObject(with: Data(((try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as! [String: Any])["input"] as! String).utf8)) as! [String: Any]
            let intent = ResearchIntent(rawValue: input["intent"] as! String)!
            return intent == .contradiction ? (429, Data()) : (200, try f.envelope(intent))
        }
        let result = try await provider().researchCase(request: f.request)
        XCTAssertEqual(DiscoveryHTTPStub.captured().count, 4); XCTAssertFalse(result.coverage[0].contradictionSearchPerformed)
        XCTAssertNil(result.overallAssessmentDraft.suggestedCategory); XCTAssertNil(result.criterionAssessmentDrafts[0].suggestedCategory)
        XCTAssertFalse(result.issues.isEmpty)
    }
    func testMissingKeySendsNothing() async throws {
        let f = try DeepResearchFixture(); DiscoveryHTTPStub.reset { _ in XCTFail("No network"); return (200, Data()) }
        do { _ = try await provider(key: "").researchCase(request: f.request); XCTFail("Expected failure") } catch { XCTAssertEqual(error as? DiscoveryError, .missingAPIKey) }
        XCTAssertTrue(DiscoveryHTTPStub.captured().isEmpty)
    }
    func testHTTPAuthenticationAndTimeoutControlled() async throws {
        let f = try DeepResearchFixture()
        for (status, expected) in [(401, DiscoveryError.authenticationFailed), (403, .permissionDenied), (408, .timeout), (429, .rateLimited), (503, .serviceUnavailable)] {
            DiscoveryHTTPStub.reset { _ in (status, Data()) }
            do { _ = try await provider().researchCase(request: f.request); XCTFail("Expected controlled failure") } catch { XCTAssertEqual(error as? DiscoveryError, expected) }
        }
    }
}
