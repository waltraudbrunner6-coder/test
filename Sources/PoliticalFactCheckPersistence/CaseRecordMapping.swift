import Foundation
import SwiftData
import PoliticalFactCheckCore

extension LocalCaseStore {
    func readCase(_ id: UUID, in context: ModelContext) throws -> DomainContext? {
        let roots = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>()).filter { $0.id == id }
        guard roots.count <= 1 else { throw PersistenceError.duplicateID(kind: "Case", id: id) }
        guard let root = roots.first else { return nil }
        try checkFormat(root.formatVersion)
        let value = try PayloadCodec.decode(CaseDTO.self, from: root.payload)
        guard value.id.value == id else { throw PersistenceError.identityMismatch(kind: "Case", id: id) }
        let manifest = try PayloadCodec.decode(CaseManifest.self, from: root.manifest)
        let politicalCase = try domainChange { try value.domain() }
        let reviewersRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ReviewerIdentityRecord>())
        let reviewers = try manifest.reviewers.map { ref -> ReviewerIdentity in
            _ = try ref.domain(ReviewerIdentity.self, kind: "ReviewerIdentity")
            let matches = reviewersRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ReviewerIdentity", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ReviewerIdentity", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ReviewerIdentityDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ReviewerIdentity", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.reviewers).count == manifest.reviewers.count else {
            throw PersistenceError.duplicateID(kind: "ReviewerIdentity", id: manifest.reviewers.first!.value)
        }
        let actorsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorRecord>())
        let actors = try manifest.actors.map { ref -> Actor in
            _ = try ref.domain(Actor.self, kind: "Actor")
            let matches = actorsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Actor", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "Actor", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ActorDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "Actor", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.actors).count == manifest.actors.count else {
            throw PersistenceError.duplicateID(kind: "Actor", id: manifest.actors.first!.value)
        }
        let affiliationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorAffiliationRecord>())
        let affiliations = try manifest.affiliations.map { ref -> ActorAffiliation in
            _ = try ref.domain(ActorAffiliation.self, kind: "ActorAffiliation")
            let matches = affiliationsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActorAffiliation", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ActorAffiliation", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ActorAffiliationDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ActorAffiliation", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.affiliations).count == manifest.affiliations.count else {
            throw PersistenceError.duplicateID(kind: "ActorAffiliation", id: manifest.affiliations.first!.value)
        }
        let promisesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRecord>())
        let promises = try manifest.promises.map { ref -> Promise in
            _ = try ref.domain(Promise.self, kind: "Promise")
            let matches = promisesRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Promise", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "Promise", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(PromiseDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "Promise", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.promises).count == manifest.promises.count else {
            throw PersistenceError.duplicateID(kind: "Promise", id: manifest.promises.first!.value)
        }
        let promiseRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRevisionRecord>())
        let promiseRevisions = try manifest.promiseRevisions.map { ref -> PromiseRevision in
            _ = try ref.domain(PromiseRevision.self, kind: "PromiseRevision")
            let matches = promiseRevisionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "PromiseRevision", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "PromiseRevision", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(PromiseRevisionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "PromiseRevision", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.promiseRevisions).count == manifest.promiseRevisions.count else {
            throw PersistenceError.duplicateID(kind: "PromiseRevision", id: manifest.promiseRevisions.first!.value)
        }
        let criteriaRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvaluationCriterionRecord>())
        let criteria = try manifest.criteria.map { ref -> EvaluationCriterion in
            _ = try ref.domain(EvaluationCriterion.self, kind: "EvaluationCriterion")
            let matches = criteriaRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "EvaluationCriterion", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "EvaluationCriterion", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(EvaluationCriterionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "EvaluationCriterion", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.criteria).count == manifest.criteria.count else {
            throw PersistenceError.duplicateID(kind: "EvaluationCriterion", id: manifest.criteria.first!.value)
        }
        let criterionRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionRevisionRecord>())
        let criterionRevisions = try manifest.criterionRevisions.map { ref -> CriterionRevision in
            _ = try ref.domain(CriterionRevision.self, kind: "CriterionRevision")
            let matches = criterionRevisionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CriterionRevision", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "CriterionRevision", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(CriterionRevisionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "CriterionRevision", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.criterionRevisions).count == manifest.criterionRevisions.count else {
            throw PersistenceError.duplicateID(kind: "CriterionRevision", id: manifest.criterionRevisions.first!.value)
        }
        let sourcesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceRecord>())
        let sources = try manifest.sources.map { ref -> Source in
            _ = try ref.domain(Source.self, kind: "Source")
            let matches = sourcesRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Source", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "Source", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(SourceDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "Source", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.sources).count == manifest.sources.count else {
            throw PersistenceError.duplicateID(kind: "Source", id: manifest.sources.first!.value)
        }
        let sourceVersionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceVersionRecord>())
        let sourceVersions = try manifest.sourceVersions.map { ref -> SourceVersion in
            _ = try ref.domain(SourceVersion.self, kind: "SourceVersion")
            let matches = sourceVersionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "SourceVersion", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "SourceVersion", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(SourceVersionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "SourceVersion", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.sourceVersions).count == manifest.sourceVersions.count else {
            throw PersistenceError.duplicateID(kind: "SourceVersion", id: manifest.sourceVersions.first!.value)
        }
        let excerptsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>())
        let excerpts = try manifest.excerpts.map { ref -> SourceExcerpt in
            _ = try ref.domain(SourceExcerpt.self, kind: "SourceExcerpt")
            let matches = excerptsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "SourceExcerpt", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "SourceExcerpt", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(SourceExcerptDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "SourceExcerpt", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.excerpts).count == manifest.excerpts.count else {
            throw PersistenceError.duplicateID(kind: "SourceExcerpt", id: manifest.excerpts.first!.value)
        }
        let actionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionOrDevelopmentRecord>())
        let actions = try manifest.actions.map { ref -> ActionOrDevelopment in
            _ = try ref.domain(ActionOrDevelopment.self, kind: "ActionOrDevelopment")
            let matches = actionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionOrDevelopment", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ActionOrDevelopment", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ActionOrDevelopmentDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ActionOrDevelopment", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.actions).count == manifest.actions.count else {
            throw PersistenceError.duplicateID(kind: "ActionOrDevelopment", id: manifest.actions.first!.value)
        }
        let actionRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionRevisionRecord>())
        let actionRevisions = try manifest.actionRevisions.map { ref -> ActionRevision in
            _ = try ref.domain(ActionRevision.self, kind: "ActionRevision")
            let matches = actionRevisionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionRevision", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ActionRevision", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ActionRevisionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ActionRevision", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.actionRevisions).count == manifest.actionRevisions.count else {
            throw PersistenceError.duplicateID(kind: "ActionRevision", id: manifest.actionRevisions.first!.value)
        }
        let participationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionParticipationRecord>())
        let participations = try manifest.participations.map { ref -> ActionParticipation in
            _ = try ref.domain(ActionParticipation.self, kind: "ActionParticipation")
            let matches = participationsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionParticipation", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ActionParticipation", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ActionParticipationDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ActionParticipation", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.participations).count == manifest.participations.count else {
            throw PersistenceError.duplicateID(kind: "ActionParticipation", id: manifest.participations.first!.value)
        }
        let evidenceLinksRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvidenceLinkRecord>())
        let evidenceLinks = try manifest.evidenceLinks.map { ref -> EvidenceLink in
            _ = try ref.domain(EvidenceLink.self, kind: "EvidenceLink")
            let matches = evidenceLinksRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "EvidenceLink", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "EvidenceLink", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(EvidenceLinkDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "EvidenceLink", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.evidenceLinks).count == manifest.evidenceLinks.count else {
            throw PersistenceError.duplicateID(kind: "EvidenceLink", id: manifest.evidenceLinks.first!.value)
        }
        let caseRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRevisionRecord>())
        let caseRevisions = try manifest.caseRevisions.map { ref -> CaseRevision in
            _ = try ref.domain(CaseRevision.self, kind: "CaseRevision")
            let matches = caseRevisionsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CaseRevision", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "CaseRevision", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(CaseRevisionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "CaseRevision", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.caseRevisions).count == manifest.caseRevisions.count else {
            throw PersistenceError.duplicateID(kind: "CaseRevision", id: manifest.caseRevisions.first!.value)
        }
        let criterionEvaluationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionEvaluationRecord>())
        let criterionEvaluations = try manifest.criterionEvaluations.map { ref -> CriterionEvaluation in
            _ = try ref.domain(CriterionEvaluation.self, kind: "CriterionEvaluation")
            let matches = criterionEvaluationsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CriterionEvaluation", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "CriterionEvaluation", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(CriterionEvaluationDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "CriterionEvaluation", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.criterionEvaluations).count == manifest.criterionEvaluations.count else {
            throw PersistenceError.duplicateID(kind: "CriterionEvaluation", id: manifest.criterionEvaluations.first!.value)
        }
        let caseEvaluationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseEvaluationRecord>())
        let caseEvaluations = try manifest.caseEvaluations.map { ref -> CaseEvaluation in
            _ = try ref.domain(CaseEvaluation.self, kind: "CaseEvaluation")
            let matches = caseEvaluationsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CaseEvaluation", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "CaseEvaluation", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(CaseEvaluationDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "CaseEvaluation", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.caseEvaluations).count == manifest.caseEvaluations.count else {
            throw PersistenceError.duplicateID(kind: "CaseEvaluation", id: manifest.caseEvaluations.first!.value)
        }
        let methodologiesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>())
        let methodologies = try manifest.methodologies.map { ref -> MethodologyVersion in
            _ = try ref.domain(MethodologyVersion.self, kind: "MethodologyVersion")
            let matches = methodologiesRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "MethodologyVersion", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "MethodologyVersion", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(MethodologyVersionDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "MethodologyVersion", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.methodologies).count == manifest.methodologies.count else {
            throw PersistenceError.duplicateID(kind: "MethodologyVersion", id: manifest.methodologies.first!.value)
        }
        let researchTasksRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ResearchTaskRecord>())
        let researchTasks = try manifest.researchTasks.map { ref -> ResearchTask in
            _ = try ref.domain(ResearchTask.self, kind: "ResearchTask")
            let matches = researchTasksRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ResearchTask", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ResearchTask", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ResearchTaskDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ResearchTask", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.researchTasks).count == manifest.researchTasks.count else {
            throw PersistenceError.duplicateID(kind: "ResearchTask", id: manifest.researchTasks.first!.value)
        }
        let auditEntriesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.AuditEntryRecord>())
        let auditEntries = try manifest.auditEntries.map { ref -> AuditEntry in
            _ = try ref.domain(AuditEntry.self, kind: "AuditEntry")
            let matches = auditEntriesRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "AuditEntry", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "AuditEntry", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(AuditEntryDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "AuditEntry", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.auditEntries).count == manifest.auditEntries.count else {
            throw PersistenceError.duplicateID(kind: "AuditEntry", id: manifest.auditEntries.first!.value)
        }
        let scriptsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptDraftRecord>())
        let scripts = try manifest.scripts.map { ref -> ScriptDraft in
            _ = try ref.domain(ScriptDraft.self, kind: "ScriptDraft")
            let matches = scriptsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ScriptDraft", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ScriptDraft", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ScriptDraftDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ScriptDraft", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.scripts).count == manifest.scripts.count else {
            throw PersistenceError.duplicateID(kind: "ScriptDraft", id: manifest.scripts.first!.value)
        }
        let statementsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptStatementRecord>())
        let statements = try manifest.statements.map { ref -> ScriptStatement in
            _ = try ref.domain(ScriptStatement.self, kind: "ScriptStatement")
            let matches = statementsRows.filter { $0.id == ref.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ScriptStatement", id: ref.value) }
            guard let row = matches.first else { throw PersistenceError.missingEntity(kind: "ScriptStatement", id: ref.value) }
            try checkFormat(row.formatVersion)
            let dto = try PayloadCodec.decode(ScriptStatementDTO.self, from: row.payload)
            guard dto.id == ref else { throw PersistenceError.identityMismatch(kind: "ScriptStatement", id: ref.value) }
            return try domainChange { try dto.domain() }
        }
        guard Set(manifest.statements).count == manifest.statements.count else {
            throw PersistenceError.duplicateID(kind: "ScriptStatement", id: manifest.statements.first!.value)
        }
        let graph = DomainContext(
            reviewers: reviewers,
            cases: [politicalCase],
            actors: actors,
            affiliations: affiliations,
            promises: promises,
            promiseRevisions: promiseRevisions,
            criteria: criteria,
            criterionRevisions: criterionRevisions,
            sources: sources,
            sourceVersions: sourceVersions,
            excerpts: excerpts,
            actions: actions,
            actionRevisions: actionRevisions,
            participations: participations,
            evidenceLinks: evidenceLinks,
            caseRevisions: caseRevisions,
            criterionEvaluations: criterionEvaluations,
            caseEvaluations: caseEvaluations,
            methodologies: methodologies,
            researchTasks: researchTasks,
            auditEntries: auditEntries,
            scripts: scripts,
            statements: statements
        )
        try validateDomain(graph)
        return graph
    }

    func writeCase(_ graph: DomainContext, in context: ModelContext) throws {
        try validateDomain(graph)
        let dto = CaseGraphDTO(graph)
        let manifest = CaseManifest(dto)
        let root = graph.cases[0]
        let previous = try readCase(root.id.rawValue, in: context)
        if let previous = previous { try validateReviewUpdates(from: previous, to: graph) }
        let previousManifest = previous.map { CaseManifest(CaseGraphDTO($0)) }
        if let previousManifest = previousManifest { try manifest.retaining(previousManifest) }
        let reviewersRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ReviewerIdentityRecord>())
        for value in dto.reviewers {
            let matches = reviewersRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ReviewerIdentity", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ReviewerIdentityDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ReviewerIdentity", id: row.id) }
                if previousManifest?.reviewers.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ReviewerIdentity", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ReviewerIdentityRecord(id: value.id.value, payload: payload))
            }
        }
        let casesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
        for value in dto.cases {
            let matches = casesRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Case", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(CaseDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "Case", id: row.id) }
                if previous == nil && old != value { throw PersistenceError.duplicateID(kind: "Case", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
                row.manifest = try PayloadCodec.encode(manifest)
            } else {
                context.insert(PersistenceSchemaV1.CaseRecord(id: value.id.value, payload: payload, manifest: try PayloadCodec.encode(manifest)))
            }
        }
        let actorsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorRecord>())
        for value in dto.actors {
            let matches = actorsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Actor", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ActorDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "Actor", id: row.id) }
                if previousManifest?.actors.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "Actor", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ActorRecord(id: value.id.value, payload: payload))
            }
        }
        let affiliationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorAffiliationRecord>())
        for value in dto.affiliations {
            let matches = affiliationsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActorAffiliation", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ActorAffiliationDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ActorAffiliation", id: row.id) }
                if previousManifest?.affiliations.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ActorAffiliation", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ActorAffiliationRecord(id: value.id.value, payload: payload))
            }
        }
        let promisesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRecord>())
        for value in dto.promises {
            let matches = promisesRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Promise", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(PromiseDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "Promise", id: row.id) }
                if previousManifest?.promises.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "Promise", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.PromiseRecord(id: value.id.value, payload: payload))
            }
        }
        let promiseRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRevisionRecord>())
        for value in dto.promiseRevisions {
            let matches = promiseRevisionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "PromiseRevision", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(PromiseRevisionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "PromiseRevision", id: row.id) }
                if previousManifest?.promiseRevisions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "PromiseRevision", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.PromiseRevisionRecord(id: value.id.value, payload: payload))
            }
        }
        let criteriaRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvaluationCriterionRecord>())
        for value in dto.criteria {
            let matches = criteriaRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "EvaluationCriterion", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(EvaluationCriterionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "EvaluationCriterion", id: row.id) }
                if previousManifest?.criteria.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "EvaluationCriterion", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.EvaluationCriterionRecord(id: value.id.value, payload: payload))
            }
        }
        let criterionRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionRevisionRecord>())
        for value in dto.criterionRevisions {
            let matches = criterionRevisionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CriterionRevision", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(CriterionRevisionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "CriterionRevision", id: row.id) }
                if previousManifest?.criterionRevisions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "CriterionRevision", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.CriterionRevisionRecord(id: value.id.value, payload: payload))
            }
        }
        let sourcesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceRecord>())
        for value in dto.sources {
            let matches = sourcesRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "Source", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(SourceDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "Source", id: row.id) }
                if previousManifest?.sources.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "Source", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.SourceRecord(id: value.id.value, payload: payload))
            }
        }
        let sourceVersionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceVersionRecord>())
        for value in dto.sourceVersions {
            let matches = sourceVersionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "SourceVersion", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(SourceVersionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "SourceVersion", id: row.id) }
                if previousManifest?.sourceVersions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "SourceVersion", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.SourceVersionRecord(id: value.id.value, payload: payload))
            }
        }
        let excerptsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>())
        for value in dto.excerpts {
            let matches = excerptsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "SourceExcerpt", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(SourceExcerptDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "SourceExcerpt", id: row.id) }
                if previousManifest?.excerpts.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "SourceExcerpt", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.SourceExcerptRecord(id: value.id.value, payload: payload))
            }
        }
        let actionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionOrDevelopmentRecord>())
        for value in dto.actions {
            let matches = actionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionOrDevelopment", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ActionOrDevelopmentDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ActionOrDevelopment", id: row.id) }
                if previousManifest?.actions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ActionOrDevelopment", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ActionOrDevelopmentRecord(id: value.id.value, payload: payload))
            }
        }
        let actionRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionRevisionRecord>())
        for value in dto.actionRevisions {
            let matches = actionRevisionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionRevision", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ActionRevisionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ActionRevision", id: row.id) }
                if previousManifest?.actionRevisions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ActionRevision", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ActionRevisionRecord(id: value.id.value, payload: payload))
            }
        }
        let participationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionParticipationRecord>())
        for value in dto.participations {
            let matches = participationsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ActionParticipation", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ActionParticipationDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ActionParticipation", id: row.id) }
                if previousManifest?.participations.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ActionParticipation", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ActionParticipationRecord(id: value.id.value, payload: payload))
            }
        }
        let evidenceLinksRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvidenceLinkRecord>())
        for value in dto.evidenceLinks {
            let matches = evidenceLinksRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "EvidenceLink", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(EvidenceLinkDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "EvidenceLink", id: row.id) }
                if previousManifest?.evidenceLinks.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "EvidenceLink", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.EvidenceLinkRecord(id: value.id.value, payload: payload))
            }
        }
        let caseRevisionsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRevisionRecord>())
        for value in dto.caseRevisions {
            let matches = caseRevisionsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CaseRevision", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(CaseRevisionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "CaseRevision", id: row.id) }
                if previousManifest?.caseRevisions.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "CaseRevision", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.CaseRevisionRecord(id: value.id.value, payload: payload))
            }
        }
        let criterionEvaluationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionEvaluationRecord>())
        for value in dto.criterionEvaluations {
            let matches = criterionEvaluationsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CriterionEvaluation", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(CriterionEvaluationDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "CriterionEvaluation", id: row.id) }
                if previousManifest?.criterionEvaluations.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "CriterionEvaluation", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.CriterionEvaluationRecord(id: value.id.value, payload: payload))
            }
        }
        let caseEvaluationsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseEvaluationRecord>())
        for value in dto.caseEvaluations {
            let matches = caseEvaluationsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "CaseEvaluation", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(CaseEvaluationDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "CaseEvaluation", id: row.id) }
                if previousManifest?.caseEvaluations.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "CaseEvaluation", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.CaseEvaluationRecord(id: value.id.value, payload: payload))
            }
        }
        let methodologiesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>())
        for value in dto.methodologies {
            let matches = methodologiesRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "MethodologyVersion", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(MethodologyVersionDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "MethodologyVersion", id: row.id) }
                if previousManifest?.methodologies.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "MethodologyVersion", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.MethodologyVersionRecord(id: value.id.value, payload: payload))
            }
        }
        let researchTasksRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ResearchTaskRecord>())
        for value in dto.researchTasks {
            let matches = researchTasksRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ResearchTask", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ResearchTaskDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ResearchTask", id: row.id) }
                if previousManifest?.researchTasks.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ResearchTask", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ResearchTaskRecord(id: value.id.value, payload: payload))
            }
        }
        let auditEntriesRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.AuditEntryRecord>())
        for value in dto.auditEntries {
            let matches = auditEntriesRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "AuditEntry", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(AuditEntryDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "AuditEntry", id: row.id) }
                if previousManifest?.auditEntries.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "AuditEntry", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.AuditEntryRecord(id: value.id.value, payload: payload))
            }
        }
        let scriptsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptDraftRecord>())
        for value in dto.scripts {
            let matches = scriptsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ScriptDraft", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ScriptDraftDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ScriptDraft", id: row.id) }
                if previousManifest?.scripts.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ScriptDraft", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ScriptDraftRecord(id: value.id.value, payload: payload))
            }
        }
        let statementsRows = try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptStatementRecord>())
        for value in dto.statements {
            let matches = statementsRows.filter { $0.id == value.id.value }
            guard matches.count <= 1 else { throw PersistenceError.duplicateID(kind: "ScriptStatement", id: value.id.value) }
            let payload = try PayloadCodec.encode(value)
            if let row = matches.first {
                try checkFormat(row.formatVersion)
                let old = try PayloadCodec.decode(ScriptStatementDTO.self, from: row.payload)
                guard old.id.value == row.id else { throw PersistenceError.identityMismatch(kind: "ScriptStatement", id: row.id) }
                if previousManifest?.statements.contains(value.id) != true && old != value { throw PersistenceError.duplicateID(kind: "ScriptStatement", id: value.id.value) }
                try domainChange { try checkReplacement(old.domain(), value.domain()) }
                row.payload = payload
            } else {
                context.insert(PersistenceSchemaV1.ScriptStatementRecord(id: value.id.value, payload: payload))
            }
        }
    }

    func removeDraft(_ id: UUID, in context: ModelContext) throws {
        guard let graph = try readCase(id, in: context) else { throw PersistenceError.missingEntity(kind: "Case", id: id) }
        let root = graph.cases[0]
        guard (root.workflowState == .candidate || root.workflowState == .documented),
              graph.caseRevisions.isEmpty, graph.caseEvaluations.isEmpty, graph.scripts.isEmpty else {
            throw PersistenceError.draftDeletionDenied(id)
        }
        let roots = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRecord>())
        let others = try roots.filter { $0.id != id }.map { row -> CaseManifest in
            try checkFormat(row.formatVersion)
            return try PayloadCodec.decode(CaseManifest.self, from: row.manifest)
        }
        let manifest = CaseManifest(CaseGraphDTO(graph))
        let keepReviewerIdentity = Set(others.flatMap { $0.reviewers })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ReviewerIdentityRecord>()) {
            let key = StoredID(EntityID<ReviewerIdentity>(row.id), kind: "ReviewerIdentity")
            if manifest.reviewers.contains(key) && !keepReviewerIdentity.contains(key) { context.delete(row) }
        }
        let keepActor = Set(others.flatMap { $0.actors })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorRecord>()) {
            let key = StoredID(EntityID<Actor>(row.id), kind: "Actor")
            if manifest.actors.contains(key) && !keepActor.contains(key) { context.delete(row) }
        }
        let keepActorAffiliation = Set(others.flatMap { $0.affiliations })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActorAffiliationRecord>()) {
            let key = StoredID(EntityID<ActorAffiliation>(row.id), kind: "ActorAffiliation")
            if manifest.affiliations.contains(key) && !keepActorAffiliation.contains(key) { context.delete(row) }
        }
        let keepPromise = Set(others.flatMap { $0.promises })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRecord>()) {
            let key = StoredID(EntityID<Promise>(row.id), kind: "Promise")
            if manifest.promises.contains(key) && !keepPromise.contains(key) { context.delete(row) }
        }
        let keepPromiseRevision = Set(others.flatMap { $0.promiseRevisions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.PromiseRevisionRecord>()) {
            let key = StoredID(EntityID<PromiseRevision>(row.id), kind: "PromiseRevision")
            if manifest.promiseRevisions.contains(key) && !keepPromiseRevision.contains(key) { context.delete(row) }
        }
        let keepEvaluationCriterion = Set(others.flatMap { $0.criteria })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvaluationCriterionRecord>()) {
            let key = StoredID(EntityID<EvaluationCriterion>(row.id), kind: "EvaluationCriterion")
            if manifest.criteria.contains(key) && !keepEvaluationCriterion.contains(key) { context.delete(row) }
        }
        let keepCriterionRevision = Set(others.flatMap { $0.criterionRevisions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionRevisionRecord>()) {
            let key = StoredID(EntityID<CriterionRevision>(row.id), kind: "CriterionRevision")
            if manifest.criterionRevisions.contains(key) && !keepCriterionRevision.contains(key) { context.delete(row) }
        }
        let keepSource = Set(others.flatMap { $0.sources })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceRecord>()) {
            let key = StoredID(EntityID<Source>(row.id), kind: "Source")
            if manifest.sources.contains(key) && !keepSource.contains(key) { context.delete(row) }
        }
        let keepSourceVersion = Set(others.flatMap { $0.sourceVersions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceVersionRecord>()) {
            let key = StoredID(EntityID<SourceVersion>(row.id), kind: "SourceVersion")
            if manifest.sourceVersions.contains(key) && !keepSourceVersion.contains(key) { context.delete(row) }
        }
        let keepSourceExcerpt = Set(others.flatMap { $0.excerpts })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.SourceExcerptRecord>()) {
            let key = StoredID(EntityID<SourceExcerpt>(row.id), kind: "SourceExcerpt")
            if manifest.excerpts.contains(key) && !keepSourceExcerpt.contains(key) { context.delete(row) }
        }
        let keepActionOrDevelopment = Set(others.flatMap { $0.actions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionOrDevelopmentRecord>()) {
            let key = StoredID(EntityID<ActionOrDevelopment>(row.id), kind: "ActionOrDevelopment")
            if manifest.actions.contains(key) && !keepActionOrDevelopment.contains(key) { context.delete(row) }
        }
        let keepActionRevision = Set(others.flatMap { $0.actionRevisions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionRevisionRecord>()) {
            let key = StoredID(EntityID<ActionRevision>(row.id), kind: "ActionRevision")
            if manifest.actionRevisions.contains(key) && !keepActionRevision.contains(key) { context.delete(row) }
        }
        let keepActionParticipation = Set(others.flatMap { $0.participations })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActionParticipationRecord>()) {
            let key = StoredID(EntityID<ActionParticipation>(row.id), kind: "ActionParticipation")
            if manifest.participations.contains(key) && !keepActionParticipation.contains(key) { context.delete(row) }
        }
        let keepEvidenceLink = Set(others.flatMap { $0.evidenceLinks })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.EvidenceLinkRecord>()) {
            let key = StoredID(EntityID<EvidenceLink>(row.id), kind: "EvidenceLink")
            if manifest.evidenceLinks.contains(key) && !keepEvidenceLink.contains(key) { context.delete(row) }
        }
        let keepCaseRevision = Set(others.flatMap { $0.caseRevisions })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseRevisionRecord>()) {
            let key = StoredID(EntityID<CaseRevision>(row.id), kind: "CaseRevision")
            if manifest.caseRevisions.contains(key) && !keepCaseRevision.contains(key) { context.delete(row) }
        }
        let keepCriterionEvaluation = Set(others.flatMap { $0.criterionEvaluations })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.CriterionEvaluationRecord>()) {
            let key = StoredID(EntityID<CriterionEvaluation>(row.id), kind: "CriterionEvaluation")
            if manifest.criterionEvaluations.contains(key) && !keepCriterionEvaluation.contains(key) { context.delete(row) }
        }
        let keepCaseEvaluation = Set(others.flatMap { $0.caseEvaluations })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.CaseEvaluationRecord>()) {
            let key = StoredID(EntityID<CaseEvaluation>(row.id), kind: "CaseEvaluation")
            if manifest.caseEvaluations.contains(key) && !keepCaseEvaluation.contains(key) { context.delete(row) }
        }
        let keepMethodologyVersion = Set(others.flatMap { $0.methodologies })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.MethodologyVersionRecord>()) {
            let key = StoredID(EntityID<MethodologyVersion>(row.id), kind: "MethodologyVersion")
            if manifest.methodologies.contains(key) && !keepMethodologyVersion.contains(key) { context.delete(row) }
        }
        let keepResearchTask = Set(others.flatMap { $0.researchTasks })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ResearchTaskRecord>()) {
            let key = StoredID(EntityID<ResearchTask>(row.id), kind: "ResearchTask")
            if manifest.researchTasks.contains(key) && !keepResearchTask.contains(key) { context.delete(row) }
        }
        let keepAuditEntry = Set(others.flatMap { $0.auditEntries })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.AuditEntryRecord>()) {
            let key = StoredID(EntityID<AuditEntry>(row.id), kind: "AuditEntry")
            if manifest.auditEntries.contains(key) && !keepAuditEntry.contains(key) { context.delete(row) }
        }
        let keepScriptDraft = Set(others.flatMap { $0.scripts })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptDraftRecord>()) {
            let key = StoredID(EntityID<ScriptDraft>(row.id), kind: "ScriptDraft")
            if manifest.scripts.contains(key) && !keepScriptDraft.contains(key) { context.delete(row) }
        }
        let keepScriptStatement = Set(others.flatMap { $0.statements })
        for row in try context.fetch(FetchDescriptor<PersistenceSchemaV1.ScriptStatementRecord>()) {
            let key = StoredID(EntityID<ScriptStatement>(row.id), kind: "ScriptStatement")
            if manifest.statements.contains(key) && !keepScriptStatement.contains(key) { context.delete(row) }
        }
        for row in roots where row.id == id { context.delete(row) }
    }
}
