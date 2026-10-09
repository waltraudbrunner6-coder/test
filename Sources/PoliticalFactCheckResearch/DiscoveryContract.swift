import Foundation
import PoliticalFactCheckCore

public enum DiscoveryError: String, Error, Codable, Equatable {
    case invalidPolicy, invalidRequest, missingAPIKey, authenticationFailed, permissionDenied, rateLimited
    case serviceUnavailable, timeout, networkFailure, refused, incomplete, invalidStructuredOutput
    case searchNotUsed, missingSearchSources, unknownSource, outsidePolicy, sourceKeyMismatch
    case invalidCandidate, notPrimaryCommitment, tooRecent, futureStatement, duplicateSkipped
    case scanInProgress, invalidStoredMetadata
    public var displayMessage: String {
        switch self {
        case .missingAPIKey: return "OpenAI API key is not configured. Die Recherche wurde nicht gestartet."
        case .authenticationFailed: return "OpenAI hat den Zugangsschlüssel abgewiesen."
        case .permissionDenied: return "Für Modell oder Web Search fehlt die OpenAI-Berechtigung."
        case .rateLimited: return "OpenAI-Limit erreicht. Bitte später erneut recherchieren."
        case .serviceUnavailable: return "OpenAI ist vorübergehend nicht verfügbar."
        case .timeout: return "Die Rechercheanfrage hat zu lange gedauert."
        case .networkFailure: return "Die Verbindung für die Recherche ist fehlgeschlagen."
        case .refused: return "Das Modell hat die Recherche nicht ausgeführt."
        case .incomplete: return "Die Rechercheantwort ist unvollständig und wurde nicht übernommen."
        case .searchNotUsed: return "In der Antwort fehlt eine abgeschlossene Websuche."
        case .missingSearchSources: return "Die Websuche hat keine nachvollziehbare Quellenliste geliefert."
        case .unknownSource: return "Die Kandidatenquelle fehlt in den tatsächlichen Web-Search-Sources."
        case .outsidePolicy: return "Die Kandidatenquelle liegt außerhalb der erlaubten Domains."
        case .sourceKeyMismatch: return "Quellenkennung und tatsächliche Webquelle stimmen nicht überein."
        case .notPrimaryCommitment: return "Keine konkrete Verpflichtung aus einer Originalquelle."
        case .tooRecent: return "Das Versprechen ist für diese Recherche-Runde zu jung."
        case .futureStatement: return "Das behauptete Aussagedatum liegt in der Zukunft."
        case .duplicateSkipped: return "Bereits vorhandener Kandidat wurde übersprungen."
        case .scanInProgress: return "Eine Recherche-Runde läuft bereits."
        case .invalidStoredMetadata: return "Die gespeicherten Recherchemetadaten sind beschädigt."
        case .invalidPolicy: return "Die versionierte Quellenpolitik ist ungültig."
        case .invalidRequest: return "Die Recherchekonfiguration ist ungültig."
        case .invalidStructuredOutput, .invalidCandidate: return "Die Rechercheantwort enthält ungültige Kandidatendaten."
        }
    }
}
public struct PromiseDiscoveryRequest: Equatable {
    public let sourcePolicy: SourcePolicy
    public let maxCandidates: Int
    public let currentDate: Date
    public let minimumPromiseAge: Int // Calendar days, not a political assessment.
    public let language: String
    public let country: String
    public init(sourcePolicy: SourcePolicy, maxCandidates: Int = 2, currentDate: Date = Date(),
                minimumPromiseAge: Int = 180, language: String = "de", country: String = "Austria") {
        self.sourcePolicy = sourcePolicy; self.maxCandidates = maxCandidates; self.currentDate = currentDate
        self.minimumPromiseAge = minimumPromiseAge; self.language = language; self.country = country
    }
    public func validate() throws {
        try sourcePolicy.validate()
        guard (1...5).contains(maxCandidates), (0...3650).contains(minimumPromiseAge), language == "de", country == "Austria",
              currentDate.timeIntervalSinceReferenceDate.isFinite else { throw DiscoveryError.invalidRequest }
    }
}
public protocol PromiseDiscoveryProvider {
    var identifier: NonEmptyText { get }
    func discoverPromises(request: PromiseDiscoveryRequest) async throws -> PromiseDiscoveryResult
}
public struct ResearchCitation: Codable, Equatable {
    public let url: String
    public let title: String?
    public let startIndex: Int?
    public let endIndex: Int?
    public init(url: String, title: String?, startIndex: Int?, endIndex: Int?) {
        self.url = url; self.title = title; self.startIndex = startIndex; self.endIndex = endIndex
    }
}
public struct ResearchWebSource: Codable, Equatable {
    public let key: String
    public let url: String
    public let title: String?
    public let domain: String
    public let researchTimestamp: Date
    public let policyVersion: String
    public let category: ResearchSourceCategory?
    public let fromSearch: Bool
    public let cited: Bool
    public init(key: String, url: String, title: String?, domain: String, researchTimestamp: Date,
                policyVersion: String, category: ResearchSourceCategory?, fromSearch: Bool, cited: Bool) {
        self.key = key; self.url = url; self.title = title; self.domain = domain; self.researchTimestamp = researchTimestamp
        self.policyVersion = policyVersion; self.category = category; self.fromSearch = fromSearch; self.cited = cited
    }
}
/// All values are AI extraction claims, including checkability flags. No verification fields here.
public struct PromiseDiscoveryCandidate: Codable, Equatable {
    public let candidateKey: String
    public let title: String
    public let exactQuote: String
    public let speakerName: String?
    public let partyName: String?
    public let statementDate: String?
    public let statementDatePrecision: String?
    public let thesis: String
    public let topics: [String]
    public let whyCheckable: String
    public let sourceReferenceKey: String?
    public let sourceTitle: String?
    public let sourceURL: String
    public let sourcePublicationDate: String?
    public let locator: String
    public let uncertainties: [String]
    public let statementKind: String
    public let isOriginalStatement: Bool
    public let concreteTarget: Bool
    public let observableOutcome: Bool
    public let deadline: String?
    public let hasDeadlineOrCondition: Bool
    public init(candidateKey: String, title: String, exactQuote: String, speakerName: String? = nil, partyName: String? = nil,
        statementDate: String? = nil, statementDatePrecision: String? = nil, thesis: String, topics: [String] = [],
        whyCheckable: String, sourceReferenceKey: String? = nil, sourceTitle: String? = nil, sourceURL: String,
        sourcePublicationDate: String? = nil, locator: String, uncertainties: [String] = [],
        statementKind: String = "commitment", isOriginalStatement: Bool = true, concreteTarget: Bool = true,
        observableOutcome: Bool = true, deadline: String? = nil, hasDeadlineOrCondition: Bool = false) {
        self.candidateKey = candidateKey; self.title = title; self.exactQuote = exactQuote; self.speakerName = speakerName
        self.partyName = partyName; self.statementDate = statementDate; self.statementDatePrecision = statementDatePrecision
        self.thesis = thesis; self.topics = topics; self.whyCheckable = whyCheckable; self.sourceReferenceKey = sourceReferenceKey
        self.sourceTitle = sourceTitle; self.sourceURL = sourceURL; self.sourcePublicationDate = sourcePublicationDate
        self.locator = locator; self.uncertainties = uncertainties; self.statementKind = statementKind
        self.isOriginalStatement = isOriginalStatement; self.concreteTarget = concreteTarget
        self.observableOutcome = observableOutcome; self.deadline = deadline; self.hasDeadlineOrCondition = hasDeadlineOrCondition
    }
}
public struct DiscoveryRejection: Equatable {
    public let candidateKey: String
    public let reason: DiscoveryError
    public init(candidateKey: String, reason: DiscoveryError) { self.candidateKey = candidateKey; self.reason = reason }
}
public struct DiscoveryGroupOutcome: Equatable {
    public let group: ResearchSourceGroup
    public let candidates: [PromiseDiscoveryCandidate]
    public let sources: [ResearchWebSource]
    public let citations: [ResearchCitation]
    public let rejections: [DiscoveryRejection]
    public let error: DiscoveryError?
    public let searched: Bool
    public init(group: ResearchSourceGroup, candidates: [PromiseDiscoveryCandidate], sources: [ResearchWebSource] = [],
        citations: [ResearchCitation] = [], rejections: [DiscoveryRejection] = [], error: DiscoveryError? = nil, searched: Bool = true) {
        self.group = group; self.candidates = candidates; self.sources = sources; self.citations = citations
        self.rejections = rejections; self.error = error; self.searched = searched
    }
}
public struct PromiseDiscoveryResult: Equatable {
    public let outcomes: [DiscoveryGroupOutcome]
    public let promptVersion: String
    public init(outcomes: [DiscoveryGroupOutcome], promptVersion: String = "unspecified") {
        self.outcomes = outcomes; self.promptVersion = promptVersion
    }
}
/// Small persisted metadata value inside existing ResearchTask.result, not a second task/entity.
public struct DiscoveryCandidateRecord: Codable, Equatable {
    public let formatVersion: Int
    public let policy: SourcePolicy
    public let groupID: String
    public let provider: String
    public let promptVersion: String
    public let candidate: PromiseDiscoveryCandidate
    public let sources: [ResearchWebSource]
    public let citations: [ResearchCitation]
    public let requestedAt: Date
    public let minimumPromiseAge: Int
    public let maxCandidates: Int
    public init(request: PromiseDiscoveryRequest, groupID: String, provider: String, promptVersion: String,
                candidate: PromiseDiscoveryCandidate, sources: [ResearchWebSource], citations: [ResearchCitation]) {
        formatVersion = 1; policy = request.sourcePolicy; self.groupID = groupID; self.provider = provider
        self.promptVersion = promptVersion; self.candidate = candidate; self.sources = sources; self.citations = citations
        requestedAt = request.currentDate; minimumPromiseAge = request.minimumPromiseAge; maxCandidates = request.maxCandidates
    }
    public func encode() throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .millisecondsSince1970
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
    public static func decode(_ text: String) throws -> DiscoveryCandidateRecord {
        do {
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
            let record = try decoder.decode(Self.self, from: Data(text.utf8))
            try record.validate()
            return record
        } catch { throw DiscoveryError.invalidStoredMetadata }
    }
    public func validate() throws {
        guard formatVersion == 1, !provider.isEmpty, !promptVersion.isEmpty,
              let group = policy.groups.first(where: { $0.id == groupID }) else { throw DiscoveryError.invalidCandidate }
        guard Set(sources.map { $0.key }).count == sources.count,
              Set(sources.map { $0.url }).count == sources.count else { throw DiscoveryError.invalidStoredMetadata }
        for source in sources {
            guard !source.key.isEmpty, try DiscoveryIdentity.canonicalURL(source.url) == source.url,
                  let url = URL(string: source.url), source.domain == url.host?.lowercased(),
                  source.policyVersion == policy.version, source.category == group.category(for: url),
                  source.researchTimestamp.timeIntervalSinceReferenceDate.isFinite else { throw DiscoveryError.invalidStoredMetadata }
        }
        for citation in citations {
            guard try DiscoveryIdentity.canonicalURL(citation.url) == citation.url,
                  sources.contains(where: { $0.url == citation.url && $0.cited }) else { throw DiscoveryError.invalidStoredMetadata }
        }
        let request = PromiseDiscoveryRequest(sourcePolicy: policy, maxCandidates: maxCandidates,
            currentDate: requestedAt, minimumPromiseAge: minimumPromiseAge)
        try DiscoveryValidation.validate(candidate, sources: sources, group: group, request: request)
    }
}
