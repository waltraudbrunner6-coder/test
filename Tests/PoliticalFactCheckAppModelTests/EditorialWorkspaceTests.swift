import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckPersistence
import PoliticalFactCheckAppModel
import PoliticalFactCheckExport

final class EditorialWorkspaceTests: XCTestCase {
    @MainActor func testApprovedPublicationSummaryAvailable() throws {
        let f = try PackageFixture(), (model, _, defaults) = try workspace(f)
        defer { cleanup(defaults) }
        let summary = try XCTUnwrap(model.editorialExportSummary(scriptID: f.script.id))
        XCTAssertEqual(summary.scriptStatus, .approved); XCTAssertEqual(summary.statementCount, 2)
        XCTAssertEqual(summary.schemaVersion, 1); XCTAssertEqual(summary.sourceCount, 1)
    }
    @MainActor func testDraftScriptHasNoExportActionSummary() throws {
        let f = try PackageFixture(); var dto = CaseGraphDTO(try f.context())
        dto.scripts[0].status = "draft"; dto.scripts[0].approval = nil
        let store = try LocalCaseStore.inMemory(); try store.saveCase(dto.domain())
        let defaults = isolatedDefaults(); defer { cleanup(defaults) }
        let model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertNil(model.editorialExportSummary(scriptID: f.script.id))
    }
    @MainActor func testExportWritesOnlyExplicitSelectedLocation() throws {
        let f = try PackageFixture(), (model, store, defaults) = try workspace(f)
        let root = editorialTemporaryDirectory(); defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Synthetic.politicalfactcheck"), before = try XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))
        XCTAssertTrue(model.exportEditorialPackage(scriptID: f.script.id, to: url))
        XCTAssertEqual(try EditorialPackageIO.read(from: url).summary.caseID, f.base.politicalCase.id)
        XCTAssertEqual(try PortableCaseArchiveV1(XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))), try PortableCaseArchiveV1(before))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["Synthetic.politicalfactcheck"])
    }
    @MainActor func testImportPreviewDoesNotSaveUntilConfirmation() throws {
        let f = try PackageFixture(), (url, root) = try exportedFixture(f)
        let store = try LocalCaseStore.inMemory(), defaults = isolatedDefaults(); defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        let model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertTrue(model.prepareEditorialImport(from: url)); XCTAssertEqual(model.editorialImportPreview?.caseID, f.base.politicalCase.id)
        XCTAssertTrue(try store.listCases().isEmpty)
        XCTAssertTrue(model.confirmEditorialImport())
        XCTAssertEqual(model.selectedCaseID, f.base.politicalCase.id)
        XCTAssertNil(model.editorialImportPreview)
        XCTAssertEqual(try PortableCaseArchiveV1(XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))), try f.archive())
    }
    @MainActor func testCancelImportDoesNotSave() throws {
        let f = try PackageFixture(), (url, root) = try exportedFixture(f)
        let store = try LocalCaseStore.inMemory(), defaults = isolatedDefaults(); defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        let model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertTrue(model.prepareEditorialImport(from: url)); model.dismissEditorialImport()
        XCTAssertFalse(model.confirmEditorialImport()); XCTAssertTrue(try store.listCases().isEmpty)
    }
    @MainActor func testAlreadyPresentCaseHasReadableErrorAndNoOverwrite() throws {
        let f = try PackageFixture(), (model, store, defaults) = try workspace(f), (url, root) = try exportedFixture(f)
        defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        XCTAssertFalse(model.prepareEditorialImport(from: url))
        XCTAssertEqual(model.errorMessage, "Dieser Fall ist bereits vorhanden.")
        XCTAssertEqual(try store.listCases().count, 1)
        XCTAssertEqual(try PortableCaseArchiveV1(XCTUnwrap(store.loadCase(id: f.base.politicalCase.id))), try f.archive())
    }
    @MainActor func testTamperedPackageShowsErrorAndDoesNotPersistAnything() throws {
        let f = try PackageFixture(), (url, root) = try exportedFixture(f)
        let store = try LocalCaseStore.inMemory(), defaults = isolatedDefaults(); defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        try Data("Synthetic tampering".utf8).write(to: url.appendingPathComponent("script.md"))
        let model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertFalse(model.prepareEditorialImport(from: url)); XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.editorialImportPreview); XCTAssertTrue(try store.listCases().isEmpty)
    }
    @MainActor func testPackageChangedAfterPreviewBlocksImport() throws {
        let f = try PackageFixture(), (url, root) = try exportedFixture(f)
        let store = try LocalCaseStore.inMemory(), defaults = isolatedDefaults(); defer { cleanup(defaults); try? FileManager.default.removeItem(at: root) }
        let model = CaseWorkspaceModel(store: store, defaults: defaults)
        XCTAssertTrue(model.prepareEditorialImport(from: url))
        try Data("Synthetic later tampering".utf8).write(to: url.appendingPathComponent("case-archive.json"))
        XCTAssertFalse(model.confirmEditorialImport()); XCTAssertTrue(try store.listCases().isEmpty)
    }
    @MainActor func testWriteErrorDisplayedWithoutInternalDump() throws {
        let f = try PackageFixture(), (model, _, defaults) = try workspace(f)
        defer { cleanup(defaults) }
        XCTAssertFalse(model.exportEditorialPackage(scriptID: f.script.id, to: URL(fileURLWithPath: "/missing-synthetic-parent/Synthetic.politicalfactcheck")))
        XCTAssertEqual(model.errorMessage, "Das Redaktionspaket konnte nicht vollständig geschrieben werden.")
        XCTAssertFalse(model.errorMessage?.contains("missing-synthetic-parent") == true)
    }
    func testAllExportErrorsHaveControlledReadableMessages() {
        for error in [EditorialPackageError.evaluationNotApproved, .evaluationNeedsReview, .scriptNotApproved,
            .scriptEvaluationMismatch, .invalidScript, .unsupportedVersion, .missingFile, .hashConflict, .methodologyConflict,
            .invalidJSON, .invalidReference, .invalidDomain, .caseAlreadyExists, .nonPortableAttachment,
            .sensitiveContent, .writeFailure, .readFailure, .invalidPackage, .destinationExists] {
            XCTAssertFalse(WorkspaceErrorMessage.describe(error).isEmpty)
        }
    }
    @MainActor private func workspace(_ f: PackageFixture) throws -> (CaseWorkspaceModel, LocalCaseStore, UserDefaults) {
        let store = try LocalCaseStore.inMemory(); try store.saveCase(f.context())
        let defaults = isolatedDefaults()
        return (CaseWorkspaceModel(store: store, defaults: defaults), store, defaults)
    }
    private func isolatedDefaults() -> UserDefaults {
        let suite = "SyntheticEditorialWorkspace-\(UUID().uuidString)", defaults = UserDefaults(suiteName: suite)!
        defaults.set(suite, forKey: "editorialTestSuite"); return defaults
    }
    private func cleanup(_ defaults: UserDefaults) { defaults.removePersistentDomain(forName: defaults.string(forKey: "editorialTestSuite")!) }
    private func exportedFixture(_ f: PackageFixture) throws -> (URL, URL) {
        let root = editorialTemporaryDirectory(), url = root.appendingPathComponent("Synthetic.politicalfactcheck")
        try EditorialPackageIO.write(f.package(), to: url); return (url, root)
    }
}
private func editorialTemporaryDirectory() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("SyntheticEditorial-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
}
