import Foundation

/// Frozen, case-independent identity. The hash refers to docs/methodology-v1.0.md.
public enum MethodologyV1 {
    public static func version() throws -> MethodologyVersion {
        try MethodologyVersion(id: EntityID(UUID(uuidString: "B8E43153-240B-4A62-BFE8-C251027A0100")!),
            version: NonEmptyText("1.0"), title: NonEmptyText("Neutrale Bewertungsmethodik für politische Versprechen"),
            contentReference: NonEmptyText("political-fact-check/methodology/1.0; docs/methodology-v1.0.md"),
            hash: ContentHash(sha256: "33ed90d3dcb6fb91469f44965db0094197d936e65a3bd6628cacdf115c81176a"),
            changeNote: NonEmptyText("Eingefrorene Konsolidierung der Produktspezifikation, Abschnitte 3.1, 4 und 5"),
            createdAt: Date(timeIntervalSince1970: 1791417600))
    }
}

/// Human-entered content, with no category/confidence defaults or aggregation.
public struct ManualAssessment {
    public let category: EvaluationCategory
    public let rationale: NonEmptyText
    public let confidence: EvidenceConfidence
    public let uncertainties: [NonEmptyText]
    public let notVerifiableReasons: [NotVerifiableReason]
    public init(category: EvaluationCategory, rationale: NonEmptyText, confidence: EvidenceConfidence,
                uncertainties: [NonEmptyText] = [], notVerifiableReasons: [NotVerifiableReason] = []) {
        self.category = category; self.rationale = rationale; self.confidence = confidence
        self.uncertainties = uncertainties; self.notVerifiableReasons = notVerifiableReasons
    }
}
public struct ManualCriterionAssessment {
    public let criterionRevisionID: EntityID<CriterionRevision>
    public let assessment: ManualAssessment
    public let evidenceLinkIDs: [EntityID<EvidenceLink>]
    public let counterEvidenceLinkIDs: [EntityID<EvidenceLink>]
    public init(criterionRevisionID: EntityID<CriterionRevision>, assessment: ManualAssessment,
                evidenceLinkIDs: [EntityID<EvidenceLink>] = [], counterEvidenceLinkIDs: [EntityID<EvidenceLink>] = []) {
        self.criterionRevisionID = criterionRevisionID; self.assessment = assessment
        self.evidenceLinkIDs = evidenceLinkIDs; self.counterEvidenceLinkIDs = counterEvidenceLinkIDs
    }
}
public struct ManualEvaluationDraft {
    public let evaluation: CaseEvaluation
    public let criteria: [CriterionEvaluation]
    public let politicalCase: Case
}

extension DomainContext {
    /// Copy only the evaluation working set; all source/revision values remain unchanged.
    public func withEvaluations(cases: [Case]? = nil, snapshots: [CaseRevision]? = nil,
        criteria: [CriterionEvaluation]? = nil, evaluations: [CaseEvaluation]? = nil,
        methodologies: [MethodologyVersion]? = nil) -> DomainContext {
        DomainContext(reviewers: reviewers, cases: cases ?? self.cases, actors: actors, affiliations: affiliations,
            promises: promises, promiseRevisions: promiseRevisions, criteria: self.criteria,
            criterionRevisions: criterionRevisions, sources: sources, sourceVersions: sourceVersions,
            excerpts: excerpts, actions: actions, actionRevisions: actionRevisions, participations: participations,
            evidenceLinks: evidenceLinks, caseRevisions: snapshots ?? caseRevisions,
            criterionEvaluations: criteria ?? criterionEvaluations, caseEvaluations: evaluations ?? caseEvaluations,
            methodologies: methodologies ?? self.methodologies, researchTasks: researchTasks,
            auditEntries: auditEntries, scripts: scripts, statements: statements)
    }
}

public extension DomainChanges {
    static func evaluationSnapshot(_ politicalCase: Case, cutoff: DatedValue, review: HumanReview,
                                   at date: Date, in graph: DomainContext) throws -> CaseRevision {
        guard politicalCase.workflowState == .readyForEvaluation else { throw DomainValidationError.evaluationRequiresReadyCase }
        guard !graph.caseEvaluations.contains(where: { $0.caseID == politicalCase.id }) else { throw DomainValidationError.firstEvaluationOnly }
        try DomainValidator.validate(politicalCase, in: graph).requireValid()
        try DomainValidator.review(review, in: graph).requireValid()
        try DomainValidator.role(cutoff, expected: .evaluationCutoff).requireValid()
        guard cutoff.content.knownValue?.end != nil else { throw DomainValidationError.missingCutoff }
        let links = graph.evidenceLinks.filter { $0.status == .verified && politicalCase.activeCriterionRevisionIDs.contains($0.criterionRevisionID) }
        var actionIDs = politicalCase.currentActionRevisionIDs
        for id in links.compactMap({ $0.actionRevisionID }) where !actionIDs.contains(id) { actionIDs.append(id) }
        let snapshot = CaseRevision(caseID: politicalCase.id, promiseRevisionID: politicalCase.currentPromiseRevisionID,
            criteria: politicalCase.activeCriterionRevisionIDs.map { StateSnapshot(id: $0, state: .confirmed) },
            actionRevisionIDs: actionIDs,
            participations: graph.participations.filter { actionIDs.contains($0.actionRevisionID) }.map { .init(id: $0.id, state: $0.verification) },
            sourceVersions: graph.sourceVersions.map { .init(id: $0.id, state: $0.verification) },
            excerpts: graph.excerpts.map { .init(id: $0.id, state: $0.state) },
            evidenceLinks: links.map { .init(id: $0.id, state: $0.status) },
            researchTasks: graph.researchTasks.filter { $0.caseID == politicalCase.id }.map { .init(id: $0.id, state: $0.status) },
            metadata: RevisionMetadata(number: graph.caseRevisions.filter { $0.caseID == politicalCase.id }.count + 1,
                reason: try NonEmptyText("Manueller Bewertungsstand eingefroren"), author: .human(review.reviewerID), createdAt: date))
        try DomainValidator.validate(snapshot, in: graph).requireValid()
        return snapshot
    }

    static func manualEvaluationDraft(_ politicalCase: Case, snapshotID: EntityID<CaseRevision>, cutoff: DatedValue,
        criteria: [ManualCriterionAssessment], overall: ManualAssessment, facts: [NonEmptyText],
        interpretations: [NonEmptyText], reviewerID: EntityID<ReviewerIdentity>, at date: Date,
        in graph: DomainContext) throws -> ManualEvaluationDraft {
        guard politicalCase.workflowState == .readyForEvaluation else { throw DomainValidationError.evaluationRequiresReadyCase }
        guard !graph.caseEvaluations.contains(where: { $0.caseID == politicalCase.id }) else { throw DomainValidationError.firstEvaluationOnly }
        try DomainValidator.validate(politicalCase, in: graph).requireValid()
        guard let snapshot = graph.find(snapshotID), snapshot.caseID == politicalCase.id else {
            throw DomainValidationError.missingReference(ObjectReference(kind: .caseRevision, id: snapshotID))
        }
        let methodology = try MethodologyV1.version()
        guard graph.find(methodology.id) == methodology else { throw DomainValidationError.methodologyConflict }
        guard date >= snapshot.metadata.createdAt else { throw DomainValidationError.invalidReviewTime }
        let id = EntityID<CaseEvaluation>()
        let children = criteria.map { input in
            CriterionEvaluation(caseEvaluationID: id, criterionRevisionID: input.criterionRevisionID,
                category: input.assessment.category, rationale: input.assessment.rationale,
                evidenceLinkIDs: input.evidenceLinkIDs, counterEvidenceLinkIDs: input.counterEvidenceLinkIDs,
                confidence: input.assessment.confidence, uncertainties: input.assessment.uncertainties,
                notVerifiableReasons: input.assessment.notVerifiableReasons)
        }
        let evaluation = CaseEvaluation(id: id, caseID: politicalCase.id, caseRevisionID: snapshotID,
            cutoff: cutoff, methodologyVersionID: methodology.id, criterionEvaluationIDs: children.map { $0.id },
            category: overall.category, rationale: overall.rationale, confidence: overall.confidence,
            facts: facts, interpretations: interpretations, uncertainties: overall.uncertainties,
            notVerifiableReasons: overall.notVerifiableReasons,
            metadata: RevisionMetadata(number: 1, reason: try NonEmptyText("Manuelle Erstbewertung"),
                author: .human(reviewerID), createdAt: date))
        let nextGraph = graph.withEvaluations(criteria: graph.criterionEvaluations + children,
            evaluations: graph.caseEvaluations + [evaluation])
        try DomainValidator.validate(evaluation, in: nextGraph).requireValid()
        let nextCase = try transition(politicalCase, to: .evaluated, at: date, in: nextGraph)
        return ManualEvaluationDraft(evaluation: evaluation, criteria: children, politicalCase: nextCase)
    }

    static func reviewCriterionEvaluation(_ child: CriterionEvaluation, review: HumanReview,
                                          in graph: DomainContext) throws -> CriterionEvaluation {
        guard child.reviewState == .unreviewed, child.review == nil,
              graph.find(child.id) == child,
              let parent = graph.find(child.caseEvaluationID), parent.criterionEvaluationIDs.contains(child.id),
              parent.status == .draft || parent.status == .needsReview,
              let snapshot = graph.find(parent.caseRevisionID) else { throw DomainValidationError.criterionReviewNotAllowed }
        guard review.reviewedAt >= parent.metadata.createdAt else { throw DomainValidationError.invalidReviewTime }
        try DomainValidator.review(review, in: graph).requireValid()
        let next = child.withReview(state: .reviewed, review: review)
        try DomainValidator.validate(next, snapshot: snapshot, cutoff: parent.cutoff, final: false, in: graph).requireValid()
        try RevisionRules.validateReplacement(child, with: next)
        return next
    }
}

extension CriterionEvaluation {
    func withReview(state: HumanReviewState, review: HumanReview?) -> CriterionEvaluation {
        CriterionEvaluation(id: id, caseEvaluationID: caseEvaluationID, criterionRevisionID: criterionRevisionID,
            category: category, rationale: rationale, evidenceLinkIDs: evidenceLinkIDs,
            counterEvidenceLinkIDs: counterEvidenceLinkIDs, confidence: confidence, uncertainties: uncertainties,
            notVerifiableReasons: notVerifiableReasons, reviewState: state, review: review)
    }
}
