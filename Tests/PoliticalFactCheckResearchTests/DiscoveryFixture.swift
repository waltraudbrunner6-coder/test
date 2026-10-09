import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch

struct DiscoveryFixture {
    let now = Date(timeIntervalSince1970: 1_759_276_800) // 2025-10-01 UTC
    var group: ResearchSourceGroup { ResearchSourceGroup(id: "test-a", label: "Synthetische Gruppe", domains: [PolicyDomain(host: "source.invalid", category: .officialParty)]) }
    var policy: SourcePolicy { SourcePolicy(version: "synthetic-policy-v1", groups: [group]) }
    var request: PromiseDiscoveryRequest { PromiseDiscoveryRequest(sourcePolicy: policy, currentDate: now) }
    var candidate: PromiseDiscoveryCandidate {
        PromiseDiscoveryCandidate(candidateKey: "candidate-1", title: "Synthetischer Zielzustand", exactQuote: "Wir errichten bis 2024 drei synthetische Einrichtungen.",
            speakerName: "Synthetische Person", partyName: "Synthetische Gruppe", statementDate: "2021-03-01", statementDatePrecision: "day",
            thesis: "Drei Einrichtungen bis 2024", topics: ["Synthetisches Thema"], whyCheckable: "Anzahl und Frist messbar",
            sourceTitle: "Synthetisches Programm", sourceURL: "https://source.invalid/commitment", sourcePublicationDate: "2025-01-01",
            locator: "Abschnitt Synthetische Ziele", uncertainties: ["Originalkontext ungeprüft"], deadline: "2024", hasDeadlineOrCondition: true)
    }
    var sources: [ResearchWebSource] { [ResearchWebSource(key: "WEB-1", url: candidate.sourceURL, title: "Synthetische Quelle",
        domain: "source.invalid", researchTimestamp: now, policyVersion: policy.version, category: .officialParty, fromSearch: true, cited: true)] }
    var citations: [ResearchCitation] { [ResearchCitation(url: candidate.sourceURL, title: "Synthetische Quelle", startIndex: 0, endIndex: 10)] }
    var record: DiscoveryCandidateRecord { DiscoveryCandidateRecord(request: request, groupID: group.id, provider: "synthetic-test-model",
        promptVersion: "synthetic-test-prompt", candidate: candidate, sources: sources, citations: citations) }
    func entry(_ overrides: [String: Any] = [:]) throws -> [String: Any] {
        var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(candidate)) as! [String: Any]
        for key in OpenAIPromiseDiscoveryProvider.nullableKeys where value[key] == nil { value[key] = NSNull() }
        value.merge(overrides) { _, new in new }; return value
    }
    func changed(_ overrides: [String: Any]) throws -> PromiseDiscoveryCandidate {
        try JSONDecoder().decode(PromiseDiscoveryCandidate.self, from: JSONSerialization.data(withJSONObject: entry(overrides)))
    }
    func response(entries: [[String: Any]]? = nil, search: Bool = true, sources: [[String: Any]]? = nil,
                  includeSources: Bool = true, status: String = "completed", refusal: Bool = false) throws -> Data {
        var output: [[String: Any]] = []
        if search {
            var action: [String: Any] = ["type": "search", "queries": ["synthetic query"]]
            if includeSources { action["sources"] = sources ?? [["type": "url", "url": candidate.sourceURL]] }
            output.append(["type": "web_search_call", "id": "search-synthetic", "status": "completed", "action": action])
        }
        let content: [String: Any]
        if refusal { content = ["type": "refusal", "refusal": "synthetic refusal"] }
        else {
            let candidates = try entries ?? [entry()]
            let text = String(decoding: try JSONSerialization.data(withJSONObject: ["candidates": candidates]), as: UTF8.self)
            content = ["type": "output_text", "text": text, "annotations": [["type": "url_citation", "url": candidate.sourceURL, "title": "Synthetische Quelle", "start_index": 0, "end_index": 10]]]
        }
        output.append(["type": "message", "role": "assistant", "content": [content]])
        return try JSONSerialization.data(withJSONObject: ["status": status, "output": output])
    }
}
final class DiscoveryHTTPStub: URLProtocol {
    static let lock = NSLock()
    static var handler: ((URLRequest) throws -> (Int, Data))?
    static var requests: [URLRequest] = []
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = data
        }
        Self.lock.lock(); let handler = Self.handler; Self.requests.append(captured); Self.lock.unlock()
        do {
            guard let handler else { throw URLError(.unsupportedURL) }
            let (status, data) = try handler(captured)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
    static func reset(_ handler: @escaping (URLRequest) throws -> (Int, Data)) {
        lock.lock(); self.handler = handler; requests = []; lock.unlock()
    }
    static func captured() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
    static func session() -> URLSession { let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [Self.self]; return URLSession(configuration: config) }
}
