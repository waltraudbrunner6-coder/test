import Foundation
import SwiftData
import PoliticalFactCheckCore
import PoliticalFactCheckResearch

extension LocalCaseStore {
    public func researchReviewPlan(caseID: EntityID<Case>) throws -> ResearchReviewPlan {
        guard let graph = try loadCase(id: caseID), let record = try CaseResearchDraftMapper.dossier(in: graph) else { throw ResearchReviewError.staleResearch }
        return try ResearchReviewPlan(graph: graph, record: record)
    }
    // Reuse existing operations on an isolated local staging store. The real store has exactly one save.
    // No nested saves reach the persistent container. Unsaved checkpoints preserve adjacent replacement transitions; the outer transaction saves or rolls back everything.
    private func reviewTransaction(caseID: EntityID<Case>, reviewer: ReviewerIdentity,
        operation: String, body: (LocalCaseStore, ResearchReviewPlan, (DomainContext) throws -> Void) throws -> Void) throws {
        try transaction(operation) { context in
            let graph = try manualGraph(caseID: caseID, reviewer: reviewer, in: context)
            guard let record = try CaseResearchDraftMapper.dossier(in: graph) else { throw ResearchReviewError.staleResearch }
            let plan = try ResearchReviewPlan(graph: graph, record: record)
            let stage = try LocalCaseStore.inMemory()
            try stage.saveCase(graph)
            try body(stage, plan, { try self.writeCase($0, in: context) })
            guard let updated = try stage.loadCase(id: caseID), try CaseResearchDraftMapper.dossier(in: updated) == record else { throw ResearchReviewError.staleResearch }
            try writeCase(updated, in: context)
        }
    }
    private func reviewAudit(_ dto: inout CaseGraphDTO, old: ObjectReference, new: ObjectReference? = nil,
        operation: String, reviewer: ReviewerIdentity, at date: Date) throws {
        dto.auditEntries.append(AuditEntryDTO(AuditEntry(caseID: try dto.cases[0].id.domain(Case.self, kind: "Case"),
            target: new ?? old, operation: try NonEmptyText(operation), before: new == nil ? nil : old, after: new,
            author: .human(reviewer.id), humanRequesterID: reviewer.id, occurredAt: date,
            reason: try NonEmptyText("Explizite menschliche Entscheidung zum erhaltenen KI-Recherchevorschlag"))))
    }
    public func reviewResearchExcerpt(caseID: EntityID<Case>, excerptID: EntityID<SourceExcerpt>,
        reject: Bool = false, reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "reviewResearchExcerpt") { stage, plan, _ in
            guard plan.record.bindings?.excerpts.values.contains(excerptID.rawValue) == true,
                  let graph = try stage.loadCase(id: caseID), let old = graph.find(excerptID), let source = graph.find(old.sourceVersionID),
                  old.state == .unverified else { throw ResearchReviewError.staleResearch }
            var dto = CaseGraphDTO(graph)
            if reject {
                let rejected = try DomainChanges.transition(old, to: .rejected, in: graph)
                dto.excerpts[dto.excerpts.firstIndex { $0.id.value == old.id.rawValue }!] = SourceExcerptDTO(rejected)
                try self.reviewAudit(&dto, old: ObjectReference(kind: .excerpt, id: old.id), operation: "rejectResearchExcerpt", reviewer: reviewer, at: date)
            } else {
                guard try ResearchReviewPlan.linkedID(old.id, operation: "reviewResearchExcerpt", kind: .excerpt, in: graph) == nil else { throw ResearchReviewError.staleResearch }
                let review = HumanReview(reviewerID: reviewer.id, reviewedAt: date)
                let version = SourceVersion(sourceID: source.sourceID, kind: source.kind, requestedURL: source.requestedURL,
                    finalURL: source.finalURL, archiveURL: source.archiveURL, title: source.title, publisher: source.publisher, author: source.author,
                    publicationDate: source.publicationDate, retrievedAt: try .instant(date, role: .retrieval), eventDate: source.eventDate,
                    validity: source.validity, availability: source.availability, verification: .verified, review: review,
                    contentType: source.contentType, language: source.language, localCopyReference: source.localCopyReference, hash: source.hash)
                let draft = SourceExcerpt(sourceVersionID: version.id, locator: old.locator, text: old.text, context: old.context,
                    language: old.language, translationOfExcerptID: old.translationOfExcerptID, provenance: old.provenance, createdAt: date)
                dto.sourceVersions.append(SourceVersionDTO(version)); dto.excerpts.append(SourceExcerptDTO(draft))
                let verified = try DomainChanges.transition(draft, to: .verified, review: review, in: dto.domain())
                dto.excerpts[dto.excerpts.count - 1] = SourceExcerptDTO(verified)
                try self.reviewAudit(&dto, old: ObjectReference(kind: .excerpt, id: old.id), new: ObjectReference(kind: .excerpt, id: verified.id), operation: "reviewResearchExcerpt", reviewer: reviewer, at: date)
            }
            try stage.saveCase(dto.domain())
        }
    }
    /// Separate explicit confirmation of the original quote, followed by the normal documented transition.
    public func reviewResearchOriginal(caseID: EntityID<Case>, reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "reviewResearchOriginal") { stage, plan, _ in
            guard let oldExcerpt = plan.originalExcerptID, let graph = try stage.loadCase(id: caseID),
                  let checked = try ResearchReviewPlan.linkedID(oldExcerpt, operation: "reviewResearchExcerpt", kind: .excerpt, in: graph) ?? (graph.find(oldExcerpt)?.state == .verified ? oldExcerpt : nil),
                  let excerpt = graph.find(checked), let old = graph.find(graph.cases[0].currentPromiseRevisionID),
                  old.quote.content.knownValue == excerpt.text, excerpt.state == .verified else { throw ResearchReviewError.incompleteSources }
            let review = HumanReview(reviewerID: reviewer.id, reviewedAt: date)
            let quote = try AssertedValue(content: old.quote.content, provenance: old.quote.provenance, verification: .verified, excerptIDs: [checked], review: review)
            let revision = PromiseRevision(promiseID: old.promiseID, quote: quote, thesis: old.thesis, statementDate: old.statementDate,
                context: old.context, targetGroup: old.targetGroup, conditions: old.conditions, responsibility: old.responsibility,
                speaker: old.speaker, party: old.party, topics: old.topics,
                metadata: RevisionMetadata(number: old.metadata.number + 1, reason: try NonEmptyText("Originalzitat anhand wortgleicher geprüfter Fundstelle bestätigt"), author: .human(reviewer.id), createdAt: date))
            var dto = CaseGraphDTO(graph)
            dto.promiseRevisions.append(PromiseRevisionDTO(revision)); dto.promises[0].currentRevisionID = StoredID(revision.id, kind: "PromiseRevision")
            dto.cases[0].currentPromiseRevisionID = StoredID(revision.id, kind: "PromiseRevision")
            try self.reviewAudit(&dto, old: ObjectReference(kind: .promiseRevision, id: old.id), new: ObjectReference(kind: .promiseRevision, id: revision.id), operation: "verifyOriginalQuote", reviewer: reviewer, at: date)
            let updated = try dto.domain()
            let documented = try DomainChanges.transition(updated.cases[0], to: .documented, at: date, in: updated)
            dto.cases[0] = CaseDTO(documented)
            try self.reviewAudit(&dto, old: ObjectReference(kind: .politicalCase, id: caseID), operation: "markDocumented", reviewer: reviewer, at: date)
            try stage.saveCase(dto.domain())
        }
    }
    public func selectResearchCriterion(caseID: EntityID<Case>, key: String, use: Bool,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "selectResearchCriterion") { stage, plan, _ in
            guard let raw = plan.record.bindings?.criterionRevisions[key], let graph = try stage.loadCase(id: caseID),
                  let old = graph.find(EntityID<CriterionRevision>(raw)), old.state == .draft, case .ai = old.metadata.author,
                  graph.caseRevisions.isEmpty, graph.caseEvaluations.isEmpty,
                  graph.find(old.criterionID)?.currentRevisionID == old.id,
                  graph.cases[0].activeCriterionRevisionIDs.contains(old.id) else { throw ResearchReviewError.staleResearch }
            var dto = CaseGraphDTO(graph)
            if !use { dto.cases[0].activeCriterionRevisionIDs.removeAll { $0.value == raw } }
            try self.reviewAudit(&dto, old: ObjectReference(kind: .criterionRevision, id: old.id), operation: use ? "acceptResearchCriterionProposal" : "rejectResearchCriterionProposal", reviewer: reviewer, at: date)
            try stage.saveCase(dto.domain())
        }
    }
    public func confirmResearchFrame(caseID: EntityID<Case>, contextText: NonEmptyText, reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "confirmResearchFrame") { stage, plan, checkpoint in
            guard let graph = try stage.loadCase(id: caseID), let head = graph.find(graph.cases[0].currentPromiseRevisionID), !plan.criterionIDs.isEmpty else { throw ResearchReviewError.unconfirmedCriteria }
            for id in plan.criterionIDs.values {
                guard ResearchReviewPlan.wasUnused(id, operation: "acceptResearchCriterionProposal", in: graph) else { throw ResearchReviewError.missingDecision }
            }
            try stage.verifyPromiseForEvaluationReadiness(caseID: caseID, contextText: contextText, contextExcerptIDs: head.quote.excerptIDs,
                speakerExcerptIDs: head.quote.excerptIDs, reviewer: reviewer, at: date)
            var dto = CaseGraphDTO(try stage.loadCase(id: caseID)!)
            for id in dto.cases[0].activeCriterionRevisionIDs {
                let reboundGraph = try dto.domain()
                guard let revision = reboundGraph.find(EntityID<CriterionRevision>(id.value)) else { throw ResearchReviewError.staleResearch }
                let confirmed = try DomainChanges.transition(revision, to: .confirmed, review: HumanReview(reviewerID: reviewer.id, reviewedAt: date), in: reboundGraph)
                dto.criterionRevisions[dto.criterionRevisions.firstIndex { $0.id.value == id.value }!] = CriterionRevisionDTO(confirmed)
                try self.reviewAudit(&dto, old: ObjectReference(kind: .criterionRevision, id: revision.id), operation: "confirmCriterion", reviewer: reviewer, at: date)
            }
            try stage.saveCase(dto.domain())
            try stage.advanceEvaluationReadiness(caseID: caseID, to: .verified, reviewer: reviewer, at: date)
            try checkpoint(try stage.loadCase(id: caseID)!)
            try stage.advanceEvaluationReadiness(caseID: caseID, to: .readyForEvaluation, reviewer: reviewer, at: date)
        }
    }
    public func reviewResearchDevelopment(caseID: EntityID<Case>, key: String, use: Bool, scope: NonEmptyText? = nil, eventDate: DatedValue? = nil, reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "reviewResearchDevelopment") { stage, plan, _ in
            guard let raw = plan.record.bindings?.actionRevisions[key], let proposal = plan.record.result.developments.first(where: { $0.developmentKey == key }),
                  let graph = try stage.loadCase(id: caseID), let old = graph.find(EntityID<ActionRevision>(raw)), graph.find(old.actionID)?.currentRevisionID == old.id else { throw ResearchReviewError.staleResearch }
            if use {
                let ids = try proposal.excerptKeys.map { k -> EntityID<SourceExcerpt> in guard let id = plan.excerptIDs[k] else { throw ResearchReviewError.incompleteSources }; return id }
                let scopeValue = scope.map { FieldValue<NonEmptyText>.known($0) } ?? old.scope.content
                let eventValue = eventDate.map { FieldValue<DatedValue>.known($0) } ?? old.eventDate.content
                guard scopeValue.knownValue != nil, eventValue.knownValue?.content.knownValue != nil else { throw ResearchReviewError.unverifiedAction }
                if old.scope.content.knownValue != nil && scopeValue != old.scope.content { throw ResearchReviewError.staleResearch }
                if old.eventDate.content.knownValue?.content.knownValue != nil && eventValue != old.eventDate.content { throw ResearchReviewError.staleResearch }
                var currentID = old.id
                if scopeValue != old.scope.content || eventValue != old.eventDate.content {
                    let prepared = try ActionRevision(actionID: old.actionID, type: old.type, title: old.title,
                        description: old.description,
                        eventDate: try AssertedValue(content: eventValue, provenance: eventDate == nil ? old.eventDate.provenance : .humanEntered),
                        validity: old.validity, institutionalLevel: old.institutionalLevel, objectIdentifier: old.objectIdentifier,
                        proceduralState: old.proceduralState,
                        scope: try AssertedValue(content: scopeValue, provenance: scope == nil ? old.scope.provenance : .humanEntered),
                        excerptIDs: old.excerptIDs,
                        metadata: RevisionMetadata(number: old.metadata.number + 1, reason: NonEmptyText("Handlungsumfang oder Ereignisdatum ausdrücklich menschlich ergänzt"), author: .human(reviewer.id), createdAt: date))
                    var dto = CaseGraphDTO(graph); dto.actionRevisions.append(ActionRevisionDTO(prepared))
                    dto.actions[dto.actions.firstIndex { $0.id.value == old.actionID.rawValue }!].currentRevisionID = StoredID(prepared.id, kind: "ActionRevision")
                    dto.cases[0].currentActionRevisionIDs = dto.cases[0].currentActionRevisionIDs.map { $0.value == old.id.rawValue ? StoredID(prepared.id, kind: "ActionRevision") : $0 }
                    try self.reviewAudit(&dto, old: ObjectReference(kind: .actionRevision, id: old.id), new: ObjectReference(kind: .actionRevision, id: prepared.id), operation: "prepareResearchDevelopment", reviewer: reviewer, at: date)
                    try stage.saveCase(dto.domain()); currentID = prepared.id
                }
                try stage.verifyAction(caseID: caseID, revisionID: currentID, excerptIDs: Array(Set(ids)), reviewer: reviewer, at: date)
            } else {
                var dto = CaseGraphDTO(graph); dto.cases[0].currentActionRevisionIDs.removeAll { $0.value == raw }
                try self.reviewAudit(&dto, old: ObjectReference(kind: .actionRevision, id: old.id), operation: "ignoreResearchDevelopment", reviewer: reviewer, at: date)
                try stage.saveCase(dto.domain())
            }
        }
    }
    public func adoptResearchEvidence(caseID: EntityID<Case>, key: String, use: Bool, reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "adoptResearchEvidence") { stage, plan, _ in
            guard let proposal = plan.record.result.evidenceProposals.first(where: { $0.evidenceKey == key }),
                  let raw = plan.record.bindings?.evidenceLinks[key], plan.evidenceIDs[key] == nil,
                  let graph = try stage.loadCase(id: caseID) else { throw ResearchReviewError.staleResearch }
            let old = EntityID<EvidenceLink>(raw)
            if !use {
                var dto = CaseGraphDTO(graph)
                try self.reviewAudit(&dto, old: ObjectReference(kind: .evidenceLink, id: old), operation: "ignoreResearchEvidence", reviewer: reviewer, at: date)
                try stage.saveCase(dto.domain()); return
            }
            guard plan.evidence.first(where: { $0.key == key })?.state == .ready,
                  let criterion = plan.criterionIDs[proposal.criterionKey] else { throw ResearchReviewError.incompleteSources }
            let excerpts = try proposal.excerptKeys.map { k -> EntityID<SourceExcerpt> in guard let id = plan.excerptIDs[k] else { throw ResearchReviewError.incompleteSources }; return id }
            let link = EvidenceLink(criterionRevisionID: criterion, excerptIDs: Array(Set(excerpts)), actionRevisionID: proposal.developmentKey.flatMap { plan.actionIDs[$0] },
                relationship: proposal.relationship.domain, directness: proposal.directness.domain, rationale: try NonEmptyText(proposal.rationale),
                temporalReference: try DiscoveryDates.value(proposal.temporalDate, role: proposal.temporalRole == .event ? .event : .validity),
                metadata: RevisionMetadata(number: 1, reason: try NonEmptyText("KI-Zuordnung ausdrücklich menschlich übernommen"), author: .human(reviewer.id), createdAt: date))
            try stage.addEvidenceDraft(caseID: caseID, link: link, reviewer: reviewer, at: date)
            try stage.requestEvidenceReview(caseID: caseID, linkID: link.id, reviewer: reviewer, at: date)
            try stage.verifyEvidence(caseID: caseID, linkID: link.id, reviewer: reviewer, at: date, reason: NonEmptyText("Recherche-Evidenz und Gegenbelege menschlich geprüft"))
            var dto = CaseGraphDTO(try stage.loadCase(id: caseID)!)
            try self.reviewAudit(&dto, old: ObjectReference(kind: .evidenceLink, id: old), new: ObjectReference(kind: .evidenceLink, id: link.id), operation: "adoptResearchEvidence", reviewer: reviewer, at: date)
            try stage.saveCase(dto.domain())
        }
    }
    public func materializeResearchAssessment(caseID: EntityID<Case>, acknowledgeOmittedCounterEvidence: Bool,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "materializeResearchAssessment") { stage, plan, _ in
            guard plan.warnings.isEmpty || acknowledgeOmittedCounterEvidence else { throw ResearchReviewError.confirmationRequired }
            guard let graph = try stage.loadCase(id: caseID) else { throw ResearchReviewError.staleResearch }
            let input = try ResearchAssessmentMapping.materialize(plan: plan, graph: graph)
            // The existing snapshot includes research history states too. Keep its semantics; only checked working actions participate.
            var dto = CaseGraphDTO(graph)
            var selectedActions: [StoredID] = []
            for id in dto.cases[0].currentActionRevisionIDs {
                guard let revision = graph.find(EntityID<ActionRevision>(id.value)) else { throw ResearchReviewError.staleResearch }
                if revision.description.verification == .verified && revision.eventDate.verification == .verified && revision.scope.verification == .verified {
                    selectedActions.append(id)
                } else if plan.record.bindings?.actionRevisions.values.contains(id.value) == true {
                    try self.reviewAudit(&dto, old: ObjectReference(kind: .actionRevision, id: revision.id), operation: "ignoreResearchDevelopment", reviewer: reviewer, at: date)
                } else { throw ResearchReviewError.missingDecision }
            }
            dto.cases[0].currentActionRevisionIDs = selectedActions
            try stage.saveCase(dto.domain())
            let snapshot = try stage.startEvaluationSnapshot(caseID: caseID, cutoff: input.cutoff, reviewer: reviewer, at: date)
            _ = try stage.createEvaluationDraft(caseID: caseID, snapshotID: snapshot.id, cutoff: input.cutoff, criteria: input.criteria,
                overall: input.overall, facts: input.facts, interpretations: input.interpretations, reviewer: reviewer, at: date)
        }
    }
    public func approveResearchEvaluation(caseID: EntityID<Case>, evaluationID: EntityID<CaseEvaluation>,
        checkedCriterionIDs: Set<EntityID<CriterionEvaluation>>, explicitConfirmation: Bool, acknowledgeOmittedCounterEvidence: Bool,
        reviewer: ReviewerIdentity, at date: Date) throws {
        try reviewTransaction(caseID: caseID, reviewer: reviewer, operation: "approveResearchEvaluation") { stage, plan, checkpoint in
            guard explicitConfirmation, plan.warnings.isEmpty || acknowledgeOmittedCounterEvidence,
                  let graph = try stage.loadCase(id: caseID), let evaluation = graph.find(evaluationID),
                  Set(evaluation.criterionEvaluationIDs) == checkedCriterionIDs, evaluation.status == .draft else { throw ResearchReviewError.confirmationRequired }
            for id in evaluation.criterionEvaluationIDs {
                if graph.find(id)?.reviewState == .unreviewed { try stage.reviewCriterionEvaluation(caseID: caseID, childID: id, reviewer: reviewer, at: date) }
            }
            try stage.submitEvaluationForReview(caseID: caseID, evaluationID: evaluationID, reviewer: reviewer, at: date)
            try checkpoint(try stage.loadCase(id: caseID)!)
            try stage.approveEvaluation(caseID: caseID, evaluationID: evaluationID, reviewer: reviewer, at: date)
        }
    }
}
