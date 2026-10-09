import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PoliticalFactCheckCore

public final class OpenAIPromiseDiscoveryProvider: PromiseDiscoveryProvider {
    public static let promptVersion = "openai-promise-discovery-prompt-v1"
    public let identifier: NonEmptyText
    private let session: URLSession
    private let environment: () -> [String: String]
    public init(session: URLSession = .shared, environment: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment }) {
        self.session = session; self.environment = environment
        identifier = try! NonEmptyText("gpt-6.1-sol")
    }
    public func discoverPromises(request: PromiseDiscoveryRequest) async throws -> PromiseDiscoveryResult {
        try request.validate()
        guard let key = environment()["OPENAI_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DiscoveryError.missingAPIKey }
        var outcomes: [DiscoveryGroupOutcome] = []
        for group in request.sourcePolicy.groups {
            try Task.checkCancellation()
            do {
                let http = try makeRequest(request, group: group, key: key)
                let (data, response) = try await session.data(for: http)
                try Task.checkCancellation()
                guard let response = response as? HTTPURLResponse else { throw DiscoveryError.networkFailure }
                switch response.statusCode {
                case 200...299: break
                case 401: throw DiscoveryError.authenticationFailed
                case 403: throw DiscoveryError.permissionDenied
                case 408: throw DiscoveryError.timeout
                case 429: throw DiscoveryError.rateLimited
                case 500...599: throw DiscoveryError.serviceUnavailable
                default: throw DiscoveryError.networkFailure
                }
                outcomes.append(try decode(data, group: group, request: request))
            } catch is CancellationError { throw CancellationError() }
            catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                outcomes.append(DiscoveryGroupOutcome(group: group, candidates: [], error: error.code == .timedOut ? .timeout : .networkFailure, searched: false))
            } catch {
                outcomes.append(DiscoveryGroupOutcome(group: group, candidates: [], error: error as? DiscoveryError ?? .invalidStructuredOutput, searched: false))
            }
        }
        return PromiseDiscoveryResult(outcomes: outcomes, promptVersion: Self.promptVersion)
    }
    func makeRequest(_ request: PromiseDiscoveryRequest, group: ResearchSourceGroup, key: String) throws -> URLRequest {
        guard let promptURL = Bundle.module.url(forResource: Self.promptVersion, withExtension: "md") else { throw DiscoveryError.invalidRequest }
        let prompt = try String(contentsOf: promptURL, encoding: .utf8)
        let config: [String: Any] = ["allowedDomains": group.allowedDomains, "maxCandidates": request.maxCandidates,
            "currentDate": ISO8601DateFormatter().string(from: request.currentDate), "minimumPromiseAgeDays": request.minimumPromiseAge,
            "language": request.language, "country": request.country, "sourcePolicyVersion": request.sourcePolicy.version]
        let input = String(decoding: try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys]), as: UTF8.self)
        let body: [String: Any] = ["model": identifier.value, "reasoning": ["effort": "medium"], "store": false,
            "instructions": prompt, "input": input,
            "tools": [["type": "web_search", "external_web_access": true, "filters": ["allowed_domains": group.allowedDomains]]],
            "tool_choice": "required", "max_tool_calls": 3, "max_output_tokens": 8192, "include": ["web_search_call.action.sources"],
            "text": ["format": ["type": "json_schema", "name": "promise_discovery", "strict": true, "schema": Self.schema]]]
        var http = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        http.httpMethod = "POST"; http.timeoutInterval = 120
        http.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return http
    }
    static let stringKeys = ["candidateKey", "title", "exactQuote", "thesis", "whyCheckable", "sourceURL", "locator", "statementKind"]
    static let nullableKeys = ["speakerName", "partyName", "statementDate", "statementDatePrecision", "sourceReferenceKey", "sourceTitle", "sourcePublicationDate", "deadline"]
    static let boolKeys = ["isOriginalStatement", "concreteTarget", "observableOutcome", "hasDeadlineOrCondition"]
    static let arrayKeys = ["topics", "uncertainties"]
    static var candidateKeys: Set<String> { Set(stringKeys + nullableKeys + boolKeys + arrayKeys) }
    static var schema: [String: Any] {
        var properties: [String: Any] = [:]
        for key in stringKeys { properties[key] = ["type": "string"] }
        for key in nullableKeys { properties[key] = ["type": ["string", "null"]] }
        for key in boolKeys { properties[key] = ["type": "boolean"] }
        for key in arrayKeys { properties[key] = ["type": "array", "items": ["type": "string"]] }
        return ["type": "object", "additionalProperties": false, "required": ["candidates"], "properties": [
            "candidates": ["type": "array", "items": ["type": "object", "additionalProperties": false,
                "required": candidateKeys.sorted(), "properties": properties]]]]
    }
    func decode(_ data: Data, group: ResearchSourceGroup, request: PromiseDiscoveryRequest) throws -> DiscoveryGroupOutcome {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DiscoveryError.invalidStructuredOutput }
        guard envelope["status"] as? String == "completed" else { throw DiscoveryError.incomplete }
        guard let output = envelope["output"] as? [[String: Any]] else { throw DiscoveryError.invalidStructuredOutput }
        var searchUsed = false; var sourcesProvided = false
        var searched: [String: String] = [:]; var citations: [ResearchCitation] = []; var text: [String] = []
        for item in output {
            if item["type"] as? String == "web_search_call", item["status"] as? String == "completed",
               let action = item["action"] as? [String: Any], action["type"] as? String == "search" {
                searchUsed = true
                if let sources = action["sources"] as? [[String: Any]] {
                    sourcesProvided = true
                    for source in sources {
                        guard source["type"] as? String == "url", let url = source["url"] as? String,
                              let canonical = try? DiscoveryIdentity.canonicalURL(url) else { throw DiscoveryError.invalidStructuredOutput }
                        searched[canonical] = source["title"] as? String ?? ""
                    }
                }
            }
            if item["type"] as? String == "message", let content = item["content"] as? [[String: Any]] {
                for part in content {
                    if part["type"] as? String == "refusal" { throw DiscoveryError.refused }
                    if part["type"] as? String == "output_text", let value = part["text"] as? String { text.append(value) }
                    for annotation in part["annotations"] as? [[String: Any]] ?? [] where annotation["type"] as? String == "url_citation" {
                        guard let url = annotation["url"] as? String, let canonical = try? DiscoveryIdentity.canonicalURL(url) else { throw DiscoveryError.invalidStructuredOutput }
                        citations.append(ResearchCitation(url: canonical, title: annotation["title"] as? String,
                            startIndex: annotation["start_index"] as? Int, endIndex: annotation["end_index"] as? Int))
                    }
                }
            }
        }
        guard searchUsed else { throw DiscoveryError.searchNotUsed }
        guard sourcesProvided else { throw DiscoveryError.missingSearchSources }
        let urls = Set(searched.keys).union(citations.map { $0.url }).sorted()
        let sources = urls.enumerated().map { index, url in
            ResearchWebSource(key: "WEB-\(index + 1)", url: url,
                title: searched[url].flatMap { $0.isEmpty ? nil : $0 } ?? citations.first(where: { $0.url == url })?.title,
                domain: URL(string: url)!.host!.lowercased(), researchTimestamp: request.currentDate,
                policyVersion: request.sourcePolicy.version, category: group.category(for: URL(string: url)!),
                fromSearch: searched[url] != nil, cited: citations.contains { $0.url == url })
        }
        guard text.count == 1, let json = text[0].data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: json) as? [String: Any], Set(object.keys) == ["candidates"],
              let entries = object["candidates"] as? [[String: Any]], entries.count <= request.maxCandidates else { throw DiscoveryError.invalidStructuredOutput }
        var accepted: [PromiseDiscoveryCandidate] = []; var rejected: [DiscoveryRejection] = []; var keys: Set<String> = []
        for entry in entries {
            let key = entry["candidateKey"] as? String ?? "invalid"
            do {
                guard Set(entry.keys) == Self.candidateKeys, keys.insert(key).inserted else { throw DiscoveryError.invalidStructuredOutput }
                let candidate = try JSONDecoder().decode(PromiseDiscoveryCandidate.self, from: JSONSerialization.data(withJSONObject: entry))
                try DiscoveryValidation.validate(candidate, sources: sources, group: group, request: request)
                accepted.append(candidate)
            } catch { rejected.append(DiscoveryRejection(candidateKey: key, reason: error as? DiscoveryError ?? .invalidStructuredOutput)) }
        }
        return DiscoveryGroupOutcome(group: group, candidates: accepted, sources: sources, citations: citations, rejections: rejected)
    }
}
