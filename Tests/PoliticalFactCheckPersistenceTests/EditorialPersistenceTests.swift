import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckExport
@testable import PoliticalFactCheckPersistence

final class EditorialPersistenceTests: XCTestCase {
    func testExportImportFreshStorePreservesWholeGraph() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), source = try LocalCaseStore.inMemory(), target = try LocalCaseStore.inMemory()
            try source.saveCase(f.context())
            let graph = try XCTUnwrap(source.loadCase(id: f.base.politicalCase.id))
            let files = try EditorialPackage.create(graph: graph, evaluationID: f.base.evaluation.id, scriptID: f.script.id).files
            let package = try EditorialPackage.validate(files: files)
            XCTAssertEqual(try target.importEditorialPackage(package), f.base.politicalCase.id)
            let reopened = LocalCaseStore(container: target.container)
            let result = try XCTUnwrap(reopened.loadCase(id: f.base.politicalCase.id))
            XCTAssertEqual(try PortableCaseArchiveV1(result), try PortableCaseArchiveV1(graph))
            XCTAssertTrue(DomainValidator.validate(result).isValid)
            XCTAssertEqual(try CaseReviews.state(of: result.cases[0], in: result), .upToDate)
        }
    }
    func testFullHistoricalEvaluationsSnapshotsScriptsAndAuditsInFreshStore() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), graph = try packageHistoryContext(f), store = try LocalCaseStore.inMemory()
            let contents = try EditorialPackage.create(graph: graph, evaluationID: f.base.evaluation.id, scriptID: f.script.id)
            _ = try store.importEditorialPackage(EditorialPackage.validate(files: contents.files))
            let reopened = LocalCaseStore(container: store.container)
            let result = try XCTUnwrap(reopened.loadCase(id: f.base.politicalCase.id))
            XCTAssertEqual(try PortableCaseArchiveV1(result), try PortableCaseArchiveV1(graph))
            XCTAssertEqual(result.caseRevisions.count, 2); XCTAssertEqual(result.caseEvaluations.count, 2)
            XCTAssertEqual(result.scripts.count, 2); XCTAssertEqual(result.auditEntries.count, 2)
            XCTAssertEqual(try CaseReviews.state(of: result.cases[0], in: result), .upToDate)
            for value in graph.caseEvaluations { XCTAssertEqual(result.find(value.id), value) }
            for value in graph.caseRevisions { XCTAssertEqual(result.find(value.id), value) }
        }
    }
    func testExistingCaseIDBlockedWithoutOverwrite() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), target = try LocalCaseStore.inMemory(), package = try EditorialPackage.validate(files: f.package().files)
            _ = try target.importEditorialPackage(package)
            let before = try XCTUnwrap(target.loadCase(id: f.base.politicalCase.id))
            XCTAssertThrowsError(try target.importEditorialPackage(package)) { XCTAssertEqual($0 as? EditorialPackageError, .caseAlreadyExists) }
            XCTAssertEqual(try PortableCaseArchiveV1(XCTUnwrap(target.loadCase(id: f.base.politicalCase.id))), try PortableCaseArchiveV1(before))
        }
    }
    func testSharedIdenticalMethodologyDoesNotMergeCases() async throws {
        try await MainActor.run {
            let a = try PackageFixture(), b = try PackageFixture(), target = try LocalCaseStore.inMemory()
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: a.package().files))
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: b.package().files))
            XCTAssertEqual(try target.listCases().count, 2)
            XCTAssertEqual(try target.loadCase(id: a.base.politicalCase.id)?.methodologies, [try MethodologyV1.version()])
        }
    }
    func testSharedIDWithDifferentActorRollsBackEntireImport() async throws {
        try await MainActor.run {
            let a = try PackageFixture(), b = try PackageFixture(), target = try LocalCaseStore.inMemory()
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: a.package().files))
            var dto = CaseGraphDTO(try b.context())
            let i = try XCTUnwrap(dto.actors.firstIndex { $0.id.value == b.base.speaker.id.rawValue })
            dto.actors[i].id = StoredID(a.base.speaker.id, kind: "Actor"); dto.actors[i].name = "Synthetic different name"
            dto.promiseRevisions[0].speaker.content = .known(StoredID(a.base.speaker.id, kind: "Actor"))
            let contents = try EditorialPackage.create(graph: dto.domain(), evaluationID: b.base.evaluation.id, scriptID: b.script.id)
            XCTAssertThrowsError(try target.importEditorialPackage(EditorialPackage.validate(files: contents.files)))
            XCTAssertEqual(try target.listCases().count, 1); XCTAssertNil(try target.loadCase(id: b.base.politicalCase.id))
            XCTAssertEqual(try target.loadCase(id: a.base.politicalCase.id)?.find(a.base.speaker.id), a.base.speaker)
        }
    }
    func testImportRetainsAuditIDsAndOriginalTimes() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), target = try LocalCaseStore.inMemory()
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: f.package().files))
            XCTAssertEqual(try target.loadCase(id: f.base.politicalCase.id)?.auditEntries, try f.context().auditEntries)
        }
    }
    func testImportPreservesApprovalsAndStatementReviews() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), target = try LocalCaseStore.inMemory()
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: f.package().files))
            let graph = try XCTUnwrap(target.loadCase(id: f.base.politicalCase.id))
            XCTAssertEqual(graph.find(f.script.id), f.script)
            XCTAssertEqual(graph.statements.sorted { $0.position < $1.position }, f.statements)
            XCTAssertEqual(graph.caseEvaluations[0].approval, f.base.evaluation.approval)
        }
    }
    func testExportDoesNotWriteDomainAuditOrAlterCase() async throws {
        try await MainActor.run {
            let f = try PackageFixture(), store = try LocalCaseStore.inMemory(); try store.saveCase(f.context())
            let before = try XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))
            _ = try EditorialPackage.create(graph: before, evaluationID: f.base.evaluation.id, scriptID: f.script.id)
            XCTAssertEqual(try PortableCaseArchiveV1(XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))), try PortableCaseArchiveV1(before))
        }
    }
    func testImportPreservesHistoricalRevisionsInFreshStore() async throws {
        try await MainActor.run {
            let f = try PackageFixture(); var dto = CaseGraphDTO(try f.context())
            var oldPromise = dto.promiseRevisions[0]; oldPromise.id.value = UUID(); dto.promiseRevisions[0].metadata.number = 2; dto.promiseRevisions.append(oldPromise)
            var oldCriterion = dto.criterionRevisions[0]; oldCriterion.id.value = UUID(); oldCriterion.promiseRevisionID = oldPromise.id
            dto.criterionRevisions[0].metadata.number = 2; dto.criterionRevisions.append(oldCriterion)
            var oldAction = dto.actionRevisions[0]; oldAction.id.value = UUID(); dto.actionRevisions[0].metadata.number = 2; dto.actionRevisions.append(oldAction)
            let graph = try dto.domain(), target = try LocalCaseStore.inMemory()
            let contents = try EditorialPackage.create(graph: graph, evaluationID: f.base.evaluation.id, scriptID: f.script.id)
            _ = try target.importEditorialPackage(EditorialPackage.validate(files: contents.files))
            let imported = try XCTUnwrap(target.loadCase(id: f.base.politicalCase.id))
            XCTAssertEqual(try PortableCaseArchiveV1(imported), try PortableCaseArchiveV1(graph))
            XCTAssertEqual(imported.promiseRevisions.count, 2); XCTAssertEqual(imported.criterionRevisions.count, 2); XCTAssertEqual(imported.actionRevisions.count, 2)
        }
    }
}

private func packageHistoryContext(_ f: PackageFixture) throws -> DomainContext {
    var a = CaseGraphDTO(try f.context())
    var promise = a.promiseRevisions[0]; promise.id.value = UUID()
    var criterion = a.criterionRevisions[0]; criterion.id.value = UUID(); criterion.promiseRevisionID = promise.id
    var action = a.actionRevisions[0]; action.id.value = UUID()
    a.promiseRevisions[0].metadata.number = 2; a.criterionRevisions[0].metadata.number = 2; a.actionRevisions[0].metadata.number = 2
    a.promiseRevisions.append(promise); a.criterionRevisions.append(criterion); a.actionRevisions.append(action)
    var snapshot = a.caseRevisions[0]; snapshot.id.value = UUID()
    a.caseRevisions[0].metadata.number = 2; a.caseRevisions.append(snapshot)
    var oldEvaluation = a.caseEvaluations[0]; oldEvaluation.id.value = UUID(); oldEvaluation.caseRevisionID = snapshot.id; oldEvaluation.status = "superseded"
    var child = a.criterionEvaluations[0]; child.id.value = UUID(); child.caseEvaluationID = oldEvaluation.id
    oldEvaluation.criterionEvaluationIDs = [child.id]
    a.caseEvaluations[0].replacesEvaluationID = oldEvaluation.id
    a.caseEvaluations.append(oldEvaluation); a.criterionEvaluations.append(child)
    var script = a.scripts[0]; script.id.value = UUID(); script.caseEvaluationID = oldEvaluation.id; script.version = 1; script.status = "superseded"
    var statement = a.statements[0]; statement.id.value = UUID(); statement.scriptDraftID = script.id
    script.statementIDs = [statement.id]
    a.scripts.append(script); a.statements.append(statement)
    var oldAudit = a.auditEntries[0]; oldAudit.id.value = UUID(); oldAudit.target = ReferenceDTO(ObjectReference(kind: .script, id: try script.id.domain(ScriptDraft.self, kind: "ScriptDraft")))
    a.auditEntries.append(oldAudit)
    return try a.domain()
}
