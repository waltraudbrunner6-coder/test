import Foundation
@testable import PoliticalFactCheckCore

func text(_ value: String) -> NonEmptyText { try! NonEmptyText(value) }

/// Entirely synthetic. Dates denote invented events, never real political cases.
struct ScriptFixture {
    static let event = Date(timeIntervalSince1970: 1_609_459_200) // 2021
    static let cutoff = Date(timeIntervalSince1970: 1_640_995_200) // 2022
    static let publication = Date(timeIntervalSince1970: 1_735_689_600) // 2025
    static let creation = Date(timeIntervalSince1970: 1_767_225_600) // 2026

    let reviewer: ReviewerIdentity
    let speaker: Actor
    let party: Actor
    let politicalCase: Case
    let promise: Promise
    let promiseRevision: PromiseRevision
    let criterion: EvaluationCriterion
    let criterionRevision: CriterionRevision
    let source: Source
    let sourceVersion: SourceVersion
    let excerpt: SourceExcerpt
    let action: ActionOrDevelopment
    let actionRevision: ActionRevision
    let evidence: EvidenceLink
    let snapshot: CaseRevision
    let criterionEvaluation: CriterionEvaluation
    let evaluation: CaseEvaluation
    let methodology: MethodologyVersion
    let sourcePresent: Bool
    let includeEvidence: Bool
    let includeAction: Bool

    var review: HumanReview { HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(86_400)) }
    var approval: HumanReview { HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(4 * 86_400)) }

    init(partyName: String = "Synthetic Party Alpha", sourcePresent: Bool = true,
         excerptState: ExcerptVerificationState = .verified, excerptReview: Bool = true,
         quoteHasExcerpt: Bool = true, criterionState: CriterionRevisionState = .confirmed,
         linkHasExcerpt: Bool = true, linkStatus: EvidenceLinkStatus = .verified,
         relationship: EvidenceRelationship = .supports, includeEvidence: Bool = true,
         category: EvaluationCategory = .fulfilled, confidence: EvidenceConfidence = .high,
         reasons: [NotVerifiableReason] = [], status: EvaluationStatus = .approved,
         hasApproval: Bool = true, eventDate: Date = ScriptFixture.event,
         includeAction: Bool = false, actionHasExcerpt: Bool = true) throws {
        self.sourcePresent = sourcePresent; self.includeEvidence = includeEvidence; self.includeAction = includeAction
        reviewer = ReviewerIdentity(displayName: text("Synthetic Editor"))
        let human = HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(86_400))
        let approved = HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(4 * 86_400))
        speaker = Actor(name: text("Synthetic Speaker"), type: .person)
        party = Actor(name: text(partyName), type: .party)
        let caseID = EntityID<Case>()
        let promiseID = EntityID<Promise>()
        let promiseRevisionID = EntityID<PromiseRevision>()
        let criterionID = EntityID<EvaluationCriterion>()
        let criterionRevisionID = EntityID<CriterionRevision>()
        let evaluationID = EntityID<CaseEvaluation>()
        let excerptID = EntityID<SourceExcerpt>()
        let actionID = EntityID<ActionOrDevelopment>()
        let actionRevisionID = EntityID<ActionRevision>()
        let meta = RevisionMetadata(number: 1, reason: text("Synthetic initial revision"), author: .human(reviewer.id), createdAt: Self.creation)
        source = Source(canonicalURL: URL(string: "https://synthetic.example.invalid/document"))
        sourceVersion = SourceVersion(sourceID: source.id, kind: .original,
            publicationDate: try .instant(Self.publication, role: .publication),
            retrievedAt: try .instant(Self.creation, role: .retrieval),
            eventDate: try .instant(eventDate, role: .event), availability: .available,
            verification: .verified, review: human, contentType: text("text/plain"), language: text("en"))
        excerpt = SourceExcerpt(id: excerptID, sourceVersionID: sourceVersion.id,
            locator: text("paragraph 1"), text: text("The synthetic service will be available."),
            context: text("Synthetic document describing an invented promise and event."), language: text("en"),
            state: excerptState, review: excerptReview ? human : nil, createdAt: Self.creation)
        func asserted<Value>(_ value: Value, excerpts: [EntityID<SourceExcerpt>] = []) throws -> AssertedValue<Value> {
            try AssertedValue(content: .known(value), provenance: .humanEntered, verification: .verified,
                              excerptIDs: excerpts.isEmpty ? [excerptID] : excerpts, review: human)
        }
        promise = Promise(id: promiseID, caseID: caseID, currentRevisionID: promiseRevisionID, createdAt: Self.creation)
        promiseRevision = PromiseRevision(id: promiseRevisionID, promiseID: promiseID,
            quote: try AssertedValue(content: .known(excerpt.text), provenance: .imported, verification: .verified,
                                     excerptIDs: quoteHasExcerpt ? [excerptID] : [], review: human),
            thesis: text("Verify availability of a synthetic service."),
            statementDate: try asserted(DatedValue.instant(Self.event.addingTimeInterval(-86_400), role: .statement)),
            context: try asserted(text("Synthetic announcement")), targetGroup: try asserted(text("Synthetic users")),
            conditions: try asserted([NonEmptyText]()), responsibility: try asserted(text("Synthetic institution")),
            speaker: try asserted(speaker.id), party: try asserted(party.id), metadata: meta)
        criterion = EvaluationCriterion(id: criterionID, promiseID: promiseID, currentRevisionID: criterionRevisionID)
        criterionRevision = CriterionRevision(id: criterionRevisionID, criterionID: criterionID,
            promiseRevisionID: promiseRevisionID, goal: text("The synthetic service is available."), targetGroup: text("Synthetic users"),
            baseline: .unknown(reason: text("Not needed for this synthetic fixture")), deadline: try .instant(Self.event, role: .deadline),
            conditions: .known([]), isCore: true, materialityRule: text("Availability is the sole core criterion."),
            metadata: meta, state: criterionState, confirmation: criterionState == .draft ? nil : human)
        politicalCase = Case(id: caseID, title: text("Synthetic case"), promiseID: promiseID,
            currentPromiseRevisionID: promiseRevisionID, activeCriterionRevisionIDs: [criterionRevisionID],
            createdAt: Self.creation, modifiedAt: Self.creation)
        action = ActionOrDevelopment(id: actionID, caseID: caseID, currentRevisionID: actionRevisionID)
        actionRevision = ActionRevision(id: actionRevisionID, actionID: actionID, type: .implementation,
            title: text("Synthetic implementation"), description: try asserted(text("Synthetic service became available")),
            eventDate: try asserted(DatedValue.instant(eventDate, role: .event)), proceduralState: text("implemented"),
            scope: try asserted(text("Synthetic users")), excerptIDs: actionHasExcerpt ? [excerptID] : [], metadata: meta)
        evidence = EvidenceLink(criterionRevisionID: criterionRevisionID, excerptIDs: linkHasExcerpt ? [excerptID] : [],
            actionRevisionID: includeAction ? actionRevisionID : nil, relationship: relationship, directness: .direct,
            rationale: text("Synthetic source documents the relevant fact."), temporalReference: try .instant(eventDate, role: .event),
            status: linkStatus, review: human, metadata: meta)
        snapshot = CaseRevision(caseID: caseID, promiseRevisionID: promiseRevisionID,
            criteria: [.init(id: criterionRevisionID, state: criterionState)], actionRevisionIDs: includeAction ? [actionRevisionID] : [],
            sourceVersions: [.init(id: sourceVersion.id, state: .verified)], excerpts: [.init(id: excerptID, state: excerptState)],
            evidenceLinks: includeEvidence ? [.init(id: evidence.id, state: linkStatus)] : [],
            metadata: RevisionMetadata(number: 1, reason: text("Synthetic frozen input"), author: .human(reviewer.id),
                                       createdAt: Self.creation.addingTimeInterval(2 * 86_400)))
        methodology = MethodologyVersion(version: text("TEST-FIXTURE-ONLY"), title: text("Synthetic test methodology"),
            contentReference: text("Synthetic fixture, not a political methodology version 1.0"), changeNote: text("Tests only"))
        criterionEvaluation = CriterionEvaluation(caseEvaluationID: evaluationID, criterionRevisionID: criterionRevisionID,
            category: category, rationale: text("Synthetic criterion assessment"), evidenceLinkIDs: includeEvidence ? [evidence.id] : [],
            confidence: confidence, notVerifiableReasons: reasons, reviewState: .reviewed, review: approved)
        evaluation = CaseEvaluation(id: evaluationID, caseID: caseID, caseRevisionID: snapshot.id,
            cutoff: try .instant(Self.cutoff, role: .evaluationCutoff), methodologyVersionID: methodology.id,
            criterionEvaluationIDs: [criterionEvaluation.id], category: category, rationale: text("Synthetic overall assessment"),
            confidence: confidence, notVerifiableReasons: reasons,
            metadata: RevisionMetadata(number: 1, reason: text("Synthetic assessment"), author: .human(reviewer.id),
                                       createdAt: Self.creation.addingTimeInterval(3 * 86_400)),
            status: status, approval: hasApproval ? approved : nil)
    }

    func context(extraCriteria: [CriterionRevision] = [], extraLinks: [EvidenceLink] = [],
                 excerptOverride: SourceExcerpt? = nil, versionOverride: SourceVersion? = nil,
                 scripts: [ScriptDraft] = [], statements: [ScriptStatement] = []) -> DomainContext {
        DomainContext(reviewers: [reviewer], cases: [politicalCase], actors: [speaker, party],
            promises: [promise], promiseRevisions: [promiseRevision], criteria: [criterion],
            criterionRevisions: [criterionRevision] + extraCriteria, sources: [source],
            sourceVersions: sourcePresent ? [versionOverride ?? sourceVersion] : [], excerpts: [excerptOverride ?? excerpt],
            actions: includeAction ? [action] : [], actionRevisions: includeAction ? [actionRevision] : [],
            evidenceLinks: [evidence] + extraLinks, caseRevisions: [snapshot],
            criterionEvaluations: [criterionEvaluation], caseEvaluations: [evaluation], methodologies: [methodology],
            scripts: scripts, statements: statements)
    }
}

func reviewedGraph(_ f: ScriptFixture, status: ScriptStatus, reviewed: Bool = true,
                   factSource: Bool = true, version: Int = 1) -> DomainContext {
    let id = EntityID<ScriptDraft>(), date = ScriptFixture.creation.addingTimeInterval(5 * 86_400)
    let review = reviewed ? HumanReview(reviewerID: f.reviewer.id, reviewedAt: date.addingTimeInterval(100)) : nil
    let fact = ScriptStatement(scriptDraftID: id, position: 0, text: text("Synthetic source fact"), kind: .fact,
        excerptIDs: factSource ? [f.excerpt.id] : [], evidenceLinkIDs: factSource ? [f.evidence.id] : [], review: review)
    let interpretation = ScriptStatement(scriptDraftID: id, position: 1, text: text("Synthetic interpretation with several words"),
        kind: .interpretation, uncertainty: text("Synthetic uncertainty"), review: review)
    let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: version, targetDurationSeconds: 45,
        statementIDs: [interpretation.id, fact.id], status: status, author: .ai(model: text("synthetic-test-only"), templateVersion: nil),
        createdAt: date, approval: status == .approved || status == .superseded ? review : nil)
    return f.context(scripts: [script], statements: [interpretation, fact])
}

import PoliticalFactCheckVideoPlanning
import PoliticalFactCheckAudio

func audioHandoff(texts: [String] = ["Synthetic narration fact.", "Synthetic interpretation only."]) throws -> VideoScriptHandoffV1 {
    let f = try ScriptFixture(), id = EntityID<ScriptDraft>(), date = ScriptFixture.creation.addingTimeInterval(6 * 86400)
    let review = HumanReview(reviewerID: f.reviewer.id, reviewedAt: date)
    let statements = texts.enumerated().map { index, value in
        ScriptStatement(scriptDraftID: id, position: index, text: text(value), kind: .interpretation, review: review)
    }
    let script = ScriptDraft(id: id, caseEvaluationID: f.evaluation.id, version: 1, targetDurationSeconds: 45,
        statementIDs: statements.map { $0.id }, status: .approved, author: .human(f.reviewer.id), createdAt: date, approval: review)
    return try VideoScriptHandoffBuilder.build(scriptID: id, in: f.context(scripts: [script], statements: statements))
}
func audioRequest(_ value: String = "Synthetic exact narration.") throws -> NarrationRequest {
    NarrationRequest(scenePosition: 0, statementID: EntityID<ScriptStatement>(), text: value, instructions: try NarrationStyleV1.instructions())
}
func audioTestDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-narration-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.resolvingSymlinksInPath()
}
