import Foundation
import PoliticalFactCheckCore

public struct ResearchInboxItem: Identifiable, Equatable {
    public let id: EntityID<PoliticalFactCheckCore.Case>
    public let record: DiscoveryCandidateRecord
    public var candidate: PromiseDiscoveryCandidate { record.candidate }
    public var score: Int {
        DiscoveryValidation.score(candidate, request: PromiseDiscoveryRequest(sourcePolicy: record.policy,
            maxCandidates: record.maxCandidates, currentDate: record.requestedAt, minimumPromiseAge: record.minimumPromiseAge))
    }
    public var source: ResearchWebSource? {
        guard let url = try? DiscoveryIdentity.canonicalURL(candidate.sourceURL) else { return nil }
        return record.sources.first { $0.url == url && $0.fromSearch }
    }
    public init(id: EntityID<PoliticalFactCheckCore.Case>, record: DiscoveryCandidateRecord) { self.id = id; self.record = record }
}
public enum DiscoveryCandidateMapper {
    public static let taskGoal = "Automatische Versprechenssuche: ungeprüfter Kandidat"
    public static let auditOperation = "discoverPromiseCandidate"
    public static func graph(_ record: DiscoveryCandidateRecord) throws -> DomainContext {
        try record.validate()
        let c = record.candidate; let now = record.requestedAt
        let caseID = EntityID<PoliticalFactCheckCore.Case>(); let promiseID = EntityID<Promise>(); let revisionID = EntityID<PromiseRevision>()
        let source = Source(canonicalURL: URL(string: try DiscoveryIdentity.canonicalURL(c.sourceURL)), createdAt: now)
        let version = SourceVersion(sourceID: source.id, requestedURL: URL(string: c.sourceURL),
            title: try c.sourceTitle.map { try NonEmptyText($0) },
            publicationDate: try DiscoveryDates.value(c.sourcePublicationDate, role: .publication),
            retrievedAt: try .instant(now, role: .retrieval), contentType: try NonEmptyText("unknown"), language: try NonEmptyText("de"))
        let excerpt = SourceExcerpt(sourceVersionID: version.id, locator: try NonEmptyText(c.locator), text: try NonEmptyText(c.exactQuote),
            context: try NonEmptyText("KI-Extraktion aus Web Search; Originalkontext noch ungeprüft. " + c.whyCheckable),
            language: try NonEmptyText("de"), provenance: .aiExtracted, createdAt: now)
        let speaker = try c.speakerName.map { Actor(name: try NonEmptyText($0), type: .person) }
        let party = try c.partyName.map { Actor(name: try NonEmptyText($0), type: .party) }
        let author = Authorship.ai(model: try NonEmptyText(record.provider), templateVersion: record.promptVersion)
        func asserted<T>(_ content: FieldValue<T>) throws -> AssertedValue<T> {
            try AssertedValue(content: content, provenance: .aiExtracted, excerptIDs: [excerpt.id])
        }
        func unknown<T>(_ reason: String) throws -> AssertedValue<T> { try asserted(.unknown(reason: NonEmptyText(reason))) }
        let revision = PromiseRevision(id: revisionID, promiseID: promiseID, quote: try asserted(.known(NonEmptyText(c.exactQuote))),
            thesis: try NonEmptyText(c.thesis), statementDate: try asserted(.known(DiscoveryDates.value(c.statementDate, precision: c.statementDatePrecision, role: .statement))),
            context: try unknown("Originalkontext noch nicht geprüft"), targetGroup: try unknown("Zielgruppe noch nicht geprüft"),
            conditions: try unknown("Bedingungen noch nicht geprüft"), responsibility: try unknown("Zuständigkeit noch nicht geprüft"),
            speaker: try speaker.map { try asserted(.known($0.id)) } ?? unknown("Sprecher nicht zuverlässig extrahiert"),
            party: try party.map { try asserted(.known($0.id)) } ?? unknown("Partei zum Aussagezeitpunkt nicht zuverlässig extrahiert"),
            topics: try c.topics.map { try NonEmptyText($0) },
            metadata: RevisionMetadata(number: 1, reason: try NonEmptyText("Automatisch gefundener ungeprüfter Recherchekandidat"), author: author, createdAt: now))
        let root = PoliticalFactCheckCore.Case(id: caseID, title: try NonEmptyText(c.title), promiseID: promiseID,
            currentPromiseRevisionID: revisionID, createdAt: now, modifiedAt: now)
        let task = ResearchTask(caseID: caseID, goal: try NonEmptyText(taskGoal), query: "politisches Versprechen Ankündigung Wahlprogramm konkretes Ziel Frist Österreich",
            status: .completed, result: try record.encode(), attemptedAt: now, nextStep: "Quellen und Kontext validieren; keine Bewertung erstellt",
            sourceIDs: [source.id], excerptIDs: [excerpt.id], author: author, createdAt: now)
        let audit = AuditEntry(caseID: caseID, target: ObjectReference(kind: .politicalCase, id: caseID), operation: try NonEmptyText(auditOperation),
            author: author, occurredAt: now, reason: try NonEmptyText("Web-Search-Kandidat übernommen; Suchherkunft ist keine Verifikation"))
        return DomainContext(cases: [root], actors: [speaker, party].compactMap { $0 },
            promises: [Promise(id: promiseID, caseID: caseID, currentRevisionID: revisionID, createdAt: now)],
            promiseRevisions: [revision], sources: [source], sourceVersions: [version], excerpts: [excerpt], researchTasks: [task], auditEntries: [audit])
    }
    public static func inboxItem(in graph: DomainContext) throws -> ResearchInboxItem? {
        guard let root = graph.cases.first, root.workflowState == .candidate,
              graph.auditEntries.contains(where: { $0.operation.value == auditOperation }),
              let task = graph.researchTasks.first(where: { $0.goal.value == taskGoal }) else { return nil }
        guard let result = task.result else { throw DiscoveryError.invalidStoredMetadata }
        return ResearchInboxItem(id: root.id, record: try DiscoveryCandidateRecord.decode(result))
    }
    /// Compare all stored quote revisions, including manually created cases. Never merge semantics.
    public static func duplicateKeyExists(_ key: String, in graph: DomainContext) -> Bool {
        for revision in graph.promiseRevisions {
            guard let quote = revision.quote.content.knownValue?.value else { continue }
            for id in revision.quote.excerptIDs {
                guard let excerpt = graph.find(id), let version = graph.find(excerpt.sourceVersionID),
                      let source = graph.find(version.sourceID), let url = source.canonicalURL ?? version.requestedURL,
                      let existing = try? DiscoveryIdentity.key(url: url.absoluteString, quote: quote) else { continue }
                if existing == key { return true }
            }
        }
        return false
    }
}
