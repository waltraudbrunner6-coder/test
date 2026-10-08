import Foundation
import SwiftData
import PoliticalFactCheckCore

extension LocalCaseStore {
    /// Explicit registration, not a side effect of opening a store. Canonical content never changes.
    @discardableResult
    public func ensureMethodologyV1() throws -> MethodologyVersion {
        var result: MethodologyVersion?
        try transaction("ensureMethodologyV1") { result = try registerMethodologyV1(in: $0).value }
        guard let result else { throw PersistenceError.invalidDomain([.methodologyConflict]) }
        return result
    }

    private func registerMethodologyV1(in context: ModelContext) throws -> (value: MethodologyVersion, inserted: Bool) {
        let expected = try MethodologyV1.version()
        let rows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>())
        let candidates = try rows.compactMap { row -> MethodologyVersion? in
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(MethodologyVersionDTO.self, from: row.payload)
            guard dto.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "MethodologyVersion", id: row.id) }
            let value = try domainChange { try dto.domain() }
            return value.version == expected.version || value.id == expected.id ? value : nil
        }
        guard candidates.count <= 1, candidates.allSatisfy({ $0 == expected }) else {
            throw PersistenceError.invalidDomain([.methodologyConflict])
        }
        if let existing = candidates.first { return (existing, false) }
        context.insert(PersistenceSchemaV1.MethodologyVersionRecord(id: expected.id.rawValue,
            payload: try PayloadCodec.encode(MethodologyVersionDTO(expected))))
        return (expected, true)
    }

    @discardableResult
    public func startEvaluationSnapshot(caseID: EntityID<Case>, cutoff: DatedValue,
        reviewer: ReviewerIdentity, at date: Date) throws -> CaseRevision {
        var result: CaseRevision?
        try transaction("startEvaluationSnapshot") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard graph.caseRevisions.isEmpty else { throw PersistenceError.invalidDomain([.firstEvaluationOnly]) }
            let snapshot = try domainChange {
                try DomainChanges.evaluationSnapshot(graph.cases[0], cutoff: cutoff,
                    review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), at: date, in: graph)
            }
            let registration = try registerMethodologyV1(in: context)
            var dto = CaseGraphDTO(graph)
            if !dto.methodologies.contains(where: { $0.id.value == registration.value.id.rawValue }) {
                dto.methodologies.append(MethodologyVersionDTO(registration.value))
            }
            dto.caseRevisions.append(CaseRevisionDTO(snapshot))
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .methodology, id: registration.value.id),
                operation: registration.inserted ? "registerMethodologyV1" : "useMethodologyV1", reviewer: reviewer, at: date)
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .caseRevision, id: snapshot.id),
                operation: "createCaseRevision", reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
            result = snapshot
        }
        guard let result else { throw PersistenceError.invalidAggregate }
        return result
    }

    @discardableResult
    public func createEvaluationDraft(caseID: EntityID<Case>, snapshotID: EntityID<CaseRevision>, cutoff: DatedValue,
        criteria: [ManualCriterionAssessment], overall: ManualAssessment, facts: [NonEmptyText],
        interpretations: [NonEmptyText], reviewer: ReviewerIdentity, at date: Date) throws -> CaseEvaluation {
        var result: CaseEvaluation?
        try transaction("createEvaluationDraft") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            _ = try registerMethodologyV1(in: context) // Detect conflicting global registrations as well.
            let change = try domainChange {
                try DomainChanges.manualEvaluationDraft(graph.cases[0], snapshotID: snapshotID, cutoff: cutoff,
                    criteria: criteria, overall: overall, facts: facts, interpretations: interpretations,
                    reviewerID: reviewer.id, at: date, in: graph)
            }
            var dto = CaseGraphDTO(graph)
            dto.cases[0] = CaseDTO(change.politicalCase)
            dto.criterionEvaluations.append(contentsOf: change.criteria.map(CriterionEvaluationDTO.init))
            dto.caseEvaluations.append(CaseEvaluationDTO(change.evaluation))
            for child in change.criteria {
                try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .criterionEvaluation, id: child.id),
                    operation: "createCriterionEvaluation", reviewer: reviewer, at: date)
            }
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .caseEvaluation, id: change.evaluation.id),
                operation: "createCaseEvaluation", reviewer: reviewer, at: date)
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .politicalCase, id: caseID),
                operation: "markCaseEvaluated", reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
            result = change.evaluation
        }
        guard let result else { throw PersistenceError.invalidAggregate }
        return result
    }

    public func reviewCriterionEvaluation(caseID: EntityID<Case>, childID: EntityID<CriterionEvaluation>,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("reviewCriterionEvaluation") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let child = graph.find(childID), graph.find(child.caseEvaluationID)?.caseID == caseID else {
                throw PersistenceError.missingEntity(kind: "CriterionEvaluation", id: childID.rawValue)
            }
            let next = try domainChange {
                try DomainChanges.reviewCriterionEvaluation(child,
                    review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: graph)
            }
            var dto = CaseGraphDTO(graph)
            let index = dto.criterionEvaluations.firstIndex { $0.id.value == childID.rawValue }!
            dto.criterionEvaluations[index] = CriterionEvaluationDTO(next)
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .criterionEvaluation, id: childID),
                operation: "reviewCriterionEvaluation", reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    public func submitEvaluationForReview(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try changeEvaluationStatus(caseID: caseID, evaluationID: evaluationID, to: .needsReview, reviewer: reviewer, at: date)
    }
    public func approveEvaluation(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try changeEvaluationStatus(caseID: caseID, evaluationID: evaluationID, to: .approved, reviewer: reviewer, at: date)
    }

    private func changeEvaluationStatus(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        to status: EvaluationStatus, reviewer: ReviewerIdentity, at date: Date) throws {
        try transaction("changeEvaluationStatus") { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let evaluation = graph.find(evaluationID), evaluation.caseID == caseID else {
                throw PersistenceError.missingEntity(kind: "CaseEvaluation", id: evaluationID.rawValue)
            }
            let next = try domainChange {
                try DomainChanges.transition(evaluation, to: status,
                    approval: status == .approved ? HumanReview(reviewerID: reviewer.id, reviewedAt: date) : nil, in: graph)
            }
            var dto = CaseGraphDTO(graph)
            let index = dto.caseEvaluations.firstIndex { $0.id.value == evaluationID.rawValue }!
            dto.caseEvaluations[index] = CaseEvaluationDTO(next)
            if status == .approved {
                let approvedCase = try domainChange {
                    try DomainChanges.transition(graph.cases[0], to: .approved, at: date, in: dto.domain())
                }
                dto.cases[0] = CaseDTO(approvedCase)
                try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .politicalCase, id: caseID),
                    operation: "markCaseApproved", reviewer: reviewer, at: date)
            }
            try evaluationAudit(&dto, caseID: caseID, target: ObjectReference(kind: .caseEvaluation, id: evaluationID),
                operation: status == .approved ? "approveEvaluation" : "submitEvaluationForReview", reviewer: reviewer, at: date)
            try writeCase(domainChange { try dto.domain() }, in: context)
        }
    }

    private func evaluationAudit(_ dto: inout CaseGraphDTO, caseID: EntityID<Case>, target: ObjectReference,
        operation: String, reviewer: ReviewerIdentity, at date: Date) throws {
        dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: caseID, target: target,
            operation: try NonEmptyText(operation), author: .human(reviewer.id), humanRequesterID: reviewer.id,
            occurredAt: date, reason: try NonEmptyText("Expliziter menschlicher Bewertungs-/Prüfschritt nach eingefrorener Methodik 1.0"))))
    }
}
