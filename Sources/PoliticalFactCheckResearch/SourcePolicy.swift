import Foundation

public enum ResearchSourceCategory: String, Codable, Equatable {
    case officialParty, parliament, legalInformation, federalGovernment, administration
    public var displayName: String {
        switch self {
        case .officialParty: return "Offizielle Parteiquelle"
        case .parliament: return "Parlament"
        case .legalInformation: return "RIS"
        case .federalGovernment: return "Bundesregierung"
        case .administration: return "Verwaltungsportal"
        }
    }
}
public struct PolicyDomain: Codable, Equatable {
    public let host: String
    public let category: ResearchSourceCategory
    public init(host: String, category: ResearchSourceCategory) { self.host = host; self.category = category }
}
public struct ResearchSourceGroup: Codable, Equatable {
    public let id: String
    public let label: String
    public let domains: [PolicyDomain]
    public var allowedDomains: [String] { domains.map { $0.host } }
    public init(id: String, label: String, domains: [PolicyDomain]) { self.id = id; self.label = label; self.domains = domains }
    public func category(for url: URL) -> ResearchSourceCategory? {
        guard let host = url.host?.lowercased() else { return nil }
        return domains.first { host == $0.host || host.hasSuffix("." + $0.host) }?.category
    }
}
public struct SourcePolicy: Codable, Equatable {
    public let version: String
    public let groups: [ResearchSourceGroup]
    public init(version: String, groups: [ResearchSourceGroup]) { self.version = version; self.groups = groups }
    public static func version1() throws -> SourcePolicy {
        guard let url = Bundle.module.url(forResource: "research-source-policy-v1", withExtension: "json") else { throw DiscoveryError.invalidPolicy }
        let policy = try JSONDecoder().decode(SourcePolicy.self, from: Data(contentsOf: url))
        try policy.validate()
        return policy
    }
    public func validate() throws {
        guard !version.isEmpty, !groups.isEmpty, groups.count <= 16,
              Set(groups.map { $0.id }).count == groups.count else { throw DiscoveryError.invalidPolicy }
        var hosts = Set<String>()
        for group in groups {
            guard !group.id.isEmpty, !group.label.isEmpty, !group.domains.isEmpty else { throw DiscoveryError.invalidPolicy }
            for domain in group.domains {
                guard domain.host == domain.host.lowercased(), domain.host.contains("."),
                      domain.host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ part in
                          !part.isEmpty && part.first != "-" && part.last != "-" && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
                      }), hosts.insert(domain.host).inserted else { throw DiscoveryError.invalidPolicy }
            }
            // Party budgets/queries are always one official domain, never a mixed privileged group.
            if group.domains.contains(where: { $0.category == .officialParty }), group.domains.count != 1 {
                throw DiscoveryError.invalidPolicy
            }
        }
    }
}

public enum DiscoveryIdentity {
    public static func canonicalURL(_ string: String) throws -> String {
        guard var parts = URLComponents(string: string), let scheme = parts.scheme?.lowercased(),
              ["https", "http"].contains(scheme), let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil else { throw DiscoveryError.invalidCandidate }
        parts.scheme = scheme; parts.host = host; parts.fragment = nil
        if parts.path.isEmpty { parts.path = "/" }
        if (scheme == "https" && parts.port == 443) || (scheme == "http" && parts.port == 80) { parts.port = nil }
        guard let url = parts.url else { throw DiscoveryError.invalidCandidate }
        return url.absoluteString
    }
    public static func normalizedQuote(_ quote: String) -> String { quote.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    public static func key(url: String, quote: String) throws -> String {
        try canonicalURL(url) + "\n" + normalizedQuote(quote)
    }
}
