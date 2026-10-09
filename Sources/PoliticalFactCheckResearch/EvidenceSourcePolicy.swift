import Foundation

public enum EvidenceSourceCategory: String, Codable {
    case originalPromiseSource, officialPartySource, parliament, lawOrRegulation, government, publicAdministration, officialStatistics, auditInstitution, otherOfficialPrimary
    public var isInstitutional: Bool { self != .originalPromiseSource && self != .officialPartySource }
}
public struct EvidencePolicyDomain: Codable, Equatable {
    public let host: String
    public let category: EvidenceSourceCategory
}
public struct EvidenceSourcePolicy: Codable, Equatable {
    public let version: String
    public let domains: [EvidencePolicyDomain]
    public static func version1() throws -> Self {
        guard let url = Bundle.module.url(forResource: "evidence-source-policy-v1", withExtension: "json") else { throw CaseResearchError.invalidRequest }
        let policy = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)); try policy.validate(); return policy
    }
    public func validate() throws {
        guard !version.isEmpty, !domains.isEmpty, Set(domains.map { $0.host }).count == domains.count else { throw CaseResearchError.invalidRequest }
        try SourcePolicy(version: version, groups: [ResearchSourceGroup(id: "evidence", label: "evidence", domains: domains.map { PolicyDomain(host: $0.host, category: .administration) })]).validate()
    }
    public func allowedDomains(discovery: DiscoveryCandidateRecord) throws -> [String] {
        let original = try DiscoveryIdentity.canonicalURL(discovery.candidate.sourceURL)
        guard let host = URL(string: original)?.host else { throw CaseResearchError.invalidRequest }
        return Set(domains.map { $0.host } + discovery.policy.groups.flatMap { $0.domains.filter { $0.category == .officialParty }.map { $0.host } } + [host]).sorted()
    }
    public func category(for url: URL, discovery: DiscoveryCandidateRecord) -> EvidenceSourceCategory? {
        if (try? DiscoveryIdentity.canonicalURL(url.absoluteString)) == (try? DiscoveryIdentity.canonicalURL(discovery.candidate.sourceURL)) { return .originalPromiseSource }
        guard let host = url.host?.lowercased() else { return nil }
        // Specific domain categories precede the broad gv.at boundary rule.
        let candidates = domains.sorted { $0.host.count > $1.host.count }
        if let value = candidates.first(where: { host == $0.host || host.hasSuffix("." + $0.host) }) { return value.category }
        let parties = discovery.policy.groups.flatMap { $0.domains.filter { $0.category == .officialParty } }
        if parties.contains(where: { host == $0.host || host.hasSuffix("." + $0.host) }) { return .officialPartySource }
        if let original = URL(string: discovery.candidate.sourceURL)?.host?.lowercased(), host == original || host.hasSuffix("." + original) { return .originalPromiseSource }
        return nil
    }
}
