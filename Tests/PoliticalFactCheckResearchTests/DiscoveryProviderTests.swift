import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import PoliticalFactCheckResearch

final class DiscoveryProviderTests: XCTestCase {
    let f = DiscoveryFixture()
    func provider(key: String = "synthetic-not-a-secret") -> OpenAIPromiseDiscoveryProvider {
        OpenAIPromiseDiscoveryProvider(session: DiscoveryHTTPStub.session(), environment: { ["OPENAI_API_KEY": key] })
    }
    func body() throws -> [String: Any] { try JSONSerialization.jsonObject(with: XCTUnwrap(provider().makeRequest(f.request, group: f.group, key: "synthetic").httpBody)) as! [String: Any] }
    func decode(_ data: Data) throws -> DiscoveryGroupOutcome { try provider().decode(data, group: f.group, request: f.request) }
    func testModelAndReasoning() throws {
        let b = try body(); XCTAssertEqual(b["model"] as? String, "gpt-6.1-sol")
        XCTAssertEqual((b["reasoning"] as? [String: Any])?["effort"] as? String, "medium")
    }
    func testRealWebSearchRequiredSoleTool() throws {
        let b = try body(), tools = try XCTUnwrap(b["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1); XCTAssertEqual(tools[0]["type"] as? String, "web_search")
        XCTAssertEqual(b["tool_choice"] as? String, "required")
        XCTAssertEqual(tools[0]["external_web_access"] as? Bool, true)
    }
    func testSourceIncludeAndFilters() throws {
        let b = try body(), tool = try XCTUnwrap((b["tools"] as? [[String: Any]])?.first)
        XCTAssertEqual((tool["filters"] as? [String: Any])?["allowed_domains"] as? [String], ["source.invalid"])
        XCTAssertEqual(b["include"] as? [String], ["web_search_call.action.sources"])
        XCTAssertEqual(b["store"] as? Bool, false)
    }
    func testSchemaStrictAllFieldsRequiredNullable() throws {
        let b = try body(), text = try XCTUnwrap(b["text"] as? [String: Any]), format = try XCTUnwrap(text["format"] as? [String: Any])
        XCTAssertEqual(format["strict"] as? Bool, true)
        let schema = OpenAIPromiseDiscoveryProvider.schema
        let properties = try XCTUnwrap(schema["properties"] as? [String: Any]), array = try XCTUnwrap(properties["candidates"] as? [String: Any])
        let item = try XCTUnwrap(array["items"] as? [String: Any]), fields = try XCTUnwrap(item["properties"] as? [String: Any])
        XCTAssertEqual(Set(item["required"] as? [String] ?? []), OpenAIPromiseDiscoveryProvider.candidateKeys)
        XCTAssertEqual(item["additionalProperties"] as? Bool, false)
        for key in OpenAIPromiseDiscoveryProvider.nullableKeys { XCTAssertEqual((fields[key] as? [String: Any])?["type"] as? [String], ["string", "null"]) }
    }
    func testPromptResourceEqualsDocument() throws {
        let http = try provider().makeRequest(f.request, group: f.group, key: "synthetic")
        let b = try JSONSerialization.jsonObject(with: XCTUnwrap(http.httpBody)) as! [String: Any]
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(b["instructions"] as? String, try String(contentsOf: root.appendingPathComponent("docs/openai-promise-discovery-prompt-v1.md"), encoding: .utf8))
    }
    func testEndpointAndSecretOnlyInHeader() throws {
        let http = try provider().makeRequest(f.request, group: f.group, key: "synthetic-secret-marker")
        XCTAssertEqual(http.url?.absoluteString, "https://api.openai.com/v1/responses"); XCTAssertEqual(http.httpMethod, "POST")
        XCTAssertEqual(http.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-secret-marker")
        XCTAssertFalse(String(decoding: try XCTUnwrap(http.httpBody), as: UTF8.self).contains("synthetic-secret-marker"))
    }
    func testAcceptsActualSearchAndCitation() throws {
        let outcome = try decode(f.response()); XCTAssertEqual(outcome.candidates, [f.candidate]); XCTAssertEqual(outcome.sources.count, 1)
        XCTAssertTrue(outcome.sources[0].fromSearch); XCTAssertTrue(outcome.sources[0].cited)
    }
    func testMissingToolCallRejected() throws { XCTAssertThrowsError(try decode(f.response(search: false))) { XCTAssertEqual($0 as? DiscoveryError, .searchNotUsed) } }
    func testMissingSourcesRejected() throws { XCTAssertThrowsError(try decode(f.response(includeSources: false))) { XCTAssertEqual($0 as? DiscoveryError, .missingSearchSources) } }
    func testCitationOnlyCannotCreateCandidate() throws {
        let outcome = try decode(f.response(sources: [])); XCTAssertTrue(outcome.candidates.isEmpty); XCTAssertEqual(outcome.rejections.first?.reason, .unknownSource)
        XCTAssertFalse(outcome.sources[0].fromSearch)
    }
    func testZeroCandidatesValidNoQuotaFilling() throws { XCTAssertTrue(try decode(f.response(entries: [], sources: [])).candidates.isEmpty) }
    func testUnknownURLRejected() throws { XCTAssertEqual(try decode(f.response(entries: [f.entry(["sourceURL": "https://source.invalid/missing"])] )).rejections.first?.reason, .unknownSource) }
    func testWrongDomainRejectedEvenInSearch() throws {
        let result = try decode(f.response(entries: [f.entry(["sourceURL": "https://foreign.invalid/promise"])], sources: [["type": "url", "url": "https://foreign.invalid/promise"]]))
        XCTAssertEqual(result.rejections.first?.reason, .outsidePolicy)
    }
    func testWrongSourceKeyRejected() throws { XCTAssertEqual(try decode(f.response(entries: [f.entry(["sourceReferenceKey": "invented-key"])] )).rejections.first?.reason, .sourceKeyMismatch) }
    func testRefusalRejected() throws { XCTAssertThrowsError(try decode(f.response(refusal: true))) { XCTAssertEqual($0 as? DiscoveryError, .refused) } }
    func testIncompleteRejected() throws { XCTAssertThrowsError(try decode(f.response(status: "incomplete"))) { XCTAssertEqual($0 as? DiscoveryError, .incomplete) } }
    func testMalformedJSONRejected() { XCTAssertThrowsError(try decode(Data("broken".utf8))) }
    func testMissingRequiredFieldRejected() throws {
        var entry = try f.entry(); entry.removeValue(forKey: "locator")
        XCTAssertEqual(try decode(f.response(entries: [entry])).rejections.first?.reason, .invalidStructuredOutput)
    }
    func testExtraFieldRejected() throws { XCTAssertEqual(try decode(f.response(entries: [f.entry(["evaluation": "negative"])] )).rejections.first?.reason, .invalidStructuredOutput) }
    func testWrongFieldTypeRejected() throws { XCTAssertEqual(try decode(f.response(entries: [f.entry(["isOriginalStatement": "yes"])] )).rejections.first?.reason, .invalidStructuredOutput) }
    func testBatchKeepsValidRejectsInvalid() throws {
        let result = try decode(f.response(entries: [f.entry(), f.entry(["candidateKey": "bad", "exactQuote": " "])]))
        XCTAssertEqual(result.candidates.count, 1); XCTAssertEqual(result.rejections.count, 1)
    }
    func testOverBudgetRejectedRatherThanPoliticalTruncation() throws { XCTAssertThrowsError(try decode(f.response(entries: [f.entry(), f.entry(), f.entry()]))) }
    func testDuplicateCandidateKeysRejected() throws { let r = try decode(f.response(entries: [f.entry(), f.entry()])); XCTAssertEqual(r.candidates.count, 1); XCTAssertEqual(r.rejections.count, 1) }
    func testMissingAPIKeyNoNetwork() async throws {
        DiscoveryHTTPStub.reset { _ in XCTFail("Must not send"); return (200, Data()) }
        do { _ = try await provider(key: "").discoverPromises(request: f.request); XCTFail("Expected missing key") }
        catch { XCTAssertEqual(error as? DiscoveryError, .missingAPIKey) }
        XCTAssertTrue(DiscoveryHTTPStub.captured().isEmpty)
    }
    func assertHTTP(_ status: Int, _ expected: DiscoveryError) async throws {
        DiscoveryHTTPStub.reset { _ in (status, Data("synthetic response includes no persistent payload".utf8)) }
        let result = try await provider().discoverPromises(request: f.request)
        XCTAssertEqual(result.outcomes.first?.error, expected); XCTAssertTrue(result.outcomes[0].candidates.isEmpty)
    }
    func testHTTP401() async throws { try await assertHTTP(401, .authenticationFailed) }
    func testHTTP403() async throws { try await assertHTTP(403, .permissionDenied) }
    func testHTTP408() async throws { try await assertHTTP(408, .timeout) }
    func testHTTP429() async throws { try await assertHTTP(429, .rateLimited) }
    func testHTTP500() async throws { try await assertHTTP(500, .serviceUnavailable) }
    func testHTTPUnexpected() async throws { try await assertHTTP(400, .networkFailure) }
    func testTransportTimeoutControlled() async throws {
        DiscoveryHTTPStub.reset { _ in throw URLError(.timedOut) }
        let result = try await provider().discoverPromises(request: f.request)
        XCTAssertEqual(result.outcomes.first?.error, .timeout)
    }
    func testTransportFailureControlled() async throws {
        DiscoveryHTTPStub.reset { _ in throw URLError(.notConnectedToInternet) }
        let result = try await provider().discoverPromises(request: f.request)
        XCTAssertEqual(result.outcomes.first?.error, .networkFailure)
    }
    func testEqualGroupRequestsAndZeroResults() async throws {
        let groupB = ResearchSourceGroup(id: "test-b", label: "Andere synthetische Gruppe", domains: [PolicyDomain(host: "other.invalid", category: .officialParty)])
        let request = PromiseDiscoveryRequest(sourcePolicy: SourcePolicy(version: f.policy.version, groups: [f.group, groupB]), currentDate: f.now)
        let empty = try f.response(entries: [], sources: [])
        DiscoveryHTTPStub.reset { _ in (200, empty) }
        let result = try await provider().discoverPromises(request: request)
        XCTAssertEqual(result.outcomes.count, 2); XCTAssertTrue(result.outcomes.allSatisfy { $0.candidates.isEmpty && $0.error == nil })
        let bodies = try DiscoveryHTTPStub.captured().map { try JSONSerialization.jsonObject(with: XCTUnwrap($0.httpBody)) as! [String: Any] }
        XCTAssertEqual(bodies.count, 2); XCTAssertEqual(bodies[0]["instructions"] as? String, bodies[1]["instructions"] as? String)
        let configs = try bodies.map { try JSONSerialization.jsonObject(with: Data(($0["input"] as! String).utf8)) as! [String: Any] }
        XCTAssertEqual(configs[0]["maxCandidates"] as? Int, configs[1]["maxCandidates"] as? Int)
        XCTAssertEqual(configs[0]["minimumPromiseAgeDays"] as? Int, configs[1]["minimumPromiseAgeDays"] as? Int)
        XCTAssertEqual(configs[0]["allowedDomains"] as? [String], ["source.invalid"]); XCTAssertEqual(configs[1]["allowedDomains"] as? [String], ["other.invalid"])
    }
    func testDefaultPolicyEveryGroupSamePromptBudgetAndInstitutionFilter() async throws {
        let policy = try SourcePolicy.version1(), request = PromiseDiscoveryRequest(sourcePolicy: policy, currentDate: f.now)
        let empty = try f.response(entries: [], sources: [])
        DiscoveryHTTPStub.reset { _ in (200, empty) }
        let result = try await provider().discoverPromises(request: request)
        XCTAssertEqual(result.outcomes.count, 6)
        let bodies = try DiscoveryHTTPStub.captured().map { try JSONSerialization.jsonObject(with: XCTUnwrap($0.httpBody)) as! [String: Any] }
        XCTAssertEqual(bodies.count, 6)
        let prompt = bodies[0]["instructions"] as? String
        for (index, body) in bodies.enumerated() {
            XCTAssertEqual(body["instructions"] as? String, prompt)
            XCTAssertEqual(body["max_tool_calls"] as? Int, 3); XCTAssertEqual(body["max_output_tokens"] as? Int, 8192)
            let tool = try XCTUnwrap((body["tools"] as? [[String: Any]])?.first)
            XCTAssertEqual((tool["filters"] as? [String: Any])?["allowed_domains"] as? [String], policy.groups[index].allowedDomains)
            let config = try JSONSerialization.jsonObject(with: Data((body["input"] as! String).utf8)) as! [String: Any]
            XCTAssertEqual(config["maxCandidates"] as? Int, 2)
        }
    }
    func testSourceMetadataCapturedWithoutRawEnvelope() throws {
        let outcome = try decode(f.response()), source = try XCTUnwrap(outcome.sources.first)
        XCTAssertEqual(source.key, "WEB-1"); XCTAssertEqual(source.domain, "source.invalid")
        XCTAssertEqual(source.researchTimestamp, f.now); XCTAssertEqual(source.policyVersion, f.policy.version)
        XCTAssertEqual(source.category, .officialParty); XCTAssertEqual(source.title, "Synthetische Quelle")
        XCTAssertEqual(outcome.citations.first?.url, f.candidate.sourceURL)
        let record = DiscoveryCandidateRecord(request: f.request, groupID: f.group.id, provider: "synthetic", promptVersion: "synthetic",
            candidate: outcome.candidates[0], sources: outcome.sources, citations: outcome.citations)
        let encoded = try record.encode()
        XCTAssertFalse(encoded.contains("search-synthetic")); XCTAssertFalse(encoded.contains("synthetic-not-a-secret"))
    }

}
