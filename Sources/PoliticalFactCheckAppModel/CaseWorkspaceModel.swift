import Combine
import Foundation
import PoliticalFactCheckCore
import PoliticalFactCheckPersistence

@MainActor
public final class CaseWorkspaceModel: ObservableObject {
    @Published public private(set) var cases: [PoliticalFactCheckCore.Case] = []
    @Published public private(set) var reviewStates: [EntityID<PoliticalFactCheckCore.Case>: CaseReviewState] = [:]
    @Published public var selectedCaseID: EntityID<PoliticalFactCheckCore.Case>?
    @Published public private(set) var selectedContext: DomainContext?
    @Published public private(set) var selectedReviewState: CaseReviewState?
    @Published public private(set) var errorMessage: String?
    @Published public var reviewerName: String {
        didSet { defaults.set(reviewerName, forKey: Self.reviewerNameKey) }
    }

    private static let reviewerNameKey = "politicalFactCheck.reviewerName"
    private static let reviewerIDKey = "politicalFactCheck.reviewerID"
    private let store: LocalCaseStore?
    private let defaults: UserDefaults

    public init(store: LocalCaseStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        self.reviewerName = defaults.string(forKey: Self.reviewerNameKey) ?? ""
        reload()
    }

    public init(startupError: String, defaults: UserDefaults = .standard) {
        self.store = nil
        self.defaults = defaults
        self.reviewerName = defaults.string(forKey: Self.reviewerNameKey) ?? ""
        self.errorMessage = startupError
    }

    public var selectedCase: PoliticalFactCheckCore.Case? {
        guard let id = selectedCaseID else { return nil }
        return cases.first { $0.id == id }
    }

    public var canDeleteSelectedDraft: Bool {
        guard let graph = selectedContext, let politicalCase = selectedCase,
              [.candidate, .documented].contains(politicalCase.workflowState) else { return false }
        return graph.caseRevisions.isEmpty && graph.caseEvaluations.isEmpty && graph.scripts.isEmpty
    }

    public func reload() {
        guard let store else { return }
        do {
            cases = try store.listCases()
            reviewStates = [:]
            var states: [EntityID<PoliticalFactCheckCore.Case>: CaseReviewState] = [:]
            for politicalCase in cases {
                guard let graph = try store.loadCase(id: politicalCase.id) else { continue }
                states[politicalCase.id] = try CaseReviews.state(of: politicalCase, in: graph)
            }
            reviewStates = states
            let wanted = selectedCaseID.flatMap { id in cases.first(where: { $0.id == id })?.id }
            selectedCaseID = wanted ?? cases.first?.id
            errorMessage = nil
            loadSelectedCase()
        } catch { present(error) }
    }

    public func selectCase(_ id: EntityID<PoliticalFactCheckCore.Case>?) {
        selectedCaseID = id
        loadSelectedCase()
    }

    @discardableResult
    public func createDraftCase(title: String, quote: String, thesis: String,
                                speakerName: String, partyName: String,
                                statementDate: Date?) -> EntityID<PoliticalFactCheckCore.Case>? {
        do {
            guard let store else { throw WorkspaceInputError.storeUnavailable }
            let reviewer = try currentReviewer()
            let now = Date()
            let caseID = EntityID<PoliticalFactCheckCore.Case>()
            let promiseID = EntityID<Promise>()
            let revisionID = EntityID<PromiseRevision>()
            let speaker = Actor(name: try NonEmptyText(speakerName), type: .person)
            let party = Actor(name: try NonEmptyText(partyName), type: .party)
            let promise = Promise(id: promiseID, caseID: caseID, currentRevisionID: revisionID, createdAt: now)
            let statement: DatedValue
            if let statementDate { statement = try .instant(statementDate, role: .statement) }
            else { statement = try .unknown(role: .statement, reason: NonEmptyText("Aussagezeitpunkt noch nicht erfasst")) }
            let revision = PromiseRevision(
                id: revisionID, promiseID: promiseID,
                quote: try asserted(.known(NonEmptyText(quote))),
                thesis: try NonEmptyText(thesis),
                statementDate: try asserted(.known(statement)),
                context: try unknown("Kontext noch nicht erfasst"),
                targetGroup: try unknown("Zielgruppe noch nicht erfasst"),
                conditions: try unknownArray("Bedingungen noch nicht erfasst"),
                responsibility: try unknown("Zuständigkeit noch nicht erfasst"),
                speaker: try asserted(.known(speaker.id)),
                party: try asserted(.known(party.id)),
                metadata: RevisionMetadata(number: 1, reason: try NonEmptyText("Manuell erfasster Erstentwurf"),
                                           author: .human(reviewer.id), createdAt: now))
            let politicalCase = PoliticalFactCheckCore.Case(
                id: caseID, title: try NonEmptyText(title), promiseID: promiseID,
                currentPromiseRevisionID: revisionID, workflowState: .candidate,
                createdAt: now, modifiedAt: now)
            let audit = try auditEntry(caseID: caseID, target: ObjectReference(kind: .politicalCase, id: caseID),
                operation: "createDraftCase", author: reviewer.id, at: now, reason: "Fall als ungeprüften Entwurf angelegt")
            let graph = DomainContext(reviewers: [reviewer], cases: [politicalCase], actors: [speaker, party],
                promises: [promise], promiseRevisions: [revision], auditEntries: [audit])
            try store.saveCase(graph)
            reload(selecting: caseID)
            return caseID
        } catch { present(error); return nil }
    }

    @discardableResult
    public func addCriterionDraft(caseID: EntityID<PoliticalFactCheckCore.Case>, goal: String,
                                  targetGroup: String, deadline: Date?, isCore: Bool,
                                  materialityRule: String) -> EntityID<CriterionRevision>? {
        do {
            guard let store, let graph = try store.loadCase(id: caseID),
                  let politicalCase = graph.find(caseID), let promise = graph.find(politicalCase.promiseID) else {
                throw WorkspaceInputError.caseUnavailable
            }
            let reviewer = try currentReviewer()
            let now = Date()
            let criterionID = EntityID<EvaluationCriterion>()
            let revisionID = EntityID<CriterionRevision>()
            let due: DatedValue
            if let deadline { due = try .instant(deadline, role: .deadline) }
            else { due = try .unknown(role: .deadline, reason: NonEmptyText("Frist noch nicht festgelegt")) }
            let criterion = EvaluationCriterion(id: criterionID, promiseID: promise.id,
                currentRevisionID: revisionID, createdAt: now)
            let revision = CriterionRevision(id: revisionID, criterionID: criterionID,
                promiseRevisionID: politicalCase.currentPromiseRevisionID,
                goal: try NonEmptyText(goal), targetGroup: try NonEmptyText(targetGroup),
                baseline: .unknown(reason: try NonEmptyText("Ausgangslage noch nicht erfasst")), deadline: due,
                conditions: .unknown(reason: try NonEmptyText("Bedingungen noch nicht erfasst")),
                isCore: isCore, materialityRule: try NonEmptyText(materialityRule),
                metadata: RevisionMetadata(number: 1, reason: try NonEmptyText("Kriterium manuell angelegt"),
                                           author: .human(reviewer.id), createdAt: now), state: .draft)
            var updated = replacing(graph,
                reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                cases: graph.cases.map { $0.id == caseID ? PoliticalFactCheckCore.Case(
                    id: $0.id, title: $0.title, promiseID: $0.promiseID,
                    currentPromiseRevisionID: $0.currentPromiseRevisionID,
                    activeCriterionRevisionIDs: $0.activeCriterionRevisionIDs + [revisionID],
                    currentActionRevisionIDs: $0.currentActionRevisionIDs, workflowState: $0.workflowState,
                    createdAt: $0.createdAt, modifiedAt: now) : $0 },
                criteria: graph.criteria + [criterion], criterionRevisions: graph.criterionRevisions + [revision])
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .criterionRevision, id: revisionID),
                operation: "addCriterionDraft", author: reviewer.id, at: now,
                reason: "Prüfkriterium als Draft angelegt"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return revisionID
        } catch { present(error); return nil }
    }

    @discardableResult
    public func confirmCriterion(_ revisionID: EntityID<CriterionRevision>) -> Bool {
        do {
            guard let store, let caseID = selectedCaseID, let graph = try store.loadCase(id: caseID),
                  let old = graph.find(revisionID) else { throw WorkspaceInputError.caseUnavailable }
            let reviewer = try currentReviewer()
            let now = Date()
            let review = HumanReview(reviewerID: reviewer.id, reviewedAt: now)
            let confirmed = try DomainChanges.transition(old, to: .confirmed, review: review, in: graph)
            var updated = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                criterionRevisions: graph.criterionRevisions.map { $0.id == revisionID ? confirmed : $0 })
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .criterionRevision, id: revisionID),
                operation: "confirmCriterion", author: reviewer.id, at: now,
                reason: "Prüfkriterium menschlich bestätigt"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return true
        } catch { present(error); return false }
    }

    @discardableResult
    public func addSource(caseID: EntityID<PoliticalFactCheckCore.Case>, urlText: String,
                          documentIdentifier: String, title: String, publisher: String,
                          publicationDate: Date?, locator: String, excerptText: String,
                          excerptContext: String, language: String) -> Bool {
        do {
            guard let store, let graph = try store.loadCase(id: caseID),
                  let politicalCase = graph.find(caseID), let promise = graph.find(politicalCase.promiseID),
                  let promiseRevision = graph.find(politicalCase.currentPromiseRevisionID) else {
                throw WorkspaceInputError.caseUnavailable
            }
            let reviewer = try currentReviewer()
            let now = Date()
            let cleanURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            let url: URL?
            if cleanURL.isEmpty { url = nil }
            else {
                guard let parts = URLComponents(string: cleanURL),
                      ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
                      parts.host != nil, let parsed = parts.url else { throw WorkspaceInputError.invalidURL }
                url = parsed
            }
            let identifier = try optionalText(documentIdentifier)
            guard url != nil || identifier != nil else { throw DomainValidationError.missingSourceIdentity }
            let source = Source(canonicalURL: url, documentIdentifier: identifier)
            let publication: DatedValue
            if let publicationDate { publication = try .instant(publicationDate, role: .publication) }
            else { publication = try .unknown(role: .publication, reason: NonEmptyText("Publikationsdatum nicht erfasst")) }
            let version = SourceVersion(sourceID: source.id, kind: .original, requestedURL: url,
                title: try optionalText(title), publisher: try optionalText(publisher), publicationDate: publication,
                retrievedAt: try .instant(now, role: .retrieval), availability: .unknown,
                verification: .unreviewed, contentType: try NonEmptyText("text/plain"),
                language: try NonEmptyText(language))
            let excerpt = SourceExcerpt(sourceVersionID: version.id, locator: try NonEmptyText(locator),
                text: try NonEmptyText(excerptText), context: try NonEmptyText(excerptContext),
                language: try NonEmptyText(language), provenance: .humanEntered, state: .unverified,
                createdAt: now)
            var revisions = graph.promiseRevisions
            var promises = graph.promises
            var cases = graph.cases
            if promiseRevision.quote.verification != .verified {
                let quote = try AssertedValue(content: promiseRevision.quote.content,
                    provenance: promiseRevision.quote.provenance,
                    verification: promiseRevision.quote.verification,
                    excerptIDs: promiseRevision.quote.excerptIDs + [excerpt.id],
                    review: promiseRevision.quote.review)
                let revised = copyingPromiseRevision(promiseRevision, id: EntityID<PromiseRevision>(),
                    quote: quote, author: reviewer.id, at: now,
                    reason: try NonEmptyText("Manuell erfasste Fundstelle mit der Aussage verknüpft"))
                revisions.append(revised)
                promises = promises.map { $0.id == promise.id ? Promise(id: $0.id, caseID: $0.caseID,
                    currentRevisionID: revised.id, createdAt: $0.createdAt) : $0 }
                cases = cases.map { $0.id == caseID ? PoliticalFactCheckCore.Case(id: $0.id, title: $0.title,
                    promiseID: $0.promiseID, currentPromiseRevisionID: revised.id,
                    activeCriterionRevisionIDs: $0.activeCriterionRevisionIDs,
                    currentActionRevisionIDs: $0.currentActionRevisionIDs, workflowState: $0.workflowState,
                    createdAt: $0.createdAt, modifiedAt: now) : $0 }
            }
            var updated = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                cases: cases, promises: promises, promiseRevisions: revisions,
                sources: graph.sources + [source], sourceVersions: graph.sourceVersions + [version],
                excerpts: graph.excerpts + [excerpt])
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .excerpt, id: excerpt.id), operation: "addSourceExcerpt",
                author: reviewer.id, at: now, reason: "Quelle und ungeprüfte Fundstelle manuell erfasst"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return true
        } catch { present(error); return false }
    }

    @discardableResult
    public func verifyExcerpt(_ excerptID: EntityID<SourceExcerpt>) -> Bool {
        do {
            guard let store, let caseID = selectedCaseID, let graph = try store.loadCase(id: caseID),
                  let oldExcerpt = graph.find(excerptID), let oldVersion = graph.find(oldExcerpt.sourceVersionID) else {
                throw WorkspaceInputError.caseUnavailable
            }
            let reviewer = try currentReviewer()
            let now = Date()
            let review = HumanReview(reviewerID: reviewer.id, reviewedAt: now)
            // SourceVersion is immutable, so checking it creates a newly identified reviewed version.
            let version = SourceVersion(id: EntityID<SourceVersion>(), sourceID: oldVersion.sourceID,
                kind: oldVersion.kind, requestedURL: oldVersion.requestedURL, finalURL: oldVersion.finalURL,
                archiveURL: oldVersion.archiveURL, title: oldVersion.title, publisher: oldVersion.publisher,
                author: oldVersion.author, publicationDate: oldVersion.publicationDate,
                retrievedAt: try .instant(now, role: .retrieval), eventDate: oldVersion.eventDate,
                validity: oldVersion.validity, availability: oldVersion.availability,
                verification: .verified, review: review, contentType: oldVersion.contentType,
                language: oldVersion.language, localCopyReference: oldVersion.localCopyReference,
                hash: oldVersion.hash)
            let draftExcerpt = SourceExcerpt(id: EntityID<SourceExcerpt>(), sourceVersionID: version.id,
                locator: oldExcerpt.locator, text: oldExcerpt.text, context: oldExcerpt.context,
                language: oldExcerpt.language, translationOfExcerptID: oldExcerpt.translationOfExcerptID,
                provenance: oldExcerpt.provenance, state: .unverified, createdAt: now)
            let staged = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                sourceVersions: graph.sourceVersions + [version], excerpts: graph.excerpts + [draftExcerpt])
            let verified = try DomainChanges.transition(draftExcerpt, to: .verified, review: review, in: staged)
            var revisions = graph.promiseRevisions
            var promises = graph.promises
            var cases = graph.cases
            if let caseRoot = graph.find(caseID),
               let promise = graph.find(caseRoot.promiseID),
               let head = graph.find(promise.currentRevisionID),
               head.quote.verification != .verified, head.quote.excerptIDs.contains(excerptID) {
                let quote = try AssertedValue(content: head.quote.content, provenance: head.quote.provenance,
                    verification: head.quote.verification,
                    excerptIDs: head.quote.excerptIDs.map { $0 == excerptID ? verified.id : $0 },
                    review: head.quote.review)
                let revised = copyingPromiseRevision(head, id: EntityID<PromiseRevision>(), quote: quote,
                    author: reviewer.id, at: now, reason: try NonEmptyText("Geprüfte Fundstellenfassung verknüpft"))
                revisions.append(revised)
                promises = promises.map { $0.id == promise.id ? Promise(id: $0.id, caseID: $0.caseID,
                    currentRevisionID: revised.id, createdAt: $0.createdAt) : $0 }
                cases = cases.map { $0.id == caseID ? PoliticalFactCheckCore.Case(id: $0.id, title: $0.title,
                    promiseID: $0.promiseID, currentPromiseRevisionID: revised.id,
                    activeCriterionRevisionIDs: $0.activeCriterionRevisionIDs,
                    currentActionRevisionIDs: $0.currentActionRevisionIDs, workflowState: $0.workflowState,
                    createdAt: $0.createdAt, modifiedAt: now) : $0 }
            }
            var updated = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                cases: cases, promises: promises, promiseRevisions: revisions,
                sourceVersions: staged.sourceVersions, excerpts: staged.excerpts.map { $0.id == draftExcerpt.id ? verified : $0 })
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .excerpt, id: verified.id), operation: "verifySourceExcerpt",
                author: reviewer.id, at: now, reason: "Quellenfassung und Fundstelle manuell geprüft"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return true
        } catch { present(error); return false }
    }

    @discardableResult
    public func verifyOriginalQuote() -> Bool {
        do {
            guard let store, let caseID = selectedCaseID, let graph = try store.loadCase(id: caseID),
                  let politicalCase = graph.find(caseID),
                  let promise = graph.find(politicalCase.promiseID),
                  let head = graph.find(politicalCase.currentPromiseRevisionID) else {
                throw WorkspaceInputError.caseUnavailable
            }
            let reviewer = try currentReviewer()
            guard case .known(let quoteText) = head.quote.content else { throw WorkspaceInputError.quoteUnavailable }
            let verifiedExcerptIDs = head.quote.excerptIDs.filter { id in
                guard let excerpt = graph.find(id), let version = graph.find(excerpt.sourceVersionID) else { return false }
                return excerpt.state == .verified && version.verification == .verified && excerpt.text == quoteText
            }
            guard !verifiedExcerptIDs.isEmpty else { throw DomainValidationError.missingOriginalExcerpt }
            let now = Date()
            let review = HumanReview(reviewerID: reviewer.id, reviewedAt: now)
            let quote = try AssertedValue(content: head.quote.content, provenance: head.quote.provenance,
                verification: .verified, excerptIDs: verifiedExcerptIDs, review: review)
            let revised = copyingPromiseRevision(head, id: EntityID<PromiseRevision>(), quote: quote,
                author: reviewer.id, at: now, reason: try NonEmptyText("Originalwortlaut anhand der Fundstelle geprüft"))
            let promises = graph.promises.map { $0.id == promise.id ? Promise(id: $0.id, caseID: $0.caseID,
                currentRevisionID: revised.id, createdAt: $0.createdAt) : $0 }
            let cases = graph.cases.map { $0.id == caseID ? PoliticalFactCheckCore.Case(id: $0.id, title: $0.title,
                promiseID: $0.promiseID, currentPromiseRevisionID: revised.id,
                activeCriterionRevisionIDs: $0.activeCriterionRevisionIDs,
                currentActionRevisionIDs: $0.currentActionRevisionIDs, workflowState: $0.workflowState,
                createdAt: $0.createdAt, modifiedAt: now) : $0 }
            var updated = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                cases: cases, promises: promises, promiseRevisions: graph.promiseRevisions + [revised])
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .promiseRevision, id: revised.id), operation: "verifyOriginalQuote",
                author: reviewer.id, at: now, reason: "Originalzitat menschlich geprüft"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return true
        } catch { present(error); return false }
    }

    @discardableResult
    public func markDocumented() -> Bool {
        do {
            guard let store, let caseID = selectedCaseID, let graph = try store.loadCase(id: caseID),
                  let politicalCase = graph.find(caseID) else { throw WorkspaceInputError.caseUnavailable }
            let reviewer = try currentReviewer()
            let now = Date()
            let documented = try DomainChanges.transition(politicalCase, to: .documented, at: now, in: graph)
            var updated = replacing(graph, reviewers: mergedReviewer(reviewer, into: graph.reviewers),
                cases: graph.cases.map { $0.id == caseID ? documented : $0 })
            updated = appendingAudit(updated, try auditEntry(caseID: caseID,
                target: ObjectReference(kind: .politicalCase, id: caseID), operation: "markDocumented",
                author: reviewer.id, at: now, reason: "Originalaussage und mindestens eine Fundstelle dokumentiert"))
            try store.saveCase(updated)
            reload(selecting: caseID)
            return true
        } catch { present(error); return false }
    }

    @discardableResult
    public func deleteSelectedDraft() -> Bool {
        do {
            guard let store, let id = selectedCaseID else { throw WorkspaceInputError.caseUnavailable }
            try store.deleteDraftCase(id: id)
            selectedCaseID = nil
            selectedContext = nil
            selectedReviewState = nil
            reload()
            errorMessage = nil
            return true
        } catch { present(error); return false }
    }

    public func dismissError() { errorMessage = nil }

    private func reload(selecting id: EntityID<PoliticalFactCheckCore.Case>) {
        selectedCaseID = id
        reload()
    }

    private func loadSelectedCase() {
        guard let store, let id = selectedCaseID else {
            selectedContext = nil
            selectedReviewState = nil
            return
        }
        do {
            guard let graph = try store.loadCase(id: id), let politicalCase = graph.find(id) else {
                selectedContext = nil
                selectedReviewState = nil
                return
            }
            selectedContext = graph
            selectedReviewState = try CaseReviews.state(of: politicalCase, in: graph)
            reviewStates[id] = selectedReviewState
        } catch { present(error) }
    }

    private func currentReviewer() throws -> ReviewerIdentity {
        let name = reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw WorkspaceInputError.reviewerNameMissing }
        let rawID: UUID
        if let existing = defaults.string(forKey: Self.reviewerIDKey), let id = UUID(uuidString: existing) { rawID = id }
        else {
            rawID = UUID()
            defaults.set(rawID.uuidString, forKey: Self.reviewerIDKey)
        }
        return ReviewerIdentity(id: EntityID<ReviewerIdentity>(rawID), displayName: try NonEmptyText(name))
    }

    private func present(_ error: Error) { errorMessage = WorkspaceErrorMessage.describe(error) }

    private func asserted<Value>(_ content: FieldValue<Value>) throws -> AssertedValue<Value> {
        try AssertedValue(content: content, provenance: .humanEntered, verification: .unreviewed)
    }

    private func unknown(_ reason: String) throws -> AssertedValue<NonEmptyText> {
        try asserted(.unknown(reason: NonEmptyText(reason)))
    }

    private func unknownArray(_ reason: String) throws -> AssertedValue<[NonEmptyText]> {
        try asserted(.unknown(reason: NonEmptyText(reason)))
    }

    private func optionalText(_ value: String) throws -> NonEmptyText? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : try NonEmptyText(trimmed)
    }

    private func mergedReviewer(_ reviewer: ReviewerIdentity, into existing: [ReviewerIdentity]) -> [ReviewerIdentity] {
        if existing.contains(where: { $0.id == reviewer.id }) {
            return existing.map { $0.id == reviewer.id ? reviewer : $0 }
        }
        return existing + [reviewer]
    }

    private func auditEntry(caseID: EntityID<PoliticalFactCheckCore.Case>, target: ObjectReference,
                            operation: String, author: EntityID<ReviewerIdentity>, at date: Date,
                            reason: String) throws -> AuditEntry {
        AuditEntry(caseID: caseID, target: target, operation: try NonEmptyText(operation),
            author: .human(author), humanRequesterID: author, occurredAt: date, reason: try NonEmptyText(reason))
    }

    private func appendingAudit(_ graph: DomainContext, _ entry: AuditEntry) -> DomainContext {
        replacing(graph, auditEntries: graph.auditEntries + [entry])
    }

    private func copyingPromiseRevision(_ old: PromiseRevision, id: EntityID<PromiseRevision>,
                                        quote: AssertedValue<NonEmptyText>, author: EntityID<ReviewerIdentity>,
                                        at date: Date, reason: NonEmptyText) -> PromiseRevision {
        PromiseRevision(id: id, promiseID: old.promiseID, quote: quote, thesis: old.thesis,
            statementDate: old.statementDate, context: old.context, targetGroup: old.targetGroup,
            conditions: old.conditions, responsibility: old.responsibility, speaker: old.speaker,
            party: old.party, topics: old.topics,
            metadata: RevisionMetadata(number: old.metadata.number + 1,
                reason: reason, author: .human(author), createdAt: date))
    }


    private func replacing(_ graph: DomainContext,
        reviewers: [ReviewerIdentity]? = nil,
        cases: [PoliticalFactCheckCore.Case]? = nil,
        actors: [Actor]? = nil,
        affiliations: [ActorAffiliation]? = nil,
        promises: [Promise]? = nil,
        promiseRevisions: [PromiseRevision]? = nil,
        criteria: [EvaluationCriterion]? = nil,
        criterionRevisions: [CriterionRevision]? = nil,
        sources: [Source]? = nil,
        sourceVersions: [SourceVersion]? = nil,
        excerpts: [SourceExcerpt]? = nil,
        actions: [ActionOrDevelopment]? = nil,
        actionRevisions: [ActionRevision]? = nil,
        participations: [ActionParticipation]? = nil,
        evidenceLinks: [EvidenceLink]? = nil,
        caseRevisions: [CaseRevision]? = nil,
        criterionEvaluations: [CriterionEvaluation]? = nil,
        caseEvaluations: [CaseEvaluation]? = nil,
        methodologies: [MethodologyVersion]? = nil,
        researchTasks: [ResearchTask]? = nil,
        auditEntries: [AuditEntry]? = nil,
        scripts: [ScriptDraft]? = nil,
        statements: [ScriptStatement]? = nil) -> DomainContext {
        DomainContext(reviewers: reviewers ?? graph.reviewers, cases: cases ?? graph.cases,
            actors: actors ?? graph.actors, affiliations: affiliations ?? graph.affiliations,
            promises: promises ?? graph.promises, promiseRevisions: promiseRevisions ?? graph.promiseRevisions,
            criteria: criteria ?? graph.criteria, criterionRevisions: criterionRevisions ?? graph.criterionRevisions,
            sources: sources ?? graph.sources, sourceVersions: sourceVersions ?? graph.sourceVersions,
            excerpts: excerpts ?? graph.excerpts, actions: actions ?? graph.actions,
            actionRevisions: actionRevisions ?? graph.actionRevisions, participations: participations ?? graph.participations,
            evidenceLinks: evidenceLinks ?? graph.evidenceLinks, caseRevisions: caseRevisions ?? graph.caseRevisions,
            criterionEvaluations: criterionEvaluations ?? graph.criterionEvaluations,
            caseEvaluations: caseEvaluations ?? graph.caseEvaluations, methodologies: methodologies ?? graph.methodologies,
            researchTasks: researchTasks ?? graph.researchTasks, auditEntries: auditEntries ?? graph.auditEntries,
            scripts: scripts ?? graph.scripts, statements: statements ?? graph.statements)
    }
}

enum WorkspaceInputError: Error {
    case reviewerNameMissing
    case caseUnavailable
    case invalidURL
    case quoteUnavailable
    case storeUnavailable
}
