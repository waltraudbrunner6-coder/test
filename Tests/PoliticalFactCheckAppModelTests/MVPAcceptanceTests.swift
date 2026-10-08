import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckPersistence
import PoliticalFactCheckAppModel
import PoliticalFactCheckScripting
import PoliticalFactCheckExport

/// Cross-layer acceptance, starting with an empty on-disk store. No approved seed graphs.
final class MVPAcceptanceTests: XCTestCase {
    @MainActor func testEmptyStoreToFakeScriptExportImportAndDiskReopen() async throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        let evaluationID = try flow.approveFirstEvaluation()
        let evaluationGraph = try flow.graph()
        try flow.reopen()
        XCTAssertEqual(try flow.archive(), try PortableCaseArchiveV1(evaluationGraph))
        let generated = await flow.model.generateScript(evaluationID: evaluationID,
            provider: FakeScriptGenerationProvider())
        let scriptID = try XCTUnwrap(generated, flow.model.errorMessage ?? "Missing fake draft")
        try flow.approveScript(scriptID)
        let before = try flow.archive()
        try flow.reopen()
        XCTAssertEqual(try flow.archive(), before)
        let url = flow.root.appendingPathComponent("complete.politicalfactcheck")
        XCTAssertTrue(flow.model.exportEditorialPackage(scriptID: scriptID, to: url), flow.message)
        XCTAssertEqual(try flow.archive(), before) // Export has no domain side effects.
        let exported = try EditorialPackageIO.read(from: url)
        XCTAssertEqual(exported.archive, before)
        let imported = try MVPFlow()
        defer { imported.cleanup() }
        XCTAssertTrue(imported.model.prepareEditorialImport(from: url), imported.message)
        XCTAssertTrue(try imported.store.listCases().isEmpty)
        XCTAssertTrue(imported.model.confirmEditorialImport(), imported.message)
        XCTAssertEqual(imported.model.selectedCaseID, flow.model.selectedCaseID)
        XCTAssertEqual(try imported.archive(), before) // All 24 graph collections, not just counts.
        try imported.reopen()
        XCTAssertEqual(try imported.archive(), before)
        XCTAssertEqual(imported.model.selectedReviewState, .upToDate)
        XCTAssertEqual(flow.model.selectedReviewState, .upToDate)
        let graph = try imported.graph()
        XCTAssertFalse(graph.auditEntries.isEmpty)
        XCTAssertGreaterThan(graph.promiseRevisions.count, 1)
        XCTAssertEqual(graph.criterionRevisions.count, 2)
        XCTAssertEqual(graph.actionRevisions.count, 2)
        XCTAssertTrue(graph.statements.allSatisfy { $0.review != nil })
        XCTAssertEqual(graph.find(scriptID)?.status, .approved)
    }

    @MainActor func testEntireWorkflowWorksWithManualScriptAndNoProvider() throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        XCTAssertNil(flow.model.createDraftCase(title: "Synthetic first draft", quote: "Synthetic original",
            thesis: "Synthetic thesis", speakerName: "Synthetic speaker", partyName: "Synthetic party", statementDate: nil))
        XCTAssertTrue(flow.model.errorMessage?.contains("Prüfer") == true)
        XCTAssertTrue(try flow.store.listCases().isEmpty)
        let evaluation = try flow.approveFirstEvaluation()
        let id = try XCTUnwrap(flow.model.createManualScript(evaluationID: evaluation,
            output: flow.manualOutput(evaluation)), flow.message)
        try flow.approveScript(id)
        let graph = try flow.graph()
        XCTAssertEqual(graph.find(id)?.author, .human(graph.reviewers[0].id))
        XCTAssertTrue(flow.model.exportEditorialPackage(scriptID: id,
            to: flow.root.appendingPathComponent("manual.politicalfactcheck")), flow.message)
        XCTAssertNil(flow.model.openAITransmissionPreview)
    }

    @MainActor func testNewVerifiedEvidenceRequiresReviewAndBlocksScriptAndExport() async throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        let evaluationID = try flow.approveFirstEvaluation()
        let scriptID = try flow.manualApprovedScript(evaluationID)
        let before = try flow.graph()
        let historical = try XCTUnwrap(before.find(evaluationID))
        let snapshot = try XCTUnwrap(before.find(historical.caseRevisionID))
        let link = try flow.addCheckedEvidence(rationale: "Synthetic additional relevant corroboration")
        let after = try flow.graph()
        let pending = try XCTUnwrap(after.find(evaluationID))
        XCTAssertEqual(after.find(link)?.status, .verified)
        XCTAssertEqual(after.cases[0].workflowState, .approved)
        XCTAssertEqual(flow.model.selectedReviewState, .reviewRequired)
        XCTAssertEqual(pending.status, .reviewRequired)
        XCTAssertNotNil(pending.reviewReason)
        XCTAssertEqual(pending.category, historical.category)
        XCTAssertEqual(pending.rationale, historical.rationale)
        XCTAssertEqual(pending.confidence, historical.confidence)
        XCTAssertEqual(pending.facts, historical.facts)
        XCTAssertEqual(pending.interpretations, historical.interpretations)
        XCTAssertEqual(pending.uncertainties, historical.uncertainties)
        XCTAssertEqual(pending.approval, historical.approval)
        XCTAssertEqual(pending.caseRevisionID, historical.caseRevisionID)
        XCTAssertEqual(pending.methodologyVersionID, historical.methodologyVersionID)
        XCTAssertEqual(after.caseRevisions, before.caseRevisions)
        XCTAssertEqual(after.find(snapshot.id), snapshot)
        XCTAssertEqual(after.criterionEvaluations, before.criterionEvaluations)
        XCTAssertEqual(after.statements, before.statements)
        XCTAssertEqual(after.find(scriptID)?.approval, before.find(scriptID)?.approval)
        XCTAssertEqual(after.find(scriptID)?.status, .superseded)
        let stable = try flow.archive()
        XCTAssertNil(flow.model.editorialExportSummary(scriptID: scriptID))
        let url = flow.root.appendingPathComponent("blocked.politicalfactcheck")
        XCTAssertFalse(flow.model.exportEditorialPackage(scriptID: scriptID, to: url))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let generated = await flow.model.generateScript(evaluationID: evaluationID,
            provider: FakeScriptGenerationProvider())
        XCTAssertNil(generated)
        XCTAssertTrue(flow.model.errorMessage?.contains("erneut geprüft") == true)
        XCTAssertFalse(flow.model.prepareOpenAIPreview(evaluationID: evaluationID))
        XCTAssertNil(flow.model.createManualScript(evaluationID: evaluationID,
            output: PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0,
                text: "Synthetic qualification", kind: .qualification)])))
        XCTAssertEqual(try flow.archive(), stable)
        try flow.reopen()
        XCTAssertEqual(try flow.archive(), stable)
        XCTAssertEqual(flow.model.selectedReviewState, .reviewRequired)
    }

    @MainActor func testMissingEvidenceCanBeHumanApprovedAsNotVerifiableAndRoundtripped() throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        let evaluationID = try flow.approveFirstEvaluation(insufficientEvidence: true)
        let graph = try flow.graph()
        let evaluation = try XCTUnwrap(graph.find(evaluationID))
        XCTAssertTrue(graph.evidenceLinks.isEmpty)
        XCTAssertEqual(evaluation.category, .notVerifiable)
        XCTAssertEqual(evaluation.confidence, .low)
        XCTAssertEqual(evaluation.notVerifiableReasons, [.missingEvidence])
        XCTAssertEqual(evaluation.status, .approved)
        XCTAssertNotNil(evaluation.approval)
        XCTAssertTrue(graph.criterionEvaluations.allSatisfy {
            $0.category == .notVerifiable && $0.notVerifiableReasons == [.missingEvidence] && $0.review != nil
        })
        let output = PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0,
            text: "Synthetic development cannot be established from the available evidence.",
            kind: .qualification, uncertainty: "Synthetic missing development documentation")])
        let script = try XCTUnwrap(flow.model.createManualScript(evaluationID: evaluationID, output: output), flow.message)
        try flow.approveScript(script)
        let original = try flow.archive()
        let url = flow.root.appendingPathComponent("uncertain.politicalfactcheck")
        XCTAssertTrue(flow.model.exportEditorialPackage(scriptID: script, to: url), flow.message)
        let fresh = try MVPFlow()
        defer { fresh.cleanup() }
        XCTAssertTrue(fresh.model.prepareEditorialImport(from: url), fresh.message)
        XCTAssertTrue(fresh.model.confirmEditorialImport(), fresh.message)
        try fresh.reopen()
        XCTAssertEqual(try fresh.archive(), original)
        XCTAssertEqual(fresh.model.selectedReviewState, .upToDate)
    }

    @MainActor func testOfflineOpenAIFailuresPreserveCompleteCaseAndManualFallback() async throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        let evaluation = try flow.approveFirstEvaluation()
        let before = try flow.archive()
        // Each session selects its failure via a private test header; no mutable global stub state.
        let modes = ["missing-key", "service", "timeout", "transport"]
        let errors: [OpenAIProviderError] = [.missingAPIKey, .serviceUnavailable, .timeout, .networkFailure]
        for (index, mode) in modes.enumerated() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MVPOfflineFailureTransport.self]
            // URLProtocol sees a per-session header only; this is never a real network request.
            configuration.httpAdditionalHeaders = ["X-Synthetic-Failure": mode]
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let provider = OpenAIScriptGenerationProvider(session: session,
                safetyIdentifier: "787D941B-0CA8-44B4-9DCE-F1D4D3BB25C9",
                environment: { _ in mode == "missing-key" ? nil : "test-key-not-real" })
            XCTAssertTrue(flow.model.prepareOpenAIPreview(evaluationID: evaluation), flow.message)
            let result = await flow.model.sendOpenAIScript(provider: provider)
            XCTAssertNil(result)
            XCTAssertEqual(flow.model.errorMessage, WorkspaceErrorMessage.describe(errors[index]))
            XCTAssertFalse(flow.model.isGeneratingScript)
            XCTAssertEqual(try flow.archive(), before)
        }
        _ = try flow.manualApprovedScript(evaluation)
        try flow.reopen()
        XCTAssertEqual(flow.model.selectedReviewState, .upToDate)
        XCTAssertEqual(try flow.graph().caseEvaluations, try before.domain().caseEvaluations)
    }

    @MainActor func testExportFailuresNeverChangeApprovedDomainData() throws {
        let flow = try MVPFlow()
        defer { flow.cleanup() }
        let evaluation = try flow.approveFirstEvaluation()
        let script = try flow.manualApprovedScript(evaluation)
        let before = try flow.archive()
        let existing = flow.root.appendingPathComponent("existing.politicalfactcheck")
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: false)
        let marker = existing.appendingPathComponent("keep.txt")
        let bytes = Data("Synthetic existing content".utf8)
        try bytes.write(to: marker)
        let missingParent = flow.root.appendingPathComponent("missing/failure.politicalfactcheck")
        let wrongExtension = flow.root.appendingPathComponent("invalid.txt")
        for destination in [existing, missingParent, wrongExtension] {
            XCTAssertFalse(flow.model.exportEditorialPackage(scriptID: script, to: destination))
            XCTAssertNotNil(flow.model.errorMessage)
            XCTAssertEqual(try flow.archive(), before)
        }
        XCTAssertEqual(try Data(contentsOf: marker), bytes)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missingParent.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: wrongExtension.path))
        try flow.reopen()
        XCTAssertEqual(try flow.archive(), before)
    }

    @MainActor func testTamperedImportAndCaseCollisionLeaveNoPartialState() throws {
        let source = try MVPFlow()
        defer { source.cleanup() }
        let evaluation = try source.approveFirstEvaluation()
        let script = try source.manualApprovedScript(evaluation)
        let url = source.root.appendingPathComponent("import.politicalfactcheck")
        XCTAssertTrue(source.model.exportEditorialPackage(scriptID: script, to: url), source.message)
        let document = url.appendingPathComponent("script.md")
        let original = try Data(contentsOf: document)
        let target = try MVPFlow()
        defer { target.cleanup() }
        try Data("Synthetic tampering".utf8).write(to: document)
        XCTAssertFalse(target.model.prepareEditorialImport(from: url))
        XCTAssertTrue(try target.store.listCases().isEmpty)
        XCTAssertNil(target.model.selectedContext)
        try original.write(to: document)
        XCTAssertTrue(target.model.prepareEditorialImport(from: url), target.message)
        try Data("Synthetic changed after preview".utf8).write(to: document)
        XCTAssertFalse(target.model.confirmEditorialImport())
        XCTAssertTrue(try target.store.listCases().isEmpty)
        try target.reopen()
        XCTAssertTrue(target.model.cases.isEmpty)
        try original.write(to: document)
        XCTAssertTrue(target.model.prepareEditorialImport(from: url), target.message)
        XCTAssertTrue(target.model.confirmEditorialImport(), target.message)
        let before = try target.archive()
        XCTAssertEqual(before, try source.archive())
        XCTAssertFalse(target.model.prepareEditorialImport(from: url))
        XCTAssertEqual(target.model.errorMessage, "Dieser Fall ist bereits vorhanden.")
        XCTAssertEqual(try target.archive(), before)
        XCTAssertEqual(try target.store.listCases().count, 1)
        try target.reopen()
        XCTAssertEqual(try target.archive(), before)
    }

    @MainActor func testWorkflowAndValidationAreIndependentOfSyntheticPartyIdentity() throws {
        let alpha = try MVPFlow(), beta = try MVPFlow()
        defer { alpha.cleanup(); beta.cleanup() }
        let a = try alpha.approveFirstEvaluation(partyName: "Synthetic Party Alpha", speakerName: "Synthetic Speaker Alpha")
        let b = try beta.approveFirstEvaluation(partyName: "Synthetic Party Beta", speakerName: "Synthetic Speaker Beta")
        let left = try alpha.graph(), right = try beta.graph()
        XCTAssertNotEqual(left.actors.map { $0.id }, right.actors.map { $0.id })
        XCTAssertNotEqual(left.actors.map { $0.name }, right.actors.map { $0.name })
        XCTAssertEqual(alpha.milestones, beta.milestones)
        XCTAssertEqual(left.find(a)?.category, right.find(b)?.category)
        XCTAssertEqual(left.find(a)?.confidence, right.find(b)?.confidence)
        XCTAssertEqual(DomainValidator.validate(left).errors, DomainValidator.validate(right).errors)
        XCTAssertEqual(alpha.model.selectedReviewState, beta.model.selectedReviewState)
        XCTAssertEqual(left.criterionRevisions.sorted { $0.metadata.number < $1.metadata.number }.map { $0.state },
            right.criterionRevisions.sorted { $0.metadata.number < $1.metadata.number }.map { $0.state })
    }
}

/// Synthetic inputs are entered via the same commands as the UI, with explicit human assessments.
@MainActor private final class MVPFlow {
    let root: URL
    let storeURL: URL
    let suiteName: String
    let defaults: UserDefaults
    private(set) var store: LocalCaseStore!
    private(set) var model: CaseWorkspaceModel!
    private(set) var milestones: [CaseWorkflowState] = []
    static let statement = Date(timeIntervalSince1970: 1_609_372_800)
    static let event = Date(timeIntervalSince1970: 1_609_459_200)
    static let cutoff = Date(timeIntervalSince1970: 1_640_995_200)

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("SyntheticMVP-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        storeURL = root.appendingPathComponent("Cases.store")
        suiteName = "SyntheticMVP-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        store = try LocalCaseStore.at(url: storeURL)
        model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertTrue(model.cases.isEmpty)
        XCTAssertNil(model.selectedContext)
        XCTAssertNil(model.errorMessage)
    }
    var message: String { model.errorMessage ?? "Operation failed without a controlled message" }
    func cleanup() {
        model = nil; store = nil
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: root)
    }
    func reopen() throws {
        let before = try model.selectedContext.map { try PortableCaseArchiveV1($0) }
        model = nil; store = nil // Release the old container before opening the on-disk store.
        store = try LocalCaseStore.at(url: storeURL)
        model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertNil(model.errorMessage)
        if let before { XCTAssertEqual(try archive(), before) }
    }
    @discardableResult func graph(file: StaticString = #filePath, line: UInt = #line) throws -> DomainContext {
        let id = try XCTUnwrap(model.selectedCaseID, file: file, line: line)
        let graph = try XCTUnwrap(store.loadCase(id: id), file: file, line: line)
        let validation = DomainValidator.validate(graph)
        XCTAssertTrue(validation.isValid, "Domain errors: \(validation.errors)", file: file, line: line)
        try validation.requireValid() // Stop this workflow on errors; never filter them.
        return graph
    }
    func archive() throws -> PortableCaseArchiveV1 { try PortableCaseArchiveV1(graph()) }
    private func milestone(_ state: CaseWorkflowState) throws {
        let graph = try graph()
        XCTAssertEqual(graph.cases[0].workflowState, state)
        milestones.append(state)
        XCTAssertNil(model.errorMessage)
    }
    func approveFirstEvaluation(insufficientEvidence: Bool = false,
        partyName: String = "Synthetic Party", speakerName: String = "Synthetic Speaker") throws -> EntityID<CaseEvaluation> {
        model.reviewerName = "Synthetic human editor"
        let id = try XCTUnwrap(model.createDraftCase(title: "Synthetic service case",
            quote: "The synthetic service will open in 2021.", thesis: "Check synthetic service availability in 2021.",
            speakerName: speakerName, partyName: partyName, statementDate: Self.statement), message)
        try milestone(.candidate)
        let oldCriterion = try XCTUnwrap(model.addCriterionDraft(caseID: id,
            goal: "Synthetic service is available", targetGroup: "Synthetic users", deadline: Self.event,
            isCore: true, materialityRule: "Availability is the sole synthetic core criterion"), message)
        XCTAssertTrue(model.confirmCriterion(oldCriterion), message)
        XCTAssertTrue(model.addSource(caseID: id, urlText: "https://synthetic.example.invalid/announcement",
            documentIdentifier: "synthetic-announcement", title: "Synthetic original announcement",
            publisher: "Synthetic publisher", publicationDate: Self.statement, locator: "paragraph 1",
            excerptText: "The synthetic service will open in 2021.",
            excerptContext: "Synthetic speaker announced the service for synthetic users.", language: "en"), message)
        let unchecked = try XCTUnwrap(try graph().excerpts.first)
        XCTAssertTrue(model.verifyExcerpt(unchecked.id), message)
        XCTAssertTrue(model.verifyOriginalQuote(), message)
        XCTAssertTrue(model.markDocumented(), message)
        try milestone(.documented)
        let original = try XCTUnwrap(model.verifiedExcerpts.first)
        XCTAssertTrue(model.verifyPromiseForEvaluationReadiness(contextText: "Synthetic announcement to synthetic users",
            contextExcerptIDs: [original.id], speakerExcerptIDs: [original.id]), message)
        let criterion = try XCTUnwrap(model.selectedCase?.activeCriterionRevisionIDs.first)
        XCTAssertNotEqual(criterion, oldCriterion)
        XCTAssertEqual(try graph().find(oldCriterion)?.state, .confirmed)
        XCTAssertEqual(try graph().find(criterion)?.state, .draft)
        XCTAssertTrue(model.confirmCriterion(criterion), message)
        XCTAssertTrue(model.markVerified(), message)
        try milestone(.verified)
        XCTAssertTrue(model.prepareForEvaluation(), message)
        try milestone(.readyForEvaluation)
        var used: [EntityID<EvidenceLink>] = []
        if !insufficientEvidence {
            XCTAssertTrue(model.addSource(caseID: id, urlText: "https://synthetic.example.invalid/implementation",
                documentIdentifier: "synthetic-implementation", title: "Synthetic retrospective documentation",
                publisher: "Synthetic institution", publicationDate: Date(timeIntervalSince1970: 1_735_689_600),
                locator: "paragraph 2", excerptText: "The synthetic service opened in 2021.",
                excerptContext: "Synthetic document from 2025 records the synthetic 2021 implementation.", language: "en"), message)
            let draftExcerpt = try XCTUnwrap(try graph().excerpts.first {
                $0.state == .unverified && $0.id != unchecked.id
            })
            XCTAssertTrue(model.verifyExcerpt(draftExcerpt.id), message)
            let actionExcerpt = try XCTUnwrap(model.verifiedExcerpts.first { $0.text == draftExcerpt.text })
            let action = try XCTUnwrap(model.addAction(type: .implementation, title: "Synthetic service opening",
                description: "The synthetic service opened", eventDate: .instant(Self.event, role: .event),
                proceduralState: "implemented", scope: "Synthetic users", excerptIDs: [actionExcerpt.id]), message)
            XCTAssertTrue(model.verifyAction(action, excerptIDs: [actionExcerpt.id]), message)
            used = [try addCheckedEvidence(rationale: "Synthetic primary documentation supports availability")]
        }
        let cutoff = try DatedValue.instant(Self.cutoff, role: .evaluationCutoff)
        let snapshot = try XCTUnwrap(model.startEvaluationSnapshot(cutoff: cutoff), message)
        let reason = insufficientEvidence ? "Synthetic later development is undocumented; no negative inference" : "Synthetic checked documentation supports the sole criterion"
        // Explicit simulated human choices; no category computed from evidence or actor identity.
        let assessment = ManualAssessment(category: insufficientEvidence ? .notVerifiable : .fulfilled,
            rationale: try NonEmptyText(reason), confidence: insufficientEvidence ? .low : .high,
            uncertainties: insufficientEvidence ? [try NonEmptyText("Synthetic missing development records")] : [],
            notVerifiableReasons: insufficientEvidence ? [.missingEvidence] : [])
        let criterionInput = ManualCriterionAssessment(criterionRevisionID: criterion, assessment: assessment, evidenceLinkIDs: used)
        let evaluation = try XCTUnwrap(model.createEvaluationDraft(snapshotID: snapshot, cutoff: cutoff,
            criteria: [criterionInput], overall: assessment,
            facts: insufficientEvidence ? [] : [try NonEmptyText("Synthetic service was documented as open")],
            interpretations: [try NonEmptyText(reason)]), message)
        try milestone(.evaluated)
        XCTAssertEqual(try graph().find(evaluation)?.status, .draft)
        let child = try XCTUnwrap(try graph().criterionEvaluations.first)
        XCTAssertEqual(child.reviewState, .unreviewed)
        XCTAssertTrue(model.reviewCriterionEvaluation(child.id), message)
        XCTAssertTrue(model.submitEvaluationForReview(evaluation), message)
        XCTAssertEqual(try graph().find(evaluation)?.status, .needsReview)
        XCTAssertTrue(model.approveEvaluation(evaluation), message)
        try milestone(.approved)
        XCTAssertEqual(model.selectedReviewState, .upToDate)
        if !insufficientEvidence {
            XCTAssertTrue(model.evaluationWarnings(evaluation).contains { $0.contains("Rückblickende Dokumentation") })
        }
        return evaluation
    }
    func addCheckedEvidence(rationale: String) throws -> EntityID<EvidenceLink> {
        let graph = try graph()
        let criterion = try XCTUnwrap(graph.cases[0].activeCriterionRevisionIDs.first)
        let action = try XCTUnwrap(graph.cases[0].currentActionRevisionIDs.first)
        let excerpt = try XCTUnwrap(graph.find(action)?.excerptIDs.first)
        let id = try XCTUnwrap(model.addEvidenceDraft(criterionRevisionID: criterion, excerptIDs: [excerpt],
            actionRevisionID: action, relationship: .supports, directness: .direct, rationale: rationale,
            temporalReference: .instant(Self.event, role: .event)), message)
        XCTAssertEqual(try self.graph().find(id)?.status, .draft)
        XCTAssertTrue(model.requestEvidenceReview(id), message)
        XCTAssertEqual(try self.graph().find(id)?.status, .needsReview)
        XCTAssertTrue(model.verifyEvidence(id), message)
        XCTAssertEqual(try self.graph().find(id)?.status, .verified)
        return id
    }
    func manualOutput(_ evaluation: EntityID<CaseEvaluation>) throws -> PoliticalFactCheckScripting.ScriptGenerationOutput {
        let input = try model.scriptInput(evaluationID: evaluation)
        let evidence = try XCTUnwrap(input.evidence.first)
        return PoliticalFactCheckScripting.ScriptGenerationOutput(statements: [.init(position: 0,
            text: "The synthetic service opened in 2021.", kind: .fact,
            referencedExcerptKeys: evidence.excerptKeys, referencedEvidenceKeys: [evidence.key]),
            .init(position: 1, text: "Synthetic human interpretation of the documented availability.", kind: .interpretation)])
    }
    func manualApprovedScript(_ evaluation: EntityID<CaseEvaluation>) throws -> EntityID<ScriptDraft> {
        let id = try XCTUnwrap(model.createManualScript(evaluationID: evaluation, output: manualOutput(evaluation)), message)
        try approveScript(id)
        return id
    }
    func approveScript(_ id: EntityID<ScriptDraft>) throws {
        let draft = try XCTUnwrap(try graph().find(id))
        XCTAssertEqual(draft.status, .draft)
        XCTAssertNil(draft.approval)
        for statement in draft.statementIDs {
            XCTAssertNil(try graph().find(statement)?.review)
            XCTAssertTrue(model.reviewScriptStatement(statement), message)
        }
        XCTAssertTrue(model.submitScriptForReview(id), message)
        XCTAssertEqual(try graph().find(id)?.status, .needsReview)
        XCTAssertTrue(model.approveScript(id), message)
        XCTAssertEqual(try graph().find(id)?.status, .approved)
        XCTAssertNotNil(model.editorialExportSummary(scriptID: id))
    }
}

/// Intercepts every URL; it cannot fall through to a live transport, even on test mistakes.
private final class MVPOfflineFailureTransport: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        switch request.value(forHTTPHeaderField: "X-Synthetic-Failure") {
        case "service":
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("Synthetic unavailable service".utf8))
            client?.urlProtocolDidFinishLoading(self)
        case "timeout": client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
        case "transport": client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        default:
            XCTFail("Unexpected offline request; live networking is forbidden")
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
        }
    }
    override func stopLoading() {}
}
