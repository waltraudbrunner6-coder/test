import Foundation
import PoliticalFactCheckCore

public enum PersistenceError: Error, Equatable {
    case invalidAggregate
    case invalidDomain([DomainValidationError])
    case invalidEnum(type: String, value: String)
    case wrongIDType(expected: String, actual: String, id: UUID)
    case identityMismatch(kind: String, id: UUID)
    case missingEntity(kind: String, id: UUID)
    case duplicateID(kind: String, id: UUID)
    case corruptPayload(detail: String)
    case invalidValue(detail: String)
    case unsupportedFormat(Int)
    case historyRemovalDenied(kind: String, id: UUID)
    case draftDeletionDenied(UUID)
    case reviewUpdateRequired(UUID)
    case immutableRecord(kind: String, id: UUID)
    case storage(operation: String, detail: String)
}

func validateDomain(_ graph: DomainContext) throws {
    guard graph.cases.count == 1, graph.promises.count == 1, let root = graph.cases.first else { throw PersistenceError.invalidAggregate }
    let result = DomainValidator.validate(graph)
    guard result.isValid else { throw PersistenceError.invalidDomain(result.errors) }
    guard graph.promises.allSatisfy({ $0.caseID == root.id }),
          graph.actions.allSatisfy({ $0.caseID == root.id }),
          graph.caseRevisions.allSatisfy({ $0.caseID == root.id }),
          graph.caseEvaluations.allSatisfy({ $0.caseID == root.id }),
          graph.researchTasks.allSatisfy({ $0.caseID == root.id }),
          graph.auditEntries.allSatisfy({ $0.caseID == root.id }) else { throw PersistenceError.invalidAggregate }
    for child in graph.criterionEvaluations {
        guard graph.find(child.caseEvaluationID)?.criterionEvaluationIDs.contains(child.id) == true else {
            throw PersistenceError.missingEntity(kind: "CaseEvaluation", id: child.caseEvaluationID.rawValue)
        }
    }
    for statement in graph.statements {
        guard graph.find(statement.scriptDraftID)?.statementIDs.contains(statement.id) == true else {
            throw PersistenceError.missingEntity(kind: "ScriptDraft", id: statement.scriptDraftID.rawValue)
        }
    }
    for audit in graph.auditEntries {
        for reference in [audit.target, audit.before, audit.after].compactMap({ $0 }) {
            guard contains(reference, in: graph) else {
                throw PersistenceError.missingEntity(kind: write(reference.kind), id: reference.id)
            }
        }
        if case .human(let id) = audit.author, graph.find(id) == nil {
            throw PersistenceError.missingEntity(kind: "ReviewerIdentity", id: id.rawValue)
        }
        if let id = audit.humanRequesterID, graph.find(id) == nil {
            throw PersistenceError.missingEntity(kind: "ReviewerIdentity", id: id.rawValue)
        }
    }
}

func domainChange<T>(_ body: () throws -> T) throws -> T {
    do { return try body() }
    catch let error as PersistenceError { throw error }
    catch let error as DomainValidationError { throw PersistenceError.invalidDomain([error]) }
    catch { throw PersistenceError.invalidValue(detail: String(describing: error)) }
}

private func contains(_ reference: ObjectReference, in graph: DomainContext) -> Bool {
    switch reference.kind {
    case .reviewer: return graph.find(EntityID<ReviewerIdentity>(reference.id)) != nil
    case .politicalCase: return graph.find(EntityID<Case>(reference.id)) != nil
    case .actor: return graph.find(EntityID<Actor>(reference.id)) != nil
    case .affiliation: return graph.find(EntityID<ActorAffiliation>(reference.id)) != nil
    case .promise: return graph.find(EntityID<Promise>(reference.id)) != nil
    case .promiseRevision: return graph.find(EntityID<PromiseRevision>(reference.id)) != nil
    case .criterion: return graph.find(EntityID<EvaluationCriterion>(reference.id)) != nil
    case .criterionRevision: return graph.find(EntityID<CriterionRevision>(reference.id)) != nil
    case .source: return graph.find(EntityID<Source>(reference.id)) != nil
    case .sourceVersion: return graph.find(EntityID<SourceVersion>(reference.id)) != nil
    case .excerpt: return graph.find(EntityID<SourceExcerpt>(reference.id)) != nil
    case .action: return graph.find(EntityID<ActionOrDevelopment>(reference.id)) != nil
    case .actionRevision: return graph.find(EntityID<ActionRevision>(reference.id)) != nil
    case .participation: return graph.find(EntityID<ActionParticipation>(reference.id)) != nil
    case .evidenceLink: return graph.find(EntityID<EvidenceLink>(reference.id)) != nil
    case .caseRevision: return graph.find(EntityID<CaseRevision>(reference.id)) != nil
    case .criterionEvaluation: return graph.find(EntityID<CriterionEvaluation>(reference.id)) != nil
    case .caseEvaluation: return graph.find(EntityID<CaseEvaluation>(reference.id)) != nil
    case .methodology: return graph.find(EntityID<MethodologyVersion>(reference.id)) != nil
    case .researchTask: return graph.find(EntityID<ResearchTask>(reference.id)) != nil
    case .auditEntry: return graph.find(EntityID<AuditEntry>(reference.id)) != nil
    case .script: return graph.find(EntityID<ScriptDraft>(reference.id)) != nil
    case .statement: return graph.find(EntityID<ScriptStatement>(reference.id)) != nil
    }
}
