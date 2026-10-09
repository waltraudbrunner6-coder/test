import Foundation
import SwiftData
import PoliticalFactCheckExport
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

/// One local writer. Each operation owns a fresh context with autosave disabled.
@MainActor
public final class LocalCaseStore {
    let container: ModelContainer

    public init(container: ModelContainer) { self.container = container }

    public static func inMemory() throws -> LocalCaseStore {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return LocalCaseStore(container: try makeContainer(schema: schema, configuration: configuration))
    }

    public static func at(url: URL) throws -> LocalCaseStore {
        let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return LocalCaseStore(container: try makeContainer(schema: schema, configuration: configuration))
    }

    private static func makeContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, migrationPlan: PersistenceMigrationPlan.self,
                configurations: [configuration])
        } catch { throw PersistenceError.storage(operation: "open", detail: String(describing: error)) }
    }

    public func saveCase(_ graph: DomainContext) throws {
        try transaction("saveCase") { try writeCase(graph, in: $0) }
    }

    public func loadCase(id: EntityID<Case>) throws -> DomainContext? {
        let context = freshContext()
        do { return try readCase(id.rawValue, in: context) }
        catch let error as PersistenceError { throw error }
        catch { throw PersistenceError.storage(operation: "loadCase", detail: String(describing: error)) }
    }

    public func listCases() throws -> [Case] {
        let context = freshContext()
        do {
            let rows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
            guard Set(rows.map { $0.id }).count == rows.count else {
                throw PersistenceError.duplicateID(kind: "Case", id: rows[0].id)
            }
            return try rows.map { row in
                guard let graph = try readCase(row.id, in: context), let root = graph.cases.first else {
                    throw PersistenceError.missingEntity(kind: "Case", id: row.id)
                }
                return root
            }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
        } catch let error as PersistenceError { throw error }
        catch { throw PersistenceError.storage(operation: "listCases", detail: String(describing: error)) }
    }

    public func deleteDraftCase(id: EntityID<Case>) throws {
        try transaction("deleteDraftCase") { try removeDraft(id.rawValue, in: $0) }
    }

    func freshContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    func transaction(_ operation: String, _ body: (ModelContext) throws -> Void) throws {
        let context = freshContext()
        do {
            try body(context)
            try context.save()
        } catch {
            context.rollback()
            if let error = error as? ResearchReviewError { throw error }
            if let error = error as? CaseResearchError { throw error }
            if let error = error as? EditorialPackageError { throw error }
            if let error = error as? PersistenceError { throw error }
            if let error = error as? DomainValidationError { throw PersistenceError.invalidDomain([error]) }
            throw PersistenceError.storage(operation: operation, detail: String(describing: error))
        }
    }

    func checkFormat(_ version: Int) throws {
        guard version == 1 else { throw PersistenceError.unsupportedFormat(version) }
    }
}
