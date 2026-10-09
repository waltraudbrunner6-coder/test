import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import PoliticalFactCheckCore

struct CompletedResearchLane {
    let output: ResearchLaneOutput
    let sources: [ProposedResearchSource]
    let webSources: [ResearchWebSource]
    let citations: [ResearchCitation]
}
public final class OpenAICaseResearchProvider: CaseResearchProvider {
    public static let promptVersion = "openai-case-research-prompt-v1"
    public let identifier = try! NonEmptyText("gpt-6.1-sol")
    private let session: URLSession
    private let environment: () -> [String: String]
    public init(session: URLSession = .shared, environment: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment }) {
        self.session = session; self.environment = environment
    }
    public func researchCase(request: CaseResearchRequest) async throws -> CaseResearchResult {
        try request.validate()
        guard let key = environment()["OPENAI_API_KEY"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DiscoveryError.missingAPIKey }
        let original = try await lane(request, intent: .original, criterion: nil, material: nil, key: key)
        guard let review = original.output.originalSourceReview,
              original.output.proposedCriteria.count <= request.maxCriteria,
              original.output.developments.isEmpty, original.output.evidenceProposals.isEmpty,
              original.output.criterionAssessments.isEmpty, original.output.overallAssessment == nil else { throw CaseResearchError.invalidResult }
        let criteria = original.output.proposedCriteria
        try CaseResearchValidation.unique(criteria.map { $0.criterionKey })
        if review.looksLikeCommitment {
            guard !criteria.isEmpty, let url = try? DiscoveryIdentity.canonicalURL(request.discovery.candidate.sourceURL),
                  original.sources.contains(where: { source in source.searchSource.url == url && original.output.excerpts.contains(where: { $0.sourceKey == source.claim.sourceKey }) }) else { throw CaseResearchError.invalidResult }
        }
        var lanes = [original]; var coverage: [CriterionSearchCoverage] = []; var issues: [ResearchIssue] = []
        for criterion in criteria {
            var completed: [ResearchIntent: CompletedResearchLane] = [:]; var blocked: [String] = []; var failed: [String] = []
            for intent in [ResearchIntent.support, .contradiction, .context] {
                try Task.checkCancellation()
                do {
                    let result = try await lane(request, intent: intent, criterion: criterion, material: nil, key: key)
                    guard result.output.originalSourceReview == nil, result.output.proposedCriteria.isEmpty,
                          result.output.criterionAssessments.isEmpty, result.output.overallAssessment == nil else { throw CaseResearchError.invalidResult }
                    let expected: ResearchRelationship = intent == .support ? .supports : intent == .contradiction ? .contradicts : .contextualizes
                    guard result.output.evidenceProposals.allSatisfy({ $0.criterionKey == criterion.criterionKey && $0.relationship == expected }) else { throw CaseResearchError.invalidReference }
                    completed[intent] = result; lanes.append(result)
                } catch is CancellationError { throw CancellationError() }
                catch {
                    if isValidationFailure(error) { throw error }
                    let name = criterion.criterionKey + ":" + intent.rawValue.uppercased()
                    let message = controlled(error)
                    if let e = error as? DiscoveryError, e == .permissionDenied || e == .authenticationFailed { blocked.append(name) }
                    else { failed.append(name) }
                    issues.append(ResearchIssue(laneID: name, message: message))
                }
            }
            coverage.append(CriterionSearchCoverage(criterionKey: criterion.criterionKey,
                supportSearchPerformed: completed[.support] != nil, contradictionSearchPerformed: completed[.contradiction] != nil, contextSearchPerformed: completed[.context] != nil,
                supportSourceCount: completed[.support]?.webSources.count ?? 0, contradictionSourceCount: completed[.contradiction]?.webSources.count ?? 0,
                contextSourceCount: completed[.context]?.webSources.count ?? 0, blockedQueries: blocked, failedQueries: failed,
                unresolvedQuestions: completed.values.flatMap { $0.output.uncertainties }))
        }
        var assessments = criteria.map { noRecommendation($0.criterionKey, reason: .researchBlocked) }
        var overall = ProposedCaseAssessment(suggestedCategory: nil, confidence: .low, rationale: "Keine abschließende Empfehlung; Rechercheabdeckung oder Originalaussage unzureichend.",
            facts: [], interpretations: [], uncertainties: ["Keine menschlich geprüften Belege"], notVerifiableReasons: [review.looksLikeCommitment ? .researchBlocked : .unclearPromise],
            criterionAssessmentKeys: criteria.map { $0.criterionKey }, decisiveUncertainty: true)
        if review.looksLikeCommitment, !criteria.isEmpty, coverage.allSatisfy({ $0.permitsRecommendation }) {
            let material = ResearchAssessmentMaterial(criteria: criteria, sources: lanes.flatMap { $0.sources }, excerpts: lanes.flatMap { $0.output.excerpts },
                developments: lanes.flatMap { $0.output.developments }, evidence: lanes.flatMap { $0.output.evidenceProposals }, coverage: coverage)
            do {
                let assessment = try await lane(request, intent: .assessment, criterion: nil, material: material, key: key)
                guard let proposal = assessment.output.overallAssessment, assessment.output.originalSourceReview == nil,
                      assessment.output.proposedCriteria.isEmpty, assessment.output.sources.isEmpty, assessment.output.excerpts.isEmpty,
                      assessment.output.developments.isEmpty, assessment.output.evidenceProposals.isEmpty else { throw CaseResearchError.invalidResult }
                assessments = assessment.output.criterionAssessments; overall = proposal; lanes.append(assessment)
            } catch is CancellationError { throw CancellationError() }
            catch {
                if isValidationFailure(error) { throw error }
                issues.append(ResearchIssue(laneID: "ASSESSMENT", message: controlled(error)))
            }
        }
        try Task.checkCancellation()
        let result = CaseResearchResult(originalSourceReview: review, proposedCriteria: criteria, webSources: lanes.flatMap { $0.webSources },
            citations: lanes.flatMap { $0.citations }, sources: lanes.flatMap { $0.sources }, excerpts: lanes.flatMap { $0.output.excerpts },
            developments: lanes.flatMap { $0.output.developments }, evidenceProposals: lanes.flatMap { $0.output.evidenceProposals },
            criterionAssessmentDrafts: assessments, overallAssessmentDraft: overall, coverage: coverage,
            uncertainties: lanes.flatMap { $0.output.uncertainties }, issues: issues, promptVersion: Self.promptVersion,
            startedAt: request.startedAt, completedAt: max(Date(), request.startedAt))
        try CaseResearchValidation.validate(result, request: request)
        return result
    }
    private func noRecommendation(_ key: String, reason: ResearchNotVerifiableReason) -> ProposedCriterionAssessment {
        ProposedCriterionAssessment(criterionKey: key, suggestedCategory: nil, confidence: .low, rationale: "Keine Empfehlung bei unvollständiger automatischer Recherche.",
            supportingEvidenceKeys: [], counterEvidenceKeys: [], facts: [], interpretations: [], uncertainties: ["Ungeprüfter Rechercheentwurf"],
            notVerifiableReasons: [reason], decisiveUncertainty: true, conditionsApplicable: nil)
    }
    private func isValidationFailure(_ error: Error) -> Bool {
        if error is CaseResearchError || error is DecodingError { return true }
        if let e = error as? DiscoveryError { return e == .invalidStructuredOutput || e == .invalidCandidate }
        return false
    }
    private func controlled(_ error: Error) -> String { (error as? DiscoveryError)?.displayMessage ?? (error as? CaseResearchError)?.displayMessage ?? "Rechercheantwort konnte nicht verarbeitet werden." }
    private func lane(_ request: CaseResearchRequest, intent: ResearchIntent, criterion: ProposedCriterion?, material: ResearchAssessmentMaterial?, key: String) async throws -> CompletedResearchLane {
        try Task.checkCancellation(); await request.onProgress?(intent, criterion?.criterionKey)
        let http = try makeRequest(request, intent: intent, criterion: criterion, material: material, key: key)
        do {
            let (data, response) = try await session.data(for: http); try Task.checkCancellation()
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
            do { return try decode(data, request: request, intent: intent, criterion: criterion) }
            catch {
                if error is DiscoveryError || error is CaseResearchError || error is DecodingError { throw error }
                throw DiscoveryError.invalidStructuredOutput
            }
        } catch let e as URLError {
            if e.code == .cancelled { throw CancellationError() }; throw e.code == .timedOut ? DiscoveryError.timeout : .networkFailure
        }
    }
    func makeRequest(_ request: CaseResearchRequest, intent: ResearchIntent, criterion: ProposedCriterion?, material: ResearchAssessmentMaterial?, key: String) throws -> URLRequest {
        let prompt = try resource(Self.promptVersion) + "\n\n" + resource("methodology-v1.0")
        let input = ResearchLaneInput(intent: intent, candidate: request.discovery.candidate, criterion: criterion, material: material,
            cutoff: ISO8601DateFormatter().string(from: request.currentDate), maxCriteria: request.maxCriteria,
            maxResults: request.maxResultsPerLane, allowedDomains: try request.policy.allowedDomains(discovery: request.discovery))
        let body: [String: Any] = ["model": identifier.value, "reasoning": ["effort": "medium"], "store": false,
            "instructions": prompt, "input": String(decoding: try JSONEncoder().encode(input), as: UTF8.self),
            "tools": [["type": "web_search", "external_web_access": true, "filters": ["allowed_domains": input.allowedDomains]]],
            "tool_choice": "required", "include": ["web_search_call.action.sources"], "max_tool_calls": request.searchBudget, "max_output_tokens": 8192,
            "text": ["format": ["type": "json_schema", "name": "case_research", "strict": true, "schema": CaseResearchSchema.schema]]]
        var http = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!); http.httpMethod = "POST"; http.timeoutInterval = 120
        http.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization"); http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]); return http
    }
    private func resource(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md") else { throw CaseResearchError.invalidRequest }
        return try String(contentsOf: url, encoding: .utf8)
    }
    func decode(_ data: Data, request: CaseResearchRequest, intent: ResearchIntent, criterion: ProposedCriterion?) throws -> CompletedResearchLane {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw DiscoveryError.invalidStructuredOutput }
        guard envelope["status"] as? String == "completed" else { throw DiscoveryError.incomplete }
        guard let items = envelope["output"] as? [[String: Any]] else { throw DiscoveryError.invalidStructuredOutput }
        var used = false; var provided = false; var actual: [String: String] = [:]; var citations: [ResearchCitation] = []; var texts: [String] = []
        for item in items {
            if item["type"] as? String == "web_search_call", item["status"] as? String == "completed",
               let action = item["action"] as? [String: Any], action["type"] as? String == "search" {
                used = true
                if let sources = action["sources"] as? [[String: Any]] {
                    provided = true
                    for source in sources {
                        guard source["type"] as? String == "url", let raw = source["url"] as? String,
                              let url = try? DiscoveryIdentity.canonicalURL(raw), let parsed = URL(string: url) else { throw DiscoveryError.invalidStructuredOutput }
                        // Outside-policy search/citation entries are never persisted.
                        if request.policy.category(for: parsed, discovery: request.discovery) != nil { actual[url] = source["title"] as? String ?? "" }
                    }
                }
            }
            if item["type"] as? String == "message" {
                for content in item["content"] as? [[String: Any]] ?? [] {
                    if content["type"] as? String == "refusal" { throw DiscoveryError.refused }
                    if content["type"] as? String == "output_text", let text = content["text"] as? String { texts.append(text) }
                    for annotation in content["annotations"] as? [[String: Any]] ?? [] where annotation["type"] as? String == "url_citation" {
                        if let raw = annotation["url"] as? String, let url = try? DiscoveryIdentity.canonicalURL(raw), let parsed = URL(string: url), request.policy.category(for: parsed, discovery: request.discovery) != nil {
                            citations.append(ResearchCitation(url: url, title: annotation["title"] as? String, startIndex: annotation["start_index"] as? Int, endIndex: annotation["end_index"] as? Int))
                        }
                    }
                }
            }
        }
        guard used else { throw DiscoveryError.searchNotUsed }; guard provided else { throw DiscoveryError.missingSearchSources }
        guard texts.count == 1 else { throw DiscoveryError.invalidStructuredOutput }
        let json = Data(texts[0].utf8), object = try JSONSerialization.jsonObject(with: json)
        try CaseResearchSchema.validateJSON(object, schema: CaseResearchSchema.schema)
        let decoded = try JSONDecoder().decode(ResearchLaneOutput.self, from: json)
        let prefix = (criterion?.criterionKey ?? intent.rawValue.uppercased()) + ":" + intent.rawValue.uppercased() + ":"
        let output = intent == .assessment ? decoded : try namespace(decoded, prefix: prefix)
        guard [output.sources.count, output.excerpts.count, output.developments.count, output.evidenceProposals.count].allSatisfy({ $0 <= request.maxResultsPerLane }) else { throw CaseResearchError.invalidResult }
        let web = actual.keys.sorted().enumerated().map { index, url in
            ResearchWebSource(key: prefix + "WEB-\(index + 1)", url: url, title: actual[url].flatMap { $0.isEmpty ? nil : $0 }, domain: URL(string: url)!.host!,
                researchTimestamp: request.startedAt, policyVersion: request.policy.version, category: nil, fromSearch: true, cited: citations.contains { $0.url == url })
        }
        let sources = try output.sources.map { claim -> ProposedResearchSource in
            let url = try DiscoveryIdentity.canonicalURL(claim.url)
            guard let parsed = URL(string: url), let category = request.policy.category(for: parsed, discovery: request.discovery) else { throw CaseResearchError.outsidePolicy }
            guard let source = web.first(where: { $0.url == url }) else { throw CaseResearchError.missingSearchSource }
            return ProposedResearchSource(claim: claim, searchSource: source, category: category)
        }
        return CompletedResearchLane(output: output, sources: sources, webSources: web, citations: citations)
    }
    private func namespace(_ output: ResearchLaneOutput, prefix: String) throws -> ResearchLaneOutput {
        // Namespace transport keys only; no semantic values or categories are changed.
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(output))
        func visit(_ value: Any, field: String? = nil) -> Any {
            let single = ["sourceKey", "excerptKey", "developmentKey", "evidenceKey"]
            let arrays = ["excerptKeys", "supportingEvidenceKeys", "counterEvidenceKeys"]
            if let field, single.contains(field), let string = value as? String { return prefix + string }
            if let field, arrays.contains(field), let values = value as? [String] { return values.map { prefix + $0 } }
            if let object = value as? [String: Any] { return object.reduce(into: [String: Any]()) { result, pair in result[pair.key] = visit(pair.value, field: pair.key) } }
            if let values = value as? [Any] { return values.map { visit($0) } }
            return value
        }
        return try JSONDecoder().decode(ResearchLaneOutput.self, from: JSONSerialization.data(withJSONObject: visit(json)))
    }
}
struct ResearchAssessmentMaterial: Codable {
    let criteria: [ProposedCriterion]
    let sources: [ProposedResearchSource]
    let excerpts: [ProposedExcerpt]
    let developments: [ProposedDevelopment]
    let evidence: [EvidenceProposal]
    let coverage: [CriterionSearchCoverage]
}
struct ResearchLaneInput: Codable {
    let intent: ResearchIntent
    let candidate: PromiseDiscoveryCandidate
    let criterion: ProposedCriterion?
    let material: ResearchAssessmentMaterial?
    let cutoff: String
    let maxCriteria: Int
    let maxResults: Int
    let allowedDomains: [String]
}
