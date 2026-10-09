import Foundation
import SwiftData
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

public enum DiscoveryImportOutcome: Equatable {
    case inserted(EntityID<PoliticalFactCheckCore.Case>)
    case duplicate
}
extension LocalCaseStore {
    /// Per-candidate atomicity: graph, task and AI audit are either all saved or all rolled back.
    public func insertDiscoveryCandidate(_ record: DiscoveryCandidateRecord) throws -> DiscoveryImportOutcome {
        try record.validate()
        let key = try DiscoveryIdentity.key(url: record.candidate.sourceURL, quote: record.candidate.exactQuote)
        let graph = try DiscoveryCandidateMapper.graph(record)
        var outcome = DiscoveryImportOutcome.duplicate
        try transaction("insertDiscoveryCandidate") { context in
            let rows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
            for row in rows {
                guard let existing = try readCase(row.id, in: context) else { throw PersistenceError.missingEntity(kind: "Case", id: row.id) }
                if DiscoveryCandidateMapper.duplicateKeyExists(key, in: existing) { return }
            }
            try writeCase(graph, in: context)
            outcome = .inserted(graph.cases[0].id)
        }
        return outcome
    }
    public func researchInbox() throws -> [ResearchInboxItem] {
        let context = freshContext()
        let rows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
        return try rows.compactMap { row in
            guard let graph = try readCase(row.id, in: context) else { throw PersistenceError.missingEntity(kind: "Case", id: row.id) }
            return try DiscoveryCandidateMapper.inboxItem(in: graph)
        }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
    }
}
