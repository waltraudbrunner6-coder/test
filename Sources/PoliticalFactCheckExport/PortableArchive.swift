import Foundation
import PoliticalFactCheckCore

public enum EditorialPackageError: Error, Equatable {
    case evaluationNotApproved, evaluationNeedsReview, scriptNotApproved, scriptEvaluationMismatch, invalidScript
    case unsupportedVersion, missingFile, hashConflict, methodologyConflict, invalidJSON, invalidReference
    case invalidDomain, caseAlreadyExists, nonPortableAttachment, sensitiveContent, writeFailure, readFailure
    case invalidPackage, destinationExists
}

enum ArchiveMappingError: Error, Equatable {
    case invalidEnum(type: String, value: String)
    case wrongIDType(expected: String, actual: String, id: UUID)
    case invalidValue(detail: String)
}

/// Explicit v1 transport, never a SwiftData model/payload. All domain identities remain unchanged.
public struct PortableCaseArchiveV1: Codable, Equatable {
    public let schemaVersion: Int
    var graph: CaseGraphDTO
    public init(_ context: DomainContext) throws {
        try EditorialValidation.validateGraph(context)
        schemaVersion = 1
        graph = CaseGraphDTO(context)
        canonicalize()
    }
    public func domain() throws -> DomainContext {
        guard schemaVersion == 1 else { throw EditorialPackageError.unsupportedVersion }
        let context: DomainContext
        do { context = try graph.domain() }
        catch { throw EditorialPackageError.invalidReference }
        try EditorialValidation.validateGraph(context)
        return context
    }
    private mutating func canonicalize() {
        graph.reviewers.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.cases.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.actors.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.affiliations.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.promises.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.promiseRevisions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.criteria.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.criterionRevisions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.sources.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.sourceVersions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.excerpts.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.actions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.actionRevisions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.participations.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.evidenceLinks.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.caseRevisions.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.criterionEvaluations.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.caseEvaluations.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.methodologies.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.researchTasks.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.auditEntries.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.scripts.sort { $0.id.value.uuidString < $1.id.value.uuidString }
        graph.statements.sort { $0.id.value.uuidString < $1.id.value.uuidString }
    }
}
