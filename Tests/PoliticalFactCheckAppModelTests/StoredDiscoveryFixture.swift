import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

struct StoredDiscoveryFixture {
    let now = Date(timeIntervalSince1970: 1_759_276_800)
    var group: ResearchSourceGroup { ResearchSourceGroup(id: "synthetic-group", label: "Synthetische Gruppe", domains: [PolicyDomain(host: "source.invalid", category: .officialParty)]) }
    var policy: SourcePolicy { SourcePolicy(version: "synthetic-policy-v1", groups: [group]) }
    var request: PromiseDiscoveryRequest { PromiseDiscoveryRequest(sourcePolicy: policy, currentDate: now) }
    func record(quote: String = "Wir errichten drei synthetische Einrichtungen.", url: String = "https://source.invalid/commitment", validSource: Bool = true) -> DiscoveryCandidateRecord {
        let candidate = PromiseDiscoveryCandidate(candidateKey: "synthetic-1", title: "Synthetischer Kandidat", exactQuote: quote,
            speakerName: "Synthetische Person", partyName: "Synthetische Partei", statementDate: "2021", statementDatePrecision: "year",
            thesis: "Anzahl prüfen", whyCheckable: "Anzahl messbar", sourceTitle: "Synthetische Originalquelle", sourceURL: url,
            sourcePublicationDate: "2025", locator: "Abschnitt Test", uncertainties: ["Kontext ungeprüft"])
        let source = ResearchWebSource(key: "WEB-1", url: (try? DiscoveryIdentity.canonicalURL(url)) ?? url, title: "Synthetische Quelle",
            domain: URL(string: url)?.host?.lowercased() ?? "", researchTimestamp: now, policyVersion: policy.version,
            category: .officialParty, fromSearch: validSource, cited: false)
        return DiscoveryCandidateRecord(request: request, groupID: group.id, provider: "synthetic-test-model", promptVersion: "synthetic-test-prompt",
            candidate: candidate, sources: [source], citations: [])
    }
    var result: PromiseDiscoveryResult {
        let r = record()
        return PromiseDiscoveryResult(outcomes: [DiscoveryGroupOutcome(group: group, candidates: [r.candidate], sources: r.sources)])
    }
}
