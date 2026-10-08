import Foundation
@testable import PoliticalFactCheckCore

private func packageFixtureText(_ value: String) -> NonEmptyText { try! NonEmptyText(value) }

/// Entirely synthetic. Dates denote invented events, never real political cases.
struct PackageFixtureBase {
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
         hasApproval: Bool = true, eventDate: Date = PackageFixtureBase.event,
         includeAction: Bool = false, actionHasExcerpt: Bool = true) throws {
        self.sourcePresent = sourcePresent; self.includeEvidence = includeEvidence; self.includeAction = includeAction
        reviewer = ReviewerIdentity(displayName: packageFixtureText("Synthetic Editor"))
        let human = HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(86_400))
        let approved = HumanReview(reviewerID: reviewer.id, reviewedAt: Self.creation.addingTimeInterval(4 * 86_400))
        speaker = Actor(name: packageFixtureText("Synthetic Speaker"), type: .person)
        party = Actor(name: packageFixtureText(partyName), type: .party)
        let caseID = EntityID<Case>()
        let promiseID = EntityID<Promise>()
        let promiseRevisionID = EntityID<PromiseRevision>()
        let criterionID = EntityID<EvaluationCriterion>()
        let criterionRevisionID = EntityID<CriterionRevision>()
        let evaluationID = EntityID<CaseEvaluation>()
        let excerptID = EntityID<SourceExcerpt>()
        let actionID = EntityID<ActionOrDevelopment>()
        let actionRevisionID = EntityID<ActionRevision>()
        let meta = RevisionMetadata(number: 1, reason: packageFixtureText("Synthetic initial revision"), author: .human(reviewer.id), createdAt: Self.creation)
        source = Source(canonicalURL: URL(string: "https://synthetic.example.invalid/document"))
        sourceVersion = SourceVersion(sourceID: source.id, kind: .original,
            publicationDate: try .instant(Self.publication, role: .publication),
            retrievedAt: try .instant(Self.creation, role: .retrieval),
            eventDate: try .instant(eventDate, role: .event), availability: .available,
            verification: .verified, review: human, contentType: packageFixtureText("text/plain"), language: packageFixtureText("en"))
        excerpt = SourceExcerpt(id: excerptID, sourceVersionID: sourceVersion.id,
            locator: packageFixtureText("paragraph 1"), text: packageFixtureText("The synthetic service will be available."),
            context: packageFixtureText("Synthetic document describing an invented promise and event."), language: packageFixtureText("en"),
            state: excerptState, review: excerptReview ? human : nil, createdAt: Self.creation)
        func asserted<Value>(_ value: Value, excerpts: [EntityID<SourceExcerpt>] = []) throws -> AssertedValue<Value> {
            try AssertedValue(content: .known(value), provenance: .humanEntered, verification: .verified,
                              excerptIDs: excerpts.isEmpty ? [excerptID] : excerpts, review: human)
        }
        promise = Promise(id: promiseID, caseID: caseID, currentRevisionID: promiseRevisionID, createdAt: Self.creation)
        promiseRevision = PromiseRevision(id: promiseRevisionID, promiseID: promiseID,
            quote: try AssertedValue(content: .known(excerpt.text), provenance: .imported, verification: .verified,
                                     excerptIDs: quoteHasExcerpt ? [excerptID] : [], review: human),
            thesis: packageFixtureText("Verify availability of a synthetic service."),
            statementDate: try asserted(DatedValue.instant(Self.event.addingTimeInterval(-86_400), role: .statement)),
            context: try asserted(packageFixtureText("Synthetic announcement")), targetGroup: try asserted(packageFixtureText("Synthetic users")),
            conditions: try asserted([NonEmptyText]()), responsibility: try asserted(packageFixtureText("Synthetic institution")),
            speaker: try asserted(speaker.id), party: try asserted(party.id), metadata: meta)
        criterion = EvaluationCriterion(id: criterionID, promiseID: promiseID, currentRevisionID: criterionRevisionID)
        criterionRevision = CriterionRevision(id: criterionRevisionID, criterionID: criterionID,
            promiseRevisionID: promiseRevisionID, goal: packageFixtureText("The synthetic service is available."), targetGroup: packageFixtureText("Synthetic users"),
            baseline: .unknown(reason: packageFixtureText("Not needed for this synthetic fixture")), deadline: try .instant(Self.event, role: .deadline),
            conditions: .known([]), isCore: true, materialityRule: packageFixtureText("Availability is the sole core criterion."),
            metadata: meta, state: criterionState, confirmation: criterionState == .draft ? nil : human)
        politicalCase = Case(id: caseID, title: packageFixtureText("Synthetic case"), promiseID: promiseID,
            currentPromiseRevisionID: promiseRevisionID, activeCriterionRevisionIDs: [criterionRevisionID],
            createdAt: Self.creation, modifiedAt: Self.creation)
        action = ActionOrDevelopment(id: actionID, caseID: caseID, currentRevisionID: actionRevisionID)
        actionRevision = ActionRevision(id: actionRevisionID, actionID: actionID, type: .implementation,
            title: packageFixtureText("Synthetic implementation"), description: try asserted(packageFixtureText("Synthetic service became available")),
            eventDate: try asserted(DatedValue.instant(eventDate, role: .event)), proceduralState: packageFixtureText("implemented"),
            scope: try asserted(packageFixtureText("Synthetic users")), excerptIDs: actionHasExcerpt ? [excerptID] : [], metadata: meta)
        evidence = EvidenceLink(criterionRevisionID: criterionRevisionID, excerptIDs: linkHasExcerpt ? [excerptID] : [],
            actionRevisionID: includeAction ? actionRevisionID : nil, relationship: relationship, directness: .direct,
            rationale: packageFixtureText("Synthetic source documents the relevant fact."), temporalReference: try .instant(eventDate, role: .event),
            status: linkStatus, review: human, metadata: meta)
        snapshot = CaseRevision(caseID: caseID, promiseRevisionID: promiseRevisionID,
            criteria: [.init(id: criterionRevisionID, state: criterionState)], actionRevisionIDs: includeAction ? [actionRevisionID] : [],
            sourceVersions: [.init(id: sourceVersion.id, state: .verified)], excerpts: [.init(id: excerptID, state: excerptState)],
            evidenceLinks: includeEvidence ? [.init(id: evidence.id, state: linkStatus)] : [],
            metadata: RevisionMetadata(number: 1, reason: packageFixtureText("Synthetic frozen input"), author: .human(reviewer.id),
                                       createdAt: Self.creation.addingTimeInterval(2 * 86_400)))
        methodology = MethodologyVersion(version: packageFixtureText("TEST-FIXTURE-ONLY"), title: packageFixtureText("Synthetic test methodology"),
            contentReference: packageFixtureText("Synthetic fixture, not a political methodology version 1.0"), changeNote: packageFixtureText("Tests only"))
        criterionEvaluation = CriterionEvaluation(caseEvaluationID: evaluationID, criterionRevisionID: criterionRevisionID,
            category: category, rationale: packageFixtureText("Synthetic criterion assessment"), evidenceLinkIDs: includeEvidence ? [evidence.id] : [],
            confidence: confidence, notVerifiableReasons: reasons, reviewState: .reviewed, review: approved)
        evaluation = CaseEvaluation(id: evaluationID, caseID: caseID, caseRevisionID: snapshot.id,
            cutoff: try .instant(Self.cutoff, role: .evaluationCutoff), methodologyVersionID: methodology.id,
            criterionEvaluationIDs: [criterionEvaluation.id], category: category, rationale: packageFixtureText("Synthetic overall assessment"),
            confidence: confidence, notVerifiableReasons: reasons,
            metadata: RevisionMetadata(number: 1, reason: packageFixtureText("Synthetic assessment"), author: .human(reviewer.id),
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


import PoliticalFactCheckExport
@testable import PoliticalFactCheckPersistence

struct PackageFixture {
    let base: PackageFixtureBase
    let script: ScriptDraft
    let statements: [ScriptStatement]
    let auditEntry: AuditEntry
    let researchTask: ResearchTask
    init() throws {
        base = try PackageFixtureBase(includeAction: true)
        let id = EntityID<ScriptDraft>()
        let review = HumanReview(reviewerID: base.reviewer.id, reviewedAt: PackageFixtureBase.creation.addingTimeInterval(7 * 86400 + 0.1234567))
        statements = [ScriptStatement(scriptDraftID: id, position: 0, text: packageFixtureText("Synthetic approved fact"), kind: .fact,
            excerptIDs: [base.excerpt.id], evidenceLinkIDs: [base.evidence.id], review: review),
            ScriptStatement(scriptDraftID: id, position: 1, text: packageFixtureText("Synthetic approved interpretation"), kind: .interpretation,
                uncertainty: packageFixtureText("Synthetic uncertainty"), review: review)]
        script = ScriptDraft(id: id, caseEvaluationID: base.evaluation.id, version: 2, targetDurationSeconds: 45,
            statementIDs: statements.map { $0.id }, status: .approved, author: .human(base.reviewer.id),
            createdAt: PackageFixtureBase.creation.addingTimeInterval(6 * 86400 + 0.1234567), approval: review)
        auditEntry = AuditEntry(caseID: base.politicalCase.id,
            target: ObjectReference(kind: .script, id: id), operation: packageFixtureText("approveScript"),
            author: .human(base.reviewer.id), occurredAt: review.reviewedAt, reason: packageFixtureText("Synthetic human approval"))
        researchTask = ResearchTask(caseID: base.politicalCase.id,
            goal: packageFixtureText("Synthetic historical task"), author: .human(base.reviewer.id),
            createdAt: PackageFixtureBase.creation)
    }
    func archive() throws -> PortableCaseArchiveV1 {
        var dto = CaseGraphDTO(base.context(scripts: [script], statements: statements))
        dto.cases[0].workflowState = "approved"
        let canonical = try MethodologyV1.version()
        dto.methodologies = [MethodologyVersionDTO(canonical)]
        dto.caseEvaluations[0].methodologyVersionID = StoredID(canonical.id, kind: "MethodologyVersion")
        dto.auditEntries = [AuditEntryDTO(auditEntry)]
        dto.researchTasks = [ResearchTaskDTO(researchTask)]
        return try PortableCaseArchiveV1(dto.domain())
    }
    func context() throws -> DomainContext { try archive().domain() }
    func package() throws -> EditorialPackageContents {
        try EditorialPackage.create(graph: context(), evaluationID: base.evaluation.id, scriptID: script.id,
            exportedAt: PackageFixtureBase.creation.addingTimeInterval(8 * 86400))
    }
}
