import Foundation
import PoliticalFactCheckCore

public enum ResearchReviewError: Error, Equatable {
    case staleResearch, incompleteSources, unconfirmedCriteria, unverifiedAction, noRecommendation, missingDecision, confirmationRequired
    public var displayMessage: String {
        switch self {
        case .staleResearch: return "Die Recherche passt nicht mehr zum aktuellen Fallstand. Bitte Recherche aktualisieren."
        case .incompleteSources: return "Mindestens eine verwendete Fundstelle ist noch ungeprüft oder wurde abgelehnt."
        case .unconfirmedCriteria: return "Die aktuellen ausgewählten Kriterien müssen menschlich bestätigt werden."
        case .unverifiedAction: return "Die verwendete Entwicklung ist noch nicht anhand geprüfter Fundstellen bestätigt."
        case .noRecommendation: return "KI gibt keine belastbare Empfehlung. Bitte manuell bewerten oder Recherche offen lassen."
        case .missingDecision: return "Für mindestens einen verwendeten Vorschlag fehlt eine ausdrückliche Entscheidung."
        case .confirmationRequired: return "Alle Kriteriumskarten und gegebenenfalls nicht übernommene Gegenbelege müssen ausdrücklich bestätigt werden."
        }
    }
}
public enum ResearchReviewItemState: String { case open, ready, reviewed, notUsed, rejected, blocked }
public struct ResearchReviewItem {
    public let key: String
    public let state: ResearchReviewItemState
}
/// Derived only. Audit before/after references are the durable adoption lineage, not a second workflow.
public struct ResearchReviewPlan {
    public let record: DeepResearchRecordV1
    public let originalExcerptID: EntityID<SourceExcerpt>?
    public let originalSource: ResearchReviewItemState
    public let criteria: [ResearchReviewItem]
    public let evidenceSources: [ResearchReviewItem]
    public let developments: [ResearchReviewItem]
    public let evidence: [ResearchReviewItem]
    public let assessment: ResearchReviewItemState
    public let blockingIssues: [String]
    public let warnings: [String]
    public let completedSteps: Int
    public let criterionIDs: [String: EntityID<CriterionRevision>]
    public let excerptIDs: [String: EntityID<SourceExcerpt>]
    public let actionIDs: [String: EntityID<ActionRevision>]
    public let evidenceIDs: [String: EntityID<EvidenceLink>]

    public static func linkedID<T>(_ old: EntityID<T>, operation: String, kind: EntityKind, in graph: DomainContext) throws -> EntityID<T>? {
        let matches = graph.auditEntries.filter { $0.operation.value == operation && $0.before?.kind == kind && $0.before?.id == old.rawValue }
        guard matches.count <= 1 else { throw ResearchReviewError.staleResearch }
        guard let audit = matches.first else { return nil }
        guard case .human(let reviewer) = audit.author, graph.find(reviewer) != nil,
              let after = audit.after, after.kind == kind, after == audit.target else { throw ResearchReviewError.staleResearch }
        return EntityID<T>(after.id)
    }
    public static func wasUnused<T>(_ old: EntityID<T>, operation: String, in graph: DomainContext) -> Bool {
        graph.auditEntries.contains { entry in
            guard entry.operation.value == operation, entry.target.id == old.rawValue, case .human = entry.author else { return false }
            return true
        }
    }
    public init(graph: DomainContext, record: DeepResearchRecordV1) throws {
        guard try CaseResearchDraftMapper.dossier(in: graph) == record, let b = record.bindings,
              let root = graph.cases.first, let original = graph.find(EntityID<PromiseRevision>(record.promiseRevisionID)),
              let current = graph.find(root.currentPromiseRevisionID), original.promiseID == current.promiseID,
              original.quote.content == current.quote.content else { throw ResearchReviewError.staleResearch }
        self.record = record
        var cs: [ResearchReviewItem] = [], es: [ResearchReviewItem] = [], ds: [ResearchReviewItem] = [], ls: [ResearchReviewItem] = []
        var criterionMap: [String: EntityID<CriterionRevision>] = [:], excerptMap: [String: EntityID<SourceExcerpt>] = [:]
        var actionMap: [String: EntityID<ActionRevision>] = [:], evidenceMap: [String: EntityID<EvidenceLink>] = [:]
        for c in record.result.proposedCriteria {
            guard let id = b.criterionRevisions[c.criterionKey], let old = graph.find(EntityID<CriterionRevision>(id)),
                  let entity = graph.find(old.criterionID), let head = graph.find(entity.currentRevisionID) else { throw ResearchReviewError.staleResearch }
            let unused = Self.wasUnused(old.id, operation: "rejectResearchCriterionProposal", in: graph)
            if unused { cs.append(.init(key: c.criterionKey, state: .notUsed)); continue }
            guard root.activeCriterionRevisionIDs.contains(head.id), head.promiseRevisionID == root.currentPromiseRevisionID || current.context.verification != .verified,
                  head.goal == old.goal, head.targetGroup == old.targetGroup, head.baseline == old.baseline,
                  head.deadline == old.deadline, head.conditions == old.conditions, head.isCore == old.isCore,
                  head.materialityRule == old.materialityRule else { throw ResearchReviewError.staleResearch }
            if head.id != old.id {
                guard try Self.linkedID(old.id, operation: "rebindCriterionToPromise", kind: .criterionRevision, in: graph) == head.id else { throw ResearchReviewError.staleResearch }
            }
            criterionMap[c.criterionKey] = head.id
            cs.append(.init(key: c.criterionKey, state: head.state == .confirmed ? .reviewed : .ready))
        }
        guard Set(root.activeCriterionRevisionIDs) == Set(criterionMap.values) else { throw ResearchReviewError.staleResearch }
        for e in record.result.excerpts {
            guard let id = b.excerpts[e.excerptKey], let old = graph.find(EntityID<SourceExcerpt>(id)) else { throw ResearchReviewError.staleResearch }
            let adopted = try Self.linkedID(old.id, operation: "reviewResearchExcerpt", kind: .excerpt, in: graph)
            let checked = adopted.flatMap { graph.find($0) } ?? (old.state == .verified ? old : nil)
            if let checked {
                guard checked.state == .verified, checked.text == old.text, checked.locator == old.locator,
                      let version = graph.find(checked.sourceVersionID), let oldVersion = graph.find(old.sourceVersionID),
                      version.sourceID == oldVersion.sourceID, version.verification == .verified,
                      DomainValidator.validate(checked, in: graph).isValid else { throw ResearchReviewError.staleResearch }
                excerptMap[e.excerptKey] = checked.id
            }
            es.append(.init(key: e.excerptKey, state: checked != nil ? .reviewed : old.state == .rejected ? .rejected : .ready))
        }
        for d in record.result.developments {
            guard let id = b.actionRevisions[d.developmentKey], let old = graph.find(EntityID<ActionRevision>(id)),
                  let action = graph.find(old.actionID), let head = graph.find(action.currentRevisionID) else { throw ResearchReviewError.staleResearch }
            let unused = Self.wasUnused(old.id, operation: "ignoreResearchDevelopment", in: graph)
            if unused { ds.append(.init(key: d.developmentKey, state: .notUsed)); continue }
            let reviewed = head.id != old.id && head.description.verification == .verified && head.eventDate.verification == .verified && head.scope.verification == .verified
            if reviewed {
                let expected = Set(d.excerptKeys.compactMap { excerptMap[$0] })
                let preparedID = try Self.linkedID(old.id, operation: "prepareResearchDevelopment", kind: .actionRevision, in: graph)
                let prepared = preparedID.flatMap { graph.find($0) } ?? old
                guard prepared.actionID == old.actionID, prepared.description.content == old.description.content,
                      graph.auditEntries.contains(where: { $0.operation.value == "verifyAction" && $0.before?.id == prepared.id.rawValue && $0.target.id == head.id.rawValue }),
                      expected.count == Set(d.excerptKeys.compactMap { b.excerpts[$0] }).count,
                      Set(head.excerptIDs) == expected, head.description.content == old.description.content,
                      head.eventDate.content == prepared.eventDate.content, head.scope.content == prepared.scope.content,
                      DomainValidator.validate(head, in: graph).isValid else { throw ResearchReviewError.staleResearch }
                actionMap[d.developmentKey] = head.id
            }
            ds.append(.init(key: d.developmentKey, state: reviewed ? .reviewed : d.excerptKeys.allSatisfy { excerptMap[$0] != nil } ? .ready : .blocked))
        }
        for e in record.result.evidenceProposals {
            guard let oldID = b.evidenceLinks[e.evidenceKey] else { throw ResearchReviewError.staleResearch }
            let old = EntityID<EvidenceLink>(oldID)
            if Self.wasUnused(old, operation: "ignoreResearchEvidence", in: graph) { ls.append(.init(key: e.evidenceKey, state: .notUsed)); continue }
            if let adopted = try Self.linkedID(old, operation: "adoptResearchEvidence", kind: .evidenceLink, in: graph) {
                guard let link = graph.find(adopted), link.status == .verified,
                      link.criterionRevisionID == criterionMap[e.criterionKey], Set(link.excerptIDs) == Set(e.excerptKeys.compactMap { excerptMap[$0] }),
                      link.actionRevisionID == e.developmentKey.flatMap({ actionMap[$0] }),
                      link.relationship == e.relationship.domain, link.directness == e.directness.domain,
                      DomainValidator.validate(link, in: graph).isValid else { throw ResearchReviewError.staleResearch }
                evidenceMap[e.evidenceKey] = adopted; ls.append(.init(key: e.evidenceKey, state: .reviewed))
            } else {
                let ready = criterionMap[e.criterionKey].flatMap { graph.find($0) }?.state == .confirmed && e.excerptKeys.allSatisfy { excerptMap[$0] != nil } && (e.developmentKey == nil || actionMap[e.developmentKey!] != nil)
                ls.append(.init(key: e.evidenceKey, state: ready ? .ready : .blocked))
            }
        }
        let originalKey = record.result.excerpts.first { e in
            e.text == record.discovery.candidate.exactQuote && record.result.sources.contains { $0.claim.sourceKey == e.sourceKey && $0.searchSource.url == record.discovery.candidate.sourceURL }
        }?.excerptKey
        originalExcerptID = originalKey.flatMap { b.excerpts[$0] }.map { EntityID<SourceExcerpt>($0) }
        originalSource = current.quote.verification == .verified ? .reviewed : originalExcerptID.flatMap { graph.find($0) }?.state == .rejected ? .rejected : originalKey.flatMap { excerptMap[$0] } != nil ? .ready : originalExcerptID == nil ? .blocked : .open
        criteria = cs; evidenceSources = es; developments = ds; evidence = ls
        criterionIDs = criterionMap; excerptIDs = excerptMap; actionIDs = actionMap; evidenceIDs = evidenceMap
        var blockers: [String] = []
        if originalSource != .reviewed { blockers.append("Originalaussage und Originalfundstelle müssen geprüft werden.") }
        if criterionMap.isEmpty || cs.contains(where: { $0.state != .reviewed && $0.state != .notUsed }) { blockers.append(ResearchReviewError.unconfirmedCriteria.displayMessage) }
        if record.result.overallAssessmentDraft.suggestedCategory == nil { blockers.append(ResearchReviewError.noRecommendation.displayMessage) }
        for assessment in record.result.criterionAssessmentDrafts where criterionMap[assessment.criterionKey] != nil {
            if assessment.suggestedCategory == nil { blockers.append("KI gibt für \(assessment.criterionKey) keine belastbare Empfehlung.") }
            if (assessment.supportingEvidenceKeys + assessment.counterEvidenceKeys).contains(where: { evidenceMap[$0] == nil }) { blockers.append("Für \(assessment.criterionKey) fehlt noch mindestens eine geprüfte Evidenzzuordnung.") }
        }
        if root.workflowState != .readyForEvaluation && root.workflowState != .evaluated && root.workflowState != .approved { blockers.append("Der Fall hat die Bewertungsreife noch nicht erreicht.") }
        warnings = record.result.evidenceProposals.filter { $0.relationship == .contradicts && evidenceMap[$0.evidenceKey] == nil }.map { "Ein recherchierter Gegenbeleg wurde nicht übernommen: " + $0.evidenceKey }
        blockingIssues = blockers
        if let evaluation = graph.caseEvaluations.last { assessment = evaluation.status == .approved ? .reviewed : .open }
        else { assessment = blockers.isEmpty ? .ready : .blocked }
        completedSteps = (originalSource == .reviewed ? 1 : 0) + (cs.allSatisfy { $0.state == .reviewed || $0.state == .notUsed } && !cs.isEmpty ? 1 : 0) + (ls.allSatisfy { $0.state == .reviewed || $0.state == .notUsed } && !ls.isEmpty ? 2 : 0) + (ds.allSatisfy { $0.state == .reviewed || $0.state == .notUsed } ? 1 : 0) + (assessment == .reviewed ? 1 : 0)
    }
}
