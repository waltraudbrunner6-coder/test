import Foundation
import PoliticalFactCheckCore
@testable import PoliticalFactCheckResearch

struct DeepResearchFixture {
    let now = Date(timeIntervalSince1970: 1_759_276_800)
    let graph: DomainContext
    let discovery: DiscoveryCandidateRecord
    let policy: EvidenceSourcePolicy
    init() throws {
        let timestamp = Date(timeIntervalSince1970: 1_759_276_800)
        let group = ResearchSourceGroup(id: "synthetic-group", label: "Synthetische Gruppe", domains: [PolicyDomain(host: "source.invalid", category: .officialParty)])
        let p = SourcePolicy(version: "synthetic-discovery", groups: [group])
        let candidate = PromiseDiscoveryCandidate(candidateKey: "synthetic", title: "Synthetisches Ziel", exactQuote: "Wir errichten bis 2024 drei synthetische Einrichtungen.",
            speakerName: "Synthetische Person", partyName: "Synthetische Gruppe", statementDate: "2021", statementDatePrecision: "year", thesis: "Drei Einrichtungen bis 2024",
            whyCheckable: "Anzahl und Frist", sourceURL: "https://source.invalid/commitment", locator: "Abschnitt Synthetische Ziele", uncertainties: ["Ungeprüft"])
        let source = ResearchWebSource(key: "WEB-1", url: candidate.sourceURL, title: nil, domain: "source.invalid", researchTimestamp: timestamp, policyVersion: p.version, category: .officialParty, fromSearch: true, cited: false)
        let discovered = DiscoveryCandidateRecord(request: PromiseDiscoveryRequest(sourcePolicy: p, currentDate: timestamp), groupID: group.id,
            provider: "synthetic-discovery-model", promptVersion: "synthetic-discovery-prompt", candidate: candidate, sources: [source], citations: [])
        discovery = discovered
        graph = try DiscoveryCandidateMapper.graph(discovered)
        policy = try JSONDecoder().decode(EvidenceSourcePolicy.self, from: Data(#"{"version":"synthetic-evidence-v1","domains":[{"host":"records.invalid","category":"parliament"}]}"#.utf8))
    }
    var request: CaseResearchRequest { CaseResearchRequest(caseID: graph.cases[0].id, promiseRevisionID: graph.cases[0].currentPromiseRevisionID, discovery: discovery, policy: policy, currentDate: now, startedAt: now) }
    func source() -> ResearchWebSource { ResearchWebSource(key: "SUPPORT:WEB-1", url: "https://records.invalid/outcome", title: "Synthetischer Bericht", domain: "records.invalid", researchTimestamp: now, policyVersion: policy.version, category: nil, fromSearch: true, cited: false) }
    func object() throws -> [String: Any] {
        let e = JSONEncoder(); e.dateEncodingStrategy = .millisecondsSince1970
        let web = try JSONSerialization.jsonObject(with: e.encode(source()))
        let review: [String: Any] = ["context": "Synthetischer Originalkontext", "looksLikeCommitment": true, "statementDate": "2021", "statementDatePrecision": "year", "uncertainties": ["Ungeprüft"]]
        let criterion: [String: Any] = ["criterionKey": "criterion-1", "goal": "Drei synthetische Einrichtungen", "targetGroup": "Synthetischer Umfang", "baseline": NSNull(), "deadline": "2024", "conditions": [], "isCore": true, "materialityRule": "Anzahl und Frist sind Kernbestandteile", "uncertainties": []]
        let claim: [String: Any] = ["sourceKey": "s1", "url": "https://records.invalid/outcome", "title": "Synthetischer Bericht", "publisher": NSNull(), "author": NSNull(), "publicationDate": "2025", "eventDate": "2023", "contentType": NSNull(), "language": "de"]
        let excerpt: [String: Any] = ["excerptKey": "e1", "sourceKey": "s1", "text": "Synthetischer dokumentierter Verfahrensstand.", "locator": "Abschnitt Test", "context": "Synthetischer Kontext", "language": "de", "eventDate": "2023", "uncertainties": []]
        let development: [String: Any] = ["developmentKey": "d1", "title": "Synthetische Umsetzung", "type": "implementation", "description": "Synthetische Entwicklung dokumentiert", "eventDate": "2023", "proceduralState": "Synthetisch umgesetzt", "scope": NSNull(), "excerptKeys": ["e1"], "uncertainties": []]
        let evidence: [String: Any] = ["evidenceKey": "ev1", "criterionKey": "criterion-1", "excerptKeys": ["e1"], "developmentKey": "d1", "relationship": "supports", "directness": "direct", "rationale": "Synthetischer relevanter Verfahrensschritt", "temporalRole": "event", "temporalDate": "2023", "uncertainties": []]
        let assessment: [String: Any] = ["criterionKey": "criterion-1", "suggestedCategory": "notVerifiable", "confidence": "low", "rationale": "Gesamtumfang synthetisch noch ungeklärt", "supportingEvidenceKeys": ["ev1"], "counterEvidenceKeys": [], "facts": ["Synthetischer Schritt berichtet"], "interpretations": [], "uncertainties": ["Umfang ungeprüft"], "notVerifiableReasons": ["missingEvidence"], "decisiveUncertainty": true, "conditionsApplicable": NSNull()]
        let overall: [String: Any] = ["suggestedCategory": "notVerifiable", "confidence": "low", "rationale": "Synthetische Lücken", "facts": [], "interpretations": [], "uncertainties": ["Ungeprüft"], "notVerifiableReasons": ["missingEvidence"], "criterionAssessmentKeys": ["criterion-1"], "decisiveUncertainty": true]
        let coverage: [String: Any] = ["criterionKey": "criterion-1", "supportSearchPerformed": true, "contradictionSearchPerformed": true, "contextSearchPerformed": true, "supportSourceCount": 1, "contradictionSourceCount": 0, "contextSourceCount": 0, "blockedQueries": [], "failedQueries": [], "unresolvedQuestions": ["Synthetische offene Frage"]]
        let originalWeb = ResearchWebSource(key: "ORIGINAL:WEB-1", url: discovery.candidate.sourceURL, title: nil, domain: "source.invalid", researchTimestamp: now,
            policyVersion: policy.version, category: nil, fromSearch: true, cited: false)
        let originalWebJSON = try JSONSerialization.jsonObject(with: e.encode(originalWeb))
        var originalClaim = claim; originalClaim["sourceKey"] = "original-source"; originalClaim["url"] = discovery.candidate.sourceURL
        var originalExcerpt = excerpt; originalExcerpt["excerptKey"] = "original-excerpt"; originalExcerpt["sourceKey"] = "original-source"
        originalExcerpt["text"] = discovery.candidate.exactQuote; originalExcerpt["locator"] = discovery.candidate.locator
        return ["originalSourceReview": review, "proposedCriteria": [criterion], "webSources": [web, originalWebJSON], "citations": [], "sources": [["claim": claim, "searchSource": web, "category": "parliament"], ["claim": originalClaim, "searchSource": originalWebJSON, "category": "originalPromiseSource"]], "excerpts": [excerpt, originalExcerpt], "developments": [development], "evidenceProposals": [evidence], "criterionAssessmentDrafts": [assessment], "overallAssessmentDraft": overall, "coverage": [coverage], "uncertainties": ["Ungeprüft"], "issues": [], "promptVersion": "synthetic-case-research-prompt", "startedAt": now.timeIntervalSince1970 * 1000, "completedAt": now.timeIntervalSince1970 * 1000]
    }
    func result(_ modify: ((inout [String: Any]) -> Void)? = nil) throws -> CaseResearchResult {
        var object = try object(); modify?(&object)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(CaseResearchResult.self, from: JSONSerialization.data(withJSONObject: object))
    }
    func record(_ result: CaseResearchResult? = nil) throws -> DeepResearchRecordV1 { DeepResearchRecordV1(request: request, provider: "synthetic-research-model", result: try result ?? self.result()) }
    func wire(intent: ResearchIntent) throws -> [String: Any] {
        let value = try object()
        var wire: [String: Any] = ["originalSourceReview": NSNull(), "proposedCriteria": [], "sources": [], "excerpts": [], "developments": [], "evidenceProposals": [], "criterionAssessments": [], "overallAssessment": NSNull(), "uncertainties": ["Ungeprüft"]]
        if intent == .original {
            wire["originalSourceReview"] = value["originalSourceReview"]; wire["proposedCriteria"] = value["proposedCriteria"]
            var claim = (value["sources"] as! [[String: Any]])[0]["claim"] as! [String: Any]; claim["url"] = discovery.candidate.sourceURL
            wire["sources"] = [claim]; var excerpt = (value["excerpts"] as! [[String: Any]])[0]; excerpt["text"] = discovery.candidate.exactQuote; wire["excerpts"] = [excerpt]
        } else if intent == .assessment {
            var assessment = (value["criterionAssessmentDrafts"] as! [[String: Any]])[0]; assessment["supportingEvidenceKeys"] = []; wire["criterionAssessments"] = [assessment]; wire["overallAssessment"] = value["overallAssessmentDraft"]
        } else if intent == .support {
            wire["sources"] = [(value["sources"] as! [[String: Any]])[0]["claim"]!]
            wire["excerpts"] = [(value["excerpts"] as! [[String: Any]])[0]]; wire["developments"] = value["developments"]; wire["evidenceProposals"] = value["evidenceProposals"]
        }
        return wire
    }
    func envelope(_ intent: ResearchIntent, search: Bool = true, url: String? = nil) throws -> Data {
        let text = String(decoding: try JSONSerialization.data(withJSONObject: wire(intent: intent)), as: UTF8.self)
        var items: [[String: Any]] = []
        if search { items.append(["type": "web_search_call", "status": "completed", "action": ["type": "search", "sources": [["type": "url", "url": url ?? (intent == .original ? discovery.candidate.sourceURL : "https://records.invalid/outcome")]]]]) }
        items.append(["type": "message", "content": [["type": "output_text", "text": text, "annotations": []]]])
        return try JSONSerialization.data(withJSONObject: ["status": "completed", "output": items])
    }
}
func changeAssessment(_ object: inout [String: Any], category: Any, confidence: String = "high", supporting: [String] = ["ev1"], counter: [String] = []) {
    var a = (object["criterionAssessmentDrafts"] as! [[String: Any]])[0]
    a["suggestedCategory"] = category; a["confidence"] = confidence; a["decisiveUncertainty"] = false; a["supportingEvidenceKeys"] = supporting; a["counterEvidenceKeys"] = counter; a["conditionsApplicable"] = true
    object["criterionAssessmentDrafts"] = [a]
    var overall = object["overallAssessmentDraft"] as! [String: Any]; overall["suggestedCategory"] = category; overall["confidence"] = confidence; overall["decisiveUncertainty"] = false; object["overallAssessmentDraft"] = overall
}
extension DeepResearchFixture {
    func result(for request: CaseResearchRequest) throws -> CaseResearchResult {
        let r = try result()
        func timestamp(_ s: ResearchWebSource) -> ResearchWebSource { ResearchWebSource(key: s.key, url: s.url, title: s.title, domain: s.domain,
            researchTimestamp: request.startedAt, policyVersion: s.policyVersion, category: s.category, fromSearch: s.fromSearch, cited: s.cited) }
        return CaseResearchResult(originalSourceReview: r.originalSourceReview, proposedCriteria: r.proposedCriteria, webSources: r.webSources.map(timestamp), citations: r.citations,
            sources: r.sources.map { ProposedResearchSource(claim: $0.claim, searchSource: timestamp($0.searchSource), category: $0.category) },
            excerpts: r.excerpts, developments: r.developments, evidenceProposals: r.evidenceProposals, criterionAssessmentDrafts: r.criterionAssessmentDrafts,
            overallAssessmentDraft: r.overallAssessmentDraft, coverage: r.coverage, uncertainties: r.uncertainties, issues: r.issues,
            promptVersion: r.promptVersion, startedAt: request.startedAt, completedAt: request.startedAt)
    }
}
