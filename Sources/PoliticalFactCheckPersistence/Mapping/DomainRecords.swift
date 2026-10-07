import Foundation
import PoliticalFactCheckCore

struct CaseDTO: Codable, Equatable {
    var id: StoredID
    var title: String
    var promiseID: StoredID
    var currentPromiseRevisionID: StoredID
    var activeCriterionRevisionIDs: [StoredID]
    var currentActionRevisionIDs: [StoredID]
    var workflowState: String
    var createdAt: Date
    var modifiedAt: Date
    init(_ value: PoliticalFactCheckCore.Case) {
        id = StoredID(value.id, kind: "Case")
        title = value.title.value
        promiseID = StoredID(value.promiseID, kind: "Promise")
        currentPromiseRevisionID = StoredID(value.currentPromiseRevisionID, kind: "PromiseRevision")
        activeCriterionRevisionIDs = value.activeCriterionRevisionIDs.map { StoredID($0, kind: "CriterionRevision") }
        currentActionRevisionIDs = value.currentActionRevisionIDs.map { StoredID($0, kind: "ActionRevision") }
        workflowState = write(value.workflowState)
        createdAt = value.createdAt
        modifiedAt = value.modifiedAt
    }
    func domain() throws -> PoliticalFactCheckCore.Case {
        try PoliticalFactCheckCore.Case(
            id: id.domain(Case.self, kind: "Case"),
            title: NonEmptyText(title),
            promiseID: promiseID.domain(Promise.self, kind: "Promise"),
            currentPromiseRevisionID: currentPromiseRevisionID.domain(PromiseRevision.self, kind: "PromiseRevision"),
            activeCriterionRevisionIDs: activeCriterionRevisionIDs.map { try $0.domain(CriterionRevision.self, kind: "CriterionRevision") },
            currentActionRevisionIDs: currentActionRevisionIDs.map { try $0.domain(ActionRevision.self, kind: "ActionRevision") },
            workflowState: readCaseWorkflowState(workflowState),
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

struct PromiseDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var currentRevisionID: StoredID
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.Promise) {
        id = StoredID(value.id, kind: "Promise")
        caseID = StoredID(value.caseID, kind: "Case")
        currentRevisionID = StoredID(value.currentRevisionID, kind: "PromiseRevision")
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.Promise {
        try PoliticalFactCheckCore.Promise(
            id: id.domain(Promise.self, kind: "Promise"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            currentRevisionID: currentRevisionID.domain(PromiseRevision.self, kind: "PromiseRevision"),
            createdAt: createdAt
        )
    }
}

struct PromiseRevisionDTO: Codable, Equatable {
    var id: StoredID
    var promiseID: StoredID
    var quote: AssertedDTO<String>
    var thesis: String
    var statementDate: AssertedDTO<DatedDTO>
    var context: AssertedDTO<String>
    var targetGroup: AssertedDTO<String>
    var conditions: AssertedDTO<[String]>
    var responsibility: AssertedDTO<String>
    var speaker: AssertedDTO<StoredID>
    var party: AssertedDTO<StoredID>
    var topics: [String]
    var metadata: MetadataDTO
    init(_ value: PoliticalFactCheckCore.PromiseRevision) {
        id = StoredID(value.id, kind: "PromiseRevision")
        promiseID = StoredID(value.promiseID, kind: "Promise")
        quote = AssertedDTO(value.quote) { $0.value }
        thesis = value.thesis.value
        statementDate = AssertedDTO(value.statementDate) { DatedDTO($0) }
        context = AssertedDTO(value.context) { $0.value }
        targetGroup = AssertedDTO(value.targetGroup) { $0.value }
        conditions = AssertedDTO(value.conditions) { $0.map { $0.value } }
        responsibility = AssertedDTO(value.responsibility) { $0.value }
        speaker = AssertedDTO(value.speaker) { StoredID($0, kind: "Actor") }
        party = AssertedDTO(value.party) { StoredID($0, kind: "Actor") }
        topics = value.topics.map { $0.value }
        metadata = MetadataDTO(value.metadata)
    }
    func domain() throws -> PoliticalFactCheckCore.PromiseRevision {
        try PoliticalFactCheckCore.PromiseRevision(
            id: id.domain(PromiseRevision.self, kind: "PromiseRevision"),
            promiseID: promiseID.domain(Promise.self, kind: "Promise"),
            quote: quote.domain { try NonEmptyText($0) },
            thesis: NonEmptyText(thesis),
            statementDate: statementDate.domain { try $0.domain() },
            context: context.domain { try NonEmptyText($0) },
            targetGroup: targetGroup.domain { try NonEmptyText($0) },
            conditions: conditions.domain { try $0.map { try NonEmptyText($0) } },
            responsibility: responsibility.domain { try NonEmptyText($0) },
            speaker: speaker.domain { try $0.domain(Actor.self, kind: "Actor") },
            party: party.domain { try $0.domain(Actor.self, kind: "Actor") },
            topics: topics.map { try NonEmptyText($0) },
            metadata: metadata.domain()
        )
    }
}

struct EvaluationCriterionDTO: Codable, Equatable {
    var id: StoredID
    var promiseID: StoredID
    var currentRevisionID: StoredID
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.EvaluationCriterion) {
        id = StoredID(value.id, kind: "EvaluationCriterion")
        promiseID = StoredID(value.promiseID, kind: "Promise")
        currentRevisionID = StoredID(value.currentRevisionID, kind: "CriterionRevision")
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.EvaluationCriterion {
        try PoliticalFactCheckCore.EvaluationCriterion(
            id: id.domain(EvaluationCriterion.self, kind: "EvaluationCriterion"),
            promiseID: promiseID.domain(Promise.self, kind: "Promise"),
            currentRevisionID: currentRevisionID.domain(CriterionRevision.self, kind: "CriterionRevision"),
            createdAt: createdAt
        )
    }
}

struct CriterionRevisionDTO: Codable, Equatable {
    var id: StoredID
    var criterionID: StoredID
    var promiseRevisionID: StoredID
    var goal: String
    var targetGroup: String
    var baseline: FieldDTO<String>
    var deadline: DatedDTO
    var conditions: FieldDTO<[String]>
    var isCore: Bool
    var materialityRule: String
    var weight: Double?
    var weightReason: String?
    var metadata: MetadataDTO
    var state: String
    var confirmation: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.CriterionRevision) {
        id = StoredID(value.id, kind: "CriterionRevision")
        criterionID = StoredID(value.criterionID, kind: "EvaluationCriterion")
        promiseRevisionID = StoredID(value.promiseRevisionID, kind: "PromiseRevision")
        goal = value.goal.value
        targetGroup = value.targetGroup.value
        baseline = FieldDTO(value.baseline) { $0.value }
        deadline = DatedDTO(value.deadline)
        conditions = FieldDTO(value.conditions) { $0.map { $0.value } }
        isCore = value.isCore
        materialityRule = value.materialityRule.value
        weight = value.weight.map { $0 }
        weightReason = value.weightReason.map { $0.value }
        metadata = MetadataDTO(value.metadata)
        state = write(value.state)
        confirmation = value.confirmation.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.CriterionRevision {
        try PoliticalFactCheckCore.CriterionRevision(
            id: id.domain(CriterionRevision.self, kind: "CriterionRevision"),
            criterionID: criterionID.domain(EvaluationCriterion.self, kind: "EvaluationCriterion"),
            promiseRevisionID: promiseRevisionID.domain(PromiseRevision.self, kind: "PromiseRevision"),
            goal: NonEmptyText(goal),
            targetGroup: NonEmptyText(targetGroup),
            baseline: baseline.domain { try NonEmptyText($0) },
            deadline: deadline.domain(),
            conditions: conditions.domain { try $0.map { try NonEmptyText($0) } },
            isCore: isCore,
            materialityRule: NonEmptyText(materialityRule),
            weight: weight.map { try $0 },
            weightReason: weightReason.map { try NonEmptyText($0) },
            metadata: metadata.domain(),
            state: readCriterionRevisionState(state),
            confirmation: confirmation.map { try $0.domain() }
        )
    }
}

struct ActionOrDevelopmentDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var currentRevisionID: StoredID
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.ActionOrDevelopment) {
        id = StoredID(value.id, kind: "ActionOrDevelopment")
        caseID = StoredID(value.caseID, kind: "Case")
        currentRevisionID = StoredID(value.currentRevisionID, kind: "ActionRevision")
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.ActionOrDevelopment {
        try PoliticalFactCheckCore.ActionOrDevelopment(
            id: id.domain(ActionOrDevelopment.self, kind: "ActionOrDevelopment"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            currentRevisionID: currentRevisionID.domain(ActionRevision.self, kind: "ActionRevision"),
            createdAt: createdAt
        )
    }
}

struct ActionRevisionDTO: Codable, Equatable {
    var id: StoredID
    var actionID: StoredID
    var type: String
    var title: String
    var description: AssertedDTO<String>
    var eventDate: AssertedDTO<DatedDTO>
    var validity: DatedDTO?
    var institutionalLevel: String?
    var objectIdentifier: String?
    var proceduralState: String
    var scope: AssertedDTO<String>
    var excerptIDs: [StoredID]
    var participationIDs: [StoredID]
    var metadata: MetadataDTO
    init(_ value: PoliticalFactCheckCore.ActionRevision) {
        id = StoredID(value.id, kind: "ActionRevision")
        actionID = StoredID(value.actionID, kind: "ActionOrDevelopment")
        type = write(value.type)
        title = value.title.value
        description = AssertedDTO(value.description) { $0.value }
        eventDate = AssertedDTO(value.eventDate) { DatedDTO($0) }
        validity = value.validity.map { DatedDTO($0) }
        institutionalLevel = value.institutionalLevel.map { $0.value }
        objectIdentifier = value.objectIdentifier.map { $0.value }
        proceduralState = value.proceduralState.value
        scope = AssertedDTO(value.scope) { $0.value }
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        participationIDs = value.participationIDs.map { StoredID($0, kind: "ActionParticipation") }
        metadata = MetadataDTO(value.metadata)
    }
    func domain() throws -> PoliticalFactCheckCore.ActionRevision {
        try PoliticalFactCheckCore.ActionRevision(
            id: id.domain(ActionRevision.self, kind: "ActionRevision"),
            actionID: actionID.domain(ActionOrDevelopment.self, kind: "ActionOrDevelopment"),
            type: readActionType(type),
            title: NonEmptyText(title),
            description: description.domain { try NonEmptyText($0) },
            eventDate: eventDate.domain { try $0.domain() },
            validity: validity.map { try $0.domain() },
            institutionalLevel: institutionalLevel.map { try NonEmptyText($0) },
            objectIdentifier: objectIdentifier.map { try NonEmptyText($0) },
            proceduralState: NonEmptyText(proceduralState),
            scope: scope.domain { try NonEmptyText($0) },
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            participationIDs: participationIDs.map { try $0.domain(ActionParticipation.self, kind: "ActionParticipation") },
            metadata: metadata.domain()
        )
    }
}

struct ActionParticipationDTO: Codable, Equatable {
    var id: StoredID
    var actionRevisionID: StoredID
    var actorID: StoredID
    var role: String
    var kind: String
    var rationale: String?
    var excerptIDs: [StoredID]
    var verification: String
    var review: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.ActionParticipation) {
        id = StoredID(value.id, kind: "ActionParticipation")
        actionRevisionID = StoredID(value.actionRevisionID, kind: "ActionRevision")
        actorID = StoredID(value.actorID, kind: "Actor")
        role = value.role.value
        kind = write(value.kind)
        rationale = value.rationale.map { $0.value }
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        verification = write(value.verification)
        review = value.review.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.ActionParticipation {
        try PoliticalFactCheckCore.ActionParticipation(
            id: id.domain(ActionParticipation.self, kind: "ActionParticipation"),
            actionRevisionID: actionRevisionID.domain(ActionRevision.self, kind: "ActionRevision"),
            actorID: actorID.domain(Actor.self, kind: "Actor"),
            role: NonEmptyText(role),
            kind: readParticipationKind(kind),
            rationale: rationale.map { try NonEmptyText($0) },
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            verification: readFactVerificationState(verification),
            review: review.map { try $0.domain() }
        )
    }
}

struct EvidenceLinkDTO: Codable, Equatable {
    var id: StoredID
    var criterionRevisionID: StoredID
    var excerptIDs: [StoredID]
    var actionRevisionID: StoredID?
    var relationship: String
    var directness: String
    var rationale: String
    var temporalReference: DatedDTO
    var status: String
    var review: ReviewDTO?
    var metadata: MetadataDTO
    init(_ value: PoliticalFactCheckCore.EvidenceLink) {
        id = StoredID(value.id, kind: "EvidenceLink")
        criterionRevisionID = StoredID(value.criterionRevisionID, kind: "CriterionRevision")
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        actionRevisionID = value.actionRevisionID.map { StoredID($0, kind: "ActionRevision") }
        relationship = write(value.relationship)
        directness = write(value.directness)
        rationale = value.rationale.value
        temporalReference = DatedDTO(value.temporalReference)
        status = write(value.status)
        review = value.review.map { ReviewDTO($0) }
        metadata = MetadataDTO(value.metadata)
    }
    func domain() throws -> PoliticalFactCheckCore.EvidenceLink {
        try PoliticalFactCheckCore.EvidenceLink(
            id: id.domain(EvidenceLink.self, kind: "EvidenceLink"),
            criterionRevisionID: criterionRevisionID.domain(CriterionRevision.self, kind: "CriterionRevision"),
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            actionRevisionID: actionRevisionID.map { try $0.domain(ActionRevision.self, kind: "ActionRevision") },
            relationship: readEvidenceRelationship(relationship),
            directness: readEvidenceDirectness(directness),
            rationale: NonEmptyText(rationale),
            temporalReference: temporalReference.domain(),
            status: readEvidenceLinkStatus(status),
            review: review.map { try $0.domain() },
            metadata: metadata.domain()
        )
    }
}

struct ResearchTaskDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var goal: String
    var criterionRevisionIDs: [StoredID]
    var query: String?
    var status: String
    var result: String?
    var failureKind: String?
    var attemptedAt: Date?
    var nextStep: String?
    var sourceIDs: [StoredID]
    var excerptIDs: [StoredID]
    var author: AuthorshipDTO
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.ResearchTask) {
        id = StoredID(value.id, kind: "ResearchTask")
        caseID = StoredID(value.caseID, kind: "Case")
        goal = value.goal.value
        criterionRevisionIDs = value.criterionRevisionIDs.map { StoredID($0, kind: "CriterionRevision") }
        query = value.query.map { $0 }
        status = write(value.status)
        result = value.result.map { $0 }
        failureKind = value.failureKind.map { $0 }
        attemptedAt = value.attemptedAt.map { $0 }
        nextStep = value.nextStep.map { $0 }
        sourceIDs = value.sourceIDs.map { StoredID($0, kind: "Source") }
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        author = AuthorshipDTO(value.author)
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.ResearchTask {
        try PoliticalFactCheckCore.ResearchTask(
            id: id.domain(ResearchTask.self, kind: "ResearchTask"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            goal: NonEmptyText(goal),
            criterionRevisionIDs: criterionRevisionIDs.map { try $0.domain(CriterionRevision.self, kind: "CriterionRevision") },
            query: query.map { try $0 },
            status: readResearchTaskStatus(status),
            result: result.map { try $0 },
            failureKind: failureKind.map { try $0 },
            attemptedAt: attemptedAt.map { try $0 },
            nextStep: nextStep.map { try $0 },
            sourceIDs: sourceIDs.map { try $0.domain(Source.self, kind: "Source") },
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            author: author.domain(),
            createdAt: createdAt
        )
    }
}

struct AuditEntryDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var target: ReferenceDTO
    var operation: String
    var before: ReferenceDTO?
    var after: ReferenceDTO?
    var author: AuthorshipDTO
    var humanRequesterID: StoredID?
    var occurredAt: Date
    var reason: String
    init(_ value: PoliticalFactCheckCore.AuditEntry) {
        id = StoredID(value.id, kind: "AuditEntry")
        caseID = StoredID(value.caseID, kind: "Case")
        target = ReferenceDTO(value.target)
        operation = value.operation.value
        before = value.before.map { ReferenceDTO($0) }
        after = value.after.map { ReferenceDTO($0) }
        author = AuthorshipDTO(value.author)
        humanRequesterID = value.humanRequesterID.map { StoredID($0, kind: "ReviewerIdentity") }
        occurredAt = value.occurredAt
        reason = value.reason.value
    }
    func domain() throws -> PoliticalFactCheckCore.AuditEntry {
        try PoliticalFactCheckCore.AuditEntry(
            id: id.domain(AuditEntry.self, kind: "AuditEntry"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            target: target.domain(),
            operation: NonEmptyText(operation),
            before: before.map { try $0.domain() },
            after: after.map { try $0.domain() },
            author: author.domain(),
            humanRequesterID: humanRequesterID.map { try $0.domain(ReviewerIdentity.self, kind: "ReviewerIdentity") },
            occurredAt: occurredAt,
            reason: NonEmptyText(reason)
        )
    }
}

struct ScriptDraftDTO: Codable, Equatable {
    var id: StoredID
    var caseEvaluationID: StoredID
    var version: Int
    var targetDurationSeconds: Double
    var statementIDs: [StoredID]
    var status: String
    var author: AuthorshipDTO
    var createdAt: Date
    var approval: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.ScriptDraft) {
        id = StoredID(value.id, kind: "ScriptDraft")
        caseEvaluationID = StoredID(value.caseEvaluationID, kind: "CaseEvaluation")
        version = value.version
        targetDurationSeconds = value.targetDurationSeconds
        statementIDs = value.statementIDs.map { StoredID($0, kind: "ScriptStatement") }
        status = write(value.status)
        author = AuthorshipDTO(value.author)
        createdAt = value.createdAt
        approval = value.approval.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.ScriptDraft {
        try PoliticalFactCheckCore.ScriptDraft(
            id: id.domain(ScriptDraft.self, kind: "ScriptDraft"),
            caseEvaluationID: caseEvaluationID.domain(CaseEvaluation.self, kind: "CaseEvaluation"),
            version: version,
            targetDurationSeconds: targetDurationSeconds,
            statementIDs: statementIDs.map { try $0.domain(ScriptStatement.self, kind: "ScriptStatement") },
            status: readScriptStatus(status),
            author: author.domain(),
            createdAt: createdAt,
            approval: approval.map { try $0.domain() }
        )
    }
}

struct ScriptStatementDTO: Codable, Equatable {
    var id: StoredID
    var scriptDraftID: StoredID
    var position: Int
    var text: String
    var kind: String
    var excerptIDs: [StoredID]
    var evidenceLinkIDs: [StoredID]
    var uncertainty: String?
    var review: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.ScriptStatement) {
        id = StoredID(value.id, kind: "ScriptStatement")
        scriptDraftID = StoredID(value.scriptDraftID, kind: "ScriptDraft")
        position = value.position
        text = value.text.value
        kind = write(value.kind)
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        evidenceLinkIDs = value.evidenceLinkIDs.map { StoredID($0, kind: "EvidenceLink") }
        uncertainty = value.uncertainty.map { $0.value }
        review = value.review.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.ScriptStatement {
        try PoliticalFactCheckCore.ScriptStatement(
            id: id.domain(ScriptStatement.self, kind: "ScriptStatement"),
            scriptDraftID: scriptDraftID.domain(ScriptDraft.self, kind: "ScriptDraft"),
            position: position,
            text: NonEmptyText(text),
            kind: readScriptStatementKind(kind),
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            evidenceLinkIDs: evidenceLinkIDs.map { try $0.domain(EvidenceLink.self, kind: "EvidenceLink") },
            uncertainty: uncertainty.map { try NonEmptyText($0) },
            review: review.map { try $0.domain() }
        )
    }
}

struct CaseRevisionDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var promiseRevisionID: StoredID
    var criteria: [StateDTO]
    var actionRevisionIDs: [StoredID]
    var participations: [StateDTO]
    var sourceVersions: [StateDTO]
    var excerpts: [StateDTO]
    var evidenceLinks: [StateDTO]
    var researchTasks: [StateDTO]
    var metadata: MetadataDTO
    init(_ value: PoliticalFactCheckCore.CaseRevision) {
        id = StoredID(value.id, kind: "CaseRevision")
        caseID = StoredID(value.caseID, kind: "Case")
        promiseRevisionID = StoredID(value.promiseRevisionID, kind: "PromiseRevision")
        criteria = value.criteria.map { StateDTO(id: StoredID($0.id, kind: "CriterionRevision"), state: write($0.state)) }
        actionRevisionIDs = value.actionRevisionIDs.map { StoredID($0, kind: "ActionRevision") }
        participations = value.participations.map { StateDTO(id: StoredID($0.id, kind: "ActionParticipation"), state: write($0.state)) }
        sourceVersions = value.sourceVersions.map { StateDTO(id: StoredID($0.id, kind: "SourceVersion"), state: write($0.state)) }
        excerpts = value.excerpts.map { StateDTO(id: StoredID($0.id, kind: "SourceExcerpt"), state: write($0.state)) }
        evidenceLinks = value.evidenceLinks.map { StateDTO(id: StoredID($0.id, kind: "EvidenceLink"), state: write($0.state)) }
        researchTasks = value.researchTasks.map { StateDTO(id: StoredID($0.id, kind: "ResearchTask"), state: write($0.state)) }
        metadata = MetadataDTO(value.metadata)
    }
    func domain() throws -> PoliticalFactCheckCore.CaseRevision {
        try PoliticalFactCheckCore.CaseRevision(
            id: id.domain(CaseRevision.self, kind: "CaseRevision"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            promiseRevisionID: promiseRevisionID.domain(PromiseRevision.self, kind: "PromiseRevision"),
            criteria: criteria.map { try StateSnapshot(id: try $0.id.domain(CriterionRevision.self, kind: "CriterionRevision"), state: try readCriterionRevisionState($0.state)) },
            actionRevisionIDs: actionRevisionIDs.map { try $0.domain(ActionRevision.self, kind: "ActionRevision") },
            participations: participations.map { try StateSnapshot(id: try $0.id.domain(ActionParticipation.self, kind: "ActionParticipation"), state: try readFactVerificationState($0.state)) },
            sourceVersions: sourceVersions.map { try StateSnapshot(id: try $0.id.domain(SourceVersion.self, kind: "SourceVersion"), state: try readFactVerificationState($0.state)) },
            excerpts: excerpts.map { try StateSnapshot(id: try $0.id.domain(SourceExcerpt.self, kind: "SourceExcerpt"), state: try readExcerptVerificationState($0.state)) },
            evidenceLinks: evidenceLinks.map { try StateSnapshot(id: try $0.id.domain(EvidenceLink.self, kind: "EvidenceLink"), state: try readEvidenceLinkStatus($0.state)) },
            researchTasks: researchTasks.map { try StateSnapshot(id: try $0.id.domain(ResearchTask.self, kind: "ResearchTask"), state: try readResearchTaskStatus($0.state)) },
            metadata: metadata.domain()
        )
    }
}

struct CriterionEvaluationDTO: Codable, Equatable {
    var id: StoredID
    var caseEvaluationID: StoredID
    var criterionRevisionID: StoredID
    var category: String
    var rationale: String
    var evidenceLinkIDs: [StoredID]
    var counterEvidenceLinkIDs: [StoredID]
    var confidence: String
    var uncertainties: [String]
    var notVerifiableReasons: [String]
    var reviewState: String
    var review: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.CriterionEvaluation) {
        id = StoredID(value.id, kind: "CriterionEvaluation")
        caseEvaluationID = StoredID(value.caseEvaluationID, kind: "CaseEvaluation")
        criterionRevisionID = StoredID(value.criterionRevisionID, kind: "CriterionRevision")
        category = write(value.category)
        rationale = value.rationale.value
        evidenceLinkIDs = value.evidenceLinkIDs.map { StoredID($0, kind: "EvidenceLink") }
        counterEvidenceLinkIDs = value.counterEvidenceLinkIDs.map { StoredID($0, kind: "EvidenceLink") }
        confidence = write(value.confidence)
        uncertainties = value.uncertainties.map { $0.value }
        notVerifiableReasons = value.notVerifiableReasons.map { write($0) }
        reviewState = write(value.reviewState)
        review = value.review.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.CriterionEvaluation {
        try PoliticalFactCheckCore.CriterionEvaluation(
            id: id.domain(CriterionEvaluation.self, kind: "CriterionEvaluation"),
            caseEvaluationID: caseEvaluationID.domain(CaseEvaluation.self, kind: "CaseEvaluation"),
            criterionRevisionID: criterionRevisionID.domain(CriterionRevision.self, kind: "CriterionRevision"),
            category: readEvaluationCategory(category),
            rationale: NonEmptyText(rationale),
            evidenceLinkIDs: evidenceLinkIDs.map { try $0.domain(EvidenceLink.self, kind: "EvidenceLink") },
            counterEvidenceLinkIDs: counterEvidenceLinkIDs.map { try $0.domain(EvidenceLink.self, kind: "EvidenceLink") },
            confidence: readEvidenceConfidence(confidence),
            uncertainties: uncertainties.map { try NonEmptyText($0) },
            notVerifiableReasons: notVerifiableReasons.map { try readNotVerifiableReason($0) },
            reviewState: readHumanReviewState(reviewState),
            review: review.map { try $0.domain() }
        )
    }
}

struct CaseEvaluationDTO: Codable, Equatable {
    var id: StoredID
    var caseID: StoredID
    var caseRevisionID: StoredID
    var cutoff: DatedDTO
    var methodologyVersionID: StoredID
    var criterionEvaluationIDs: [StoredID]
    var category: String
    var rationale: String
    var confidence: String
    var facts: [String]
    var interpretations: [String]
    var uncertainties: [String]
    var notVerifiableReasons: [String]
    var metadata: MetadataDTO
    var status: String
    var approval: ReviewDTO?
    var reviewReason: String?
    var replacesEvaluationID: StoredID?
    init(_ value: PoliticalFactCheckCore.CaseEvaluation) {
        id = StoredID(value.id, kind: "CaseEvaluation")
        caseID = StoredID(value.caseID, kind: "Case")
        caseRevisionID = StoredID(value.caseRevisionID, kind: "CaseRevision")
        cutoff = DatedDTO(value.cutoff)
        methodologyVersionID = StoredID(value.methodologyVersionID, kind: "MethodologyVersion")
        criterionEvaluationIDs = value.criterionEvaluationIDs.map { StoredID($0, kind: "CriterionEvaluation") }
        category = write(value.category)
        rationale = value.rationale.value
        confidence = write(value.confidence)
        facts = value.facts.map { $0.value }
        interpretations = value.interpretations.map { $0.value }
        uncertainties = value.uncertainties.map { $0.value }
        notVerifiableReasons = value.notVerifiableReasons.map { write($0) }
        metadata = MetadataDTO(value.metadata)
        status = write(value.status)
        approval = value.approval.map { ReviewDTO($0) }
        reviewReason = value.reviewReason.map { $0.value }
        replacesEvaluationID = value.replacesEvaluationID.map { StoredID($0, kind: "CaseEvaluation") }
    }
    func domain() throws -> PoliticalFactCheckCore.CaseEvaluation {
        try PoliticalFactCheckCore.CaseEvaluation(
            id: id.domain(CaseEvaluation.self, kind: "CaseEvaluation"),
            caseID: caseID.domain(Case.self, kind: "Case"),
            caseRevisionID: caseRevisionID.domain(CaseRevision.self, kind: "CaseRevision"),
            cutoff: cutoff.domain(),
            methodologyVersionID: methodologyVersionID.domain(MethodologyVersion.self, kind: "MethodologyVersion"),
            criterionEvaluationIDs: criterionEvaluationIDs.map { try $0.domain(CriterionEvaluation.self, kind: "CriterionEvaluation") },
            category: readEvaluationCategory(category),
            rationale: NonEmptyText(rationale),
            confidence: readEvidenceConfidence(confidence),
            facts: facts.map { try NonEmptyText($0) },
            interpretations: interpretations.map { try NonEmptyText($0) },
            uncertainties: uncertainties.map { try NonEmptyText($0) },
            notVerifiableReasons: notVerifiableReasons.map { try readNotVerifiableReason($0) },
            metadata: metadata.domain(),
            status: readEvaluationStatus(status),
            approval: approval.map { try $0.domain() },
            reviewReason: reviewReason.map { try NonEmptyText($0) },
            replacesEvaluationID: replacesEvaluationID.map { try $0.domain(CaseEvaluation.self, kind: "CaseEvaluation") }
        )
    }
}

struct MethodologyVersionDTO: Codable, Equatable {
    var id: StoredID
    var version: String
    var title: String
    var contentReference: String
    var hash: String?
    var changeNote: String
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.MethodologyVersion) {
        id = StoredID(value.id, kind: "MethodologyVersion")
        version = value.version.value
        title = value.title.value
        contentReference = value.contentReference.value
        hash = value.hash.map { $0.sha256 }
        changeNote = value.changeNote.value
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.MethodologyVersion {
        try PoliticalFactCheckCore.MethodologyVersion(
            id: id.domain(MethodologyVersion.self, kind: "MethodologyVersion"),
            version: NonEmptyText(version),
            title: NonEmptyText(title),
            contentReference: NonEmptyText(contentReference),
            hash: hash.map { try ContentHash(sha256: $0) },
            changeNote: NonEmptyText(changeNote),
            createdAt: createdAt
        )
    }
}

struct ReviewerIdentityDTO: Codable, Equatable {
    var id: StoredID
    var displayName: String
    var note: String?
    init(_ value: PoliticalFactCheckCore.ReviewerIdentity) {
        id = StoredID(value.id, kind: "ReviewerIdentity")
        displayName = value.displayName.value
        note = value.note.map { $0 }
    }
    func domain() throws -> PoliticalFactCheckCore.ReviewerIdentity {
        try PoliticalFactCheckCore.ReviewerIdentity(
            id: id.domain(ReviewerIdentity.self, kind: "ReviewerIdentity"),
            displayName: NonEmptyText(displayName),
            note: note.map { try $0 }
        )
    }
}

struct ActorDTO: Codable, Equatable {
    var id: StoredID
    var name: String
    var type: String
    var description: String?
    var affiliationIDs: [StoredID]
    init(_ value: PoliticalFactCheckCore.Actor) {
        id = StoredID(value.id, kind: "Actor")
        name = value.name.value
        type = write(value.type)
        description = value.description.map { $0 }
        affiliationIDs = value.affiliationIDs.map { StoredID($0, kind: "ActorAffiliation") }
    }
    func domain() throws -> PoliticalFactCheckCore.Actor {
        try PoliticalFactCheckCore.Actor(
            id: id.domain(Actor.self, kind: "Actor"),
            name: NonEmptyText(name),
            type: readActorType(type),
            description: description.map { try $0 },
            affiliationIDs: affiliationIDs.map { try $0.domain(ActorAffiliation.self, kind: "ActorAffiliation") }
        )
    }
}

struct ActorAffiliationDTO: Codable, Equatable {
    var id: StoredID
    var actorID: StoredID
    var associatedActorID: StoredID?
    var role: String
    var validity: DatedDTO
    var verification: String
    var excerptIDs: [StoredID]
    var review: ReviewDTO?
    init(_ value: PoliticalFactCheckCore.ActorAffiliation) {
        id = StoredID(value.id, kind: "ActorAffiliation")
        actorID = StoredID(value.actorID, kind: "Actor")
        associatedActorID = value.associatedActorID.map { StoredID($0, kind: "Actor") }
        role = value.role.value
        validity = DatedDTO(value.validity)
        verification = write(value.verification)
        excerptIDs = value.excerptIDs.map { StoredID($0, kind: "SourceExcerpt") }
        review = value.review.map { ReviewDTO($0) }
    }
    func domain() throws -> PoliticalFactCheckCore.ActorAffiliation {
        try PoliticalFactCheckCore.ActorAffiliation(
            id: id.domain(ActorAffiliation.self, kind: "ActorAffiliation"),
            actorID: actorID.domain(Actor.self, kind: "Actor"),
            associatedActorID: associatedActorID.map { try $0.domain(Actor.self, kind: "Actor") },
            role: NonEmptyText(role),
            validity: validity.domain(),
            verification: readFactVerificationState(verification),
            excerptIDs: excerptIDs.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            review: review.map { try $0.domain() }
        )
    }
}

struct SourceDTO: Codable, Equatable {
    var id: StoredID
    var canonicalURL: String?
    var documentIdentifier: String?
    var originSourceID: StoredID?
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.Source) {
        id = StoredID(value.id, kind: "Source")
        canonicalURL = value.canonicalURL.map { $0.absoluteString }
        documentIdentifier = value.documentIdentifier.map { $0.value }
        originSourceID = value.originSourceID.map { StoredID($0, kind: "Source") }
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.Source {
        try PoliticalFactCheckCore.Source(
            id: id.domain(Source.self, kind: "Source"),
            canonicalURL: canonicalURL.map { try readURL($0) },
            documentIdentifier: documentIdentifier.map { try NonEmptyText($0) },
            originSourceID: originSourceID.map { try $0.domain(Source.self, kind: "Source") },
            createdAt: createdAt
        )
    }
}

struct SourceVersionDTO: Codable, Equatable {
    var id: StoredID
    var sourceID: StoredID
    var kind: String
    var requestedURL: String?
    var finalURL: String?
    var archiveURL: String?
    var title: String?
    var publisher: String?
    var author: String?
    var publicationDate: DatedDTO
    var retrievedAt: DatedDTO
    var eventDate: DatedDTO?
    var validity: DatedDTO?
    var availability: String
    var verification: String
    var review: ReviewDTO?
    var contentType: String
    var language: String
    var localCopyReference: String?
    var hash: String?
    init(_ value: PoliticalFactCheckCore.SourceVersion) {
        id = StoredID(value.id, kind: "SourceVersion")
        sourceID = StoredID(value.sourceID, kind: "Source")
        kind = write(value.kind)
        requestedURL = value.requestedURL.map { $0.absoluteString }
        finalURL = value.finalURL.map { $0.absoluteString }
        archiveURL = value.archiveURL.map { $0.absoluteString }
        title = value.title.map { $0.value }
        publisher = value.publisher.map { $0.value }
        author = value.author.map { $0.value }
        publicationDate = DatedDTO(value.publicationDate)
        retrievedAt = DatedDTO(value.retrievedAt)
        eventDate = value.eventDate.map { DatedDTO($0) }
        validity = value.validity.map { DatedDTO($0) }
        availability = write(value.availability)
        verification = write(value.verification)
        review = value.review.map { ReviewDTO($0) }
        contentType = value.contentType.value
        language = value.language.value
        localCopyReference = value.localCopyReference.map { $0.value }
        hash = value.hash.map { $0.sha256 }
    }
    func domain() throws -> PoliticalFactCheckCore.SourceVersion {
        try PoliticalFactCheckCore.SourceVersion(
            id: id.domain(SourceVersion.self, kind: "SourceVersion"),
            sourceID: sourceID.domain(Source.self, kind: "Source"),
            kind: readSourceVersionKind(kind),
            requestedURL: requestedURL.map { try readURL($0) },
            finalURL: finalURL.map { try readURL($0) },
            archiveURL: archiveURL.map { try readURL($0) },
            title: title.map { try NonEmptyText($0) },
            publisher: publisher.map { try NonEmptyText($0) },
            author: author.map { try NonEmptyText($0) },
            publicationDate: publicationDate.domain(),
            retrievedAt: retrievedAt.domain(),
            eventDate: eventDate.map { try $0.domain() },
            validity: validity.map { try $0.domain() },
            availability: readSourceAvailability(availability),
            verification: readFactVerificationState(verification),
            review: review.map { try $0.domain() },
            contentType: NonEmptyText(contentType),
            language: NonEmptyText(language),
            localCopyReference: localCopyReference.map { try NonEmptyText($0) },
            hash: hash.map { try ContentHash(sha256: $0) }
        )
    }
}

struct SourceExcerptDTO: Codable, Equatable {
    var id: StoredID
    var sourceVersionID: StoredID
    var locator: String
    var text: String
    var context: String
    var language: String
    var translationOfExcerptID: StoredID?
    var provenance: String
    var state: String
    var review: ReviewDTO?
    var createdAt: Date
    init(_ value: PoliticalFactCheckCore.SourceExcerpt) {
        id = StoredID(value.id, kind: "SourceExcerpt")
        sourceVersionID = StoredID(value.sourceVersionID, kind: "SourceVersion")
        locator = value.locator.value
        text = value.text.value
        context = value.context.value
        language = value.language.value
        translationOfExcerptID = value.translationOfExcerptID.map { StoredID($0, kind: "SourceExcerpt") }
        provenance = write(value.provenance)
        state = write(value.state)
        review = value.review.map { ReviewDTO($0) }
        createdAt = value.createdAt
    }
    func domain() throws -> PoliticalFactCheckCore.SourceExcerpt {
        try PoliticalFactCheckCore.SourceExcerpt(
            id: id.domain(SourceExcerpt.self, kind: "SourceExcerpt"),
            sourceVersionID: sourceVersionID.domain(SourceVersion.self, kind: "SourceVersion"),
            locator: NonEmptyText(locator),
            text: NonEmptyText(text),
            context: NonEmptyText(context),
            language: NonEmptyText(language),
            translationOfExcerptID: translationOfExcerptID.map { try $0.domain(SourceExcerpt.self, kind: "SourceExcerpt") },
            provenance: readProvenance(provenance),
            state: readExcerptVerificationState(state),
            review: review.map { try $0.domain() },
            createdAt: createdAt
        )
    }
}
