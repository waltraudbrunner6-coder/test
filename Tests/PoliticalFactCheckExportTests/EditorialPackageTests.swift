import Foundation
import XCTest
import PoliticalFactCheckCore
@testable import PoliticalFactCheckExport

final class EditorialPackageTests: XCTestCase {
    func testApprovedEvaluationAndScriptPassGate() throws {
        let f = try EditorialFixture(), package = try f.package()
        XCTAssertEqual(package.manifest.schemaVersion, 1)
        XCTAssertEqual(try EditorialPackage.validate(files: package.files).summary.scriptStatus, .approved)
    }
    func testDraftEvaluationBlocked() throws { try evaluationGate("draft", .evaluationNotApproved) }
    func testNeedsReviewEvaluationBlocked() throws { try evaluationGate("needsReview", .evaluationNotApproved) }
    func testReviewRequiredEvaluationBlocked() throws { try evaluationGate("reviewRequired", .evaluationNeedsReview) }
    func testSupersededEvaluationBlocked() throws { try evaluationGate("superseded", .evaluationNotApproved) }
    func testDraftScriptBlocked() throws { try scriptGate("draft") }
    func testNeedsReviewScriptBlocked() throws { try scriptGate("needsReview") }
    func testSupersededScriptBlocked() throws { try scriptGate("superseded") }
    func testMissingEvaluationApprovalBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.caseEvaluations[0].approval = nil
        assertCreateFails(f, a, .evaluationNotApproved)
    }
    func testRejectedExcerptCannotSupportPublishedFact() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.excerpts[0].state = "rejected"
        assertCreateFails(f, a, .invalidScript)
    }
    func testMissingScriptApprovalBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.scripts[0].approval = nil
        assertCreateFails(f, a, .scriptNotApproved)
    }
    func testUnreviewedStatementBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.statements[0].review = nil
        assertCreateFails(f, a, .invalidScript)
    }
    func testFactWithoutExcerptBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive()
        let i = try XCTUnwrap(a.graph.statements.firstIndex { $0.kind == "fact" }); a.graph.statements[i].excerptIDs = []
        assertCreateFails(f, a, .invalidScript)
    }
    func testScriptEvaluationMismatchBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.scripts[0].caseEvaluationID.value = UUID()
        assertCreateFails(f, a, .scriptEvaluationMismatch)
    }
    func testManifestIDsAndVersions() throws {
        let f = try EditorialFixture(), m = try f.package().manifest
        XCTAssertEqual(m.packageType, "PoliticalFactCheck Editorial Package"); XCTAssertEqual(m.exportFormatVersion, "1")
        XCTAssertEqual(m.caseID, f.base.politicalCase.id.rawValue); XCTAssertEqual(m.caseEvaluationID, f.base.evaluation.id.rawValue)
        XCTAssertEqual(m.caseRevisionID, f.base.snapshot.id.rawValue); XCTAssertEqual(m.scriptDraftID, f.script.id.rawValue)
        XCTAssertEqual(m.scriptVersion, 2); XCTAssertEqual(m.methodologyVersionID, try MethodologyV1.version().id.rawValue)
    }
    func testManifestListsExactlySevenPayloads() throws {
        let p = try EditorialFixture().package()
        XCTAssertEqual(p.manifest.files.map { $0.filename }, EditorialPackage.payloadFilenames)
        XCTAssertEqual(p.files.count, 8)
    }
    func testEveryDigestAndByteCountMatchesActualBytes() throws {
        let p = try EditorialFixture().package()
        for entry in p.manifest.files {
            let bytes = try XCTUnwrap(p.files[entry.filename])
            XCTAssertEqual(entry.sha256, EditorialPackage.sha256(bytes)); XCTAssertEqual(entry.byteCount, bytes.count)
        }
    }
    func testSHA256KnownVector() { XCTAssertEqual(EditorialPackage.sha256(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") }
    func testCanonicalMethodologyMatchesFrozenHashAndDocument() throws {
        let bytes = try EditorialPackage.canonicalMethodology()
        XCTAssertEqual(EditorialPackage.sha256(bytes), try MethodologyV1.version().hash?.sha256)
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        XCTAssertEqual(bytes, try Data(contentsOf: root.appendingPathComponent("docs/methodology-v1.0.md")))
    }
    func testConflictingMethodologyBlocksExport() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.methodologies[0].hash = String(repeating: "0", count: 64)
        assertCreateFails(f, a, .methodologyConflict)
    }
    func testArchiveEncodeDecodePreservesEveryDomainValue() throws {
        let f = try EditorialFixture(), a = try f.archive()
        let b = try PortableJSON.decode(PortableCaseArchiveV1.self, from: PortableJSON.encode(a))
        XCTAssertEqual(a, b); XCTAssertEqual(try PortableCaseArchiveV1(b.domain()), a)
        XCTAssertTrue(try DomainValidator.validate(b.domain()).isValid)
    }
    func testDatesRetainSubMillisecondPrecisionExactly() throws {
        let f = try EditorialFixture(), p = try f.package(), imported = try EditorialPackage.validate(files: p.files).domain()
        XCTAssertEqual(imported.find(f.script.id)?.createdAt, f.script.createdAt)
        XCTAssertEqual(imported.find(f.script.id)?.approval, f.script.approval)
        XCTAssertEqual(imported.auditEntries[0].occurredAt, f.script.approval!.reviewedAt)
        let archiveText = String(data: p.files["case-archive.json"]!, encoding: .utf8)!
        XCTAssertTrue(archiveText.contains("referenceSeconds")); XCTAssertTrue(archiveText.contains("Z\""))
    }
    func testMismatchedUTCAndExactDateRejected() throws {
        let f = try EditorialFixture(), bytes = try PortableJSON.encode(f.archive())
        let text = String(data: bytes, encoding: .utf8)!.replacingOccurrences(of: "2021-", with: "2020-")
        XCTAssertThrowsError(try PortableJSON.decode(PortableCaseArchiveV1.self, from: Data(text.utf8)))
    }
    func testPortableIDsAndEnumsPreserved() throws {
        let f = try EditorialFixture(), graph = try EditorialPackage.validate(files: f.package().files).domain()
        XCTAssertEqual(graph.evidenceLinks, [f.base.evidence]); XCTAssertEqual(graph.caseRevisions, [f.base.snapshot])
        XCTAssertEqual(graph.find(f.script.id), f.script); XCTAssertEqual(graph.statements.sorted { $0.position < $1.position }, f.statements)
    }
    func testDeterministicIdenticalInputAndTime() throws {
        let f = try EditorialFixture(); XCTAssertEqual(try f.package().files, try f.package().files)
    }
    func testOnlyManifestChangesWithExportTime() throws {
        let f = try EditorialFixture(), a = try f.package()
        let b = try EditorialPackage.create(graph: f.context(), evaluationID: f.base.evaluation.id, scriptID: f.script.id, exportedAt: Date(timeIntervalSince1970: 123))
        for name in EditorialPackage.payloadFilenames { XCTAssertEqual(a.files[name], b.files[name]) }
        XCTAssertNotEqual(a.files["manifest.json"], b.files["manifest.json"])
    }
    func testOuterCollectionOrderDoesNotAffectPayloads() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.actors.reverse(); a.graph.statements.reverse()
        let p = try EditorialPackage.create(graph: a.graph.domain(), evaluationID: f.base.evaluation.id, scriptID: f.script.id, exportedAt: try f.package().manifest.exportedAt)
        XCTAssertEqual(p.files, try f.package().files)
    }
    func testManifestUnknownVersionRejected() throws {
        var files = try EditorialFixture().package().files
        files["manifest.json"] = Data(String(data: files["manifest.json"]!, encoding: .utf8)!.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 99").utf8)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .unsupportedVersion) }
    }
    func testMissingPayloadRejected() throws {
        var files = try EditorialFixture().package().files; files.removeValue(forKey: "sources.md")
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .missingFile) }
    }
    func testArchiveByteTamperingRejected() throws {
        var files = try EditorialFixture().package().files; files["case-archive.json"]!.append(32)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .hashConflict) }
    }
    func testIncorrectDigestRejected() throws {
        var files = try EditorialFixture().package().files
        files["manifest.json"] = Data(String(data: files["manifest.json"]!, encoding: .utf8)!.replacingOccurrences(of: "\"sha256\" : \"", with: "\"sha256\" : \"bad").utf8)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .hashConflict) }
    }
    func testMethodologyTamperWithRecomputedFileDigestStillRejected() throws {
        var files = try EditorialFixture().package().files; files["methodology.md"] = Data("Synthetic modified methodology".utf8)
        try rehash(&files)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .methodologyConflict) }
    }
    func testMissingSnapshotReferenceEvenWithValidHashesRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.caseEvaluations[0].caseRevisionID.value = UUID()
        try assertInvalidArchive(f, a)
    }
    func testMissingReviewerEvenWithValidHashesRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.reviewers = []
        try assertInvalidArchive(f, a)
    }
    func testForeignCaseObjectRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.actions[0].caseID.value = UUID()
        try assertInvalidArchive(f, a)
    }
    func testWrongEntityIDKindRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.excerpts[0].sourceVersionID.kind = "Actor"
        try assertInvalidArchive(f, a)
    }
    func testDuplicateEntityIDRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.excerpts.append(a.graph.excerpts[0])
        try assertInvalidArchive(f, a)
    }
    func testUnknownEnumRejected() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.excerpts[0].state = "invented"
        try assertInvalidArchive(f, a)
    }
    func testUnknownArchiveSchemaRejected() throws {
        let f = try EditorialFixture(); var files = try f.package().files
        let a = try PortableJSON.encode(f.archive())
        files["case-archive.json"] = Data(String(data: a, encoding: .utf8)!.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 99").utf8)
        try rehash(&files)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .unsupportedVersion) }
    }
    func testInvalidJSONRejectedEvenWithCorrectHash() throws {
        var files = try EditorialFixture().package().files; files["case-archive.json"] = Data("{broken".utf8); try rehash(&files)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .invalidJSON) }
    }
    func testUnknownJSONFieldsRejected() throws {
        let f = try EditorialFixture(), a = try PortableJSON.encode(f.archive())
        let text = String(data: a, encoding: .utf8)!.replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 1, \"unrecognized\": true")
        XCTAssertThrowsError(try PortableJSON.decode(PortableCaseArchiveV1.self, from: Data(text.utf8)))
    }
    func testReportContainsOnlySelectedApprovedView() throws {
        let f = try EditorialFixture(), report = try PortableJSON.decode(EditorialCaseReportV1.self, from: f.package().files["case-report.json"]!)
        XCTAssertEqual(report.originalPromise.id.value, f.base.promiseRevision.id.rawValue)
        XCTAssertEqual(report.evaluation.id.value, f.base.evaluation.id.rawValue)
        XCTAssertEqual(report.script.id.value, f.script.id.rawValue)
        XCTAssertEqual(report.statementSources[0].excerptKeys, ["EX-1"])
        XCTAssertEqual(report.statementSources[0].evidenceKeys, ["EV-1"])
    }
    func testReportReferenceKeysResolveToExactObjects() throws {
        let f = try EditorialFixture(), report = try PortableJSON.decode(EditorialCaseReportV1.self, from: f.package().files["case-report.json"]!)
        XCTAssertEqual(report.referenceKeys.first { $0.key == "EX-1" }?.id, f.base.excerpt.id.rawValue)
        XCTAssertEqual(report.referenceKeys.first { $0.key == "EV-1" }?.id, f.base.evidence.id.rawValue)
        XCTAssertEqual(report.referenceKeys.first { $0.key == "SRC-1" }?.id, f.base.sourceVersion.id.rawValue)
    }
    func testReportTamperWithValidDigestRejected() throws {
        var files = try EditorialFixture().package().files
        files["case-report.json"] = Data(String(data: files["case-report.json"]!, encoding: .utf8)!.replacingOccurrences(of: "Synthetic case", with: "Synthetic misleading case").utf8)
        try rehash(&files); XCTAssertThrowsError(try EditorialPackage.validate(files: files))
    }
    func testScriptMarkdownHasApprovedTextKindsAndReferences() throws {
        let f = try EditorialFixture(), text = String(data: try f.package().files["script.md"]!, encoding: .utf8)!
        XCTAssertTrue(text.contains(f.statements[0].text.value)); XCTAssertTrue(text.contains("Fact / Tatsache"))
        XCTAssertTrue(text.contains("Interpretation")); XCTAssertTrue(text.contains("EX-1")); XCTAssertTrue(text.contains("Synthetic uncertainty"))
        XCTAssertTrue(text.contains("Planwert, nicht gemessen"))
    }
    func testSourcesMarkdownContainsLocatorAndExactExcerpt() throws {
        let f = try EditorialFixture(), text = String(data: try f.package().files["sources.md"]!, encoding: .utf8)!
        XCTAssertTrue(text.contains(f.base.excerpt.locator.value)); XCTAssertTrue(text.contains(f.base.excerpt.text.value))
        XCTAssertTrue(text.contains("SRC-1")); XCTAssertTrue(text.contains("EX-1")); XCTAssertTrue(text.contains("ScriptStatement-Positionen: 0"))
        XCTAssertTrue(text.contains("2025-")); XCTAssertTrue(text.contains("Abruf:"))
    }
    func testStoryboardDoesNotInventVisualsOrSceneDurations() throws {
        let f = try EditorialFixture(), text = String(data: try f.package().files["storyboard.md"]!, encoding: .utf8)!
        XCTAssertEqual(text.components(separatedBy: "Visualhinweis: Noch festzulegen").count - 1, 2)
        XCTAssertTrue(text.contains("EV-1")); XCTAssertTrue(text.contains("EX-1")); XCTAssertTrue(text.contains("Phase 5"))
        XCTAssertTrue(text.contains(f.statements[1].text.value))
    }
    func testMarkdownTamperEvenWithRecomputedHashRejected() throws {
        var files = try EditorialFixture().package().files; files["script.md"] = Data("Synthetic changed political text".utf8); try rehash(&files)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files)) { XCTAssertEqual($0 as? EditorialPackageError, .invalidPackage) }
    }
    func testNoRuntimeSecretsOrNetworkPayloadsInPackage() throws {
        let files = try EditorialFixture().package().files
        for bytes in files.values {
            let text = String(data: bytes, encoding: .utf8)!
            for forbidden in ["OPENAI_API_KEY", "Authorization", "safety_identifier", "input_text", "test-key-not-real"] { XCTAssertFalse(text.contains(forbidden)) }
        }
    }
    func testAccidentallyPastedCredentialDumpBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.auditEntries[0].reason = "Authorization: Bearer test-key-not-real"
        assertCreateFails(f, a, .sensitiveContent)
    }
    func testLocalAbsoluteAttachmentBlockedWithoutLosingReference() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.sourceVersions[0].localCopyReference = "/Users/synthetic/private.txt"
        assertCreateFails(f, a, .nonPortableAttachment)
        XCTAssertEqual(a.graph.sourceVersions[0].localCopyReference, "/Users/synthetic/private.txt")
    }
    func testFileURLBlocked() throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.sources[0].canonicalURL = "file:///Users/synthetic/source.txt"
        assertCreateFails(f, a, .nonPortableAttachment)
    }
    func testWriteReadDirectoryRoundtrip() throws {
        let f = try EditorialFixture(), root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Synthetic.politicalfactcheck")
        try EditorialPackageIO.write(f.package(), to: url)
        XCTAssertEqual(try EditorialPackageIO.read(from: url).archive, try f.archive())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.path).count, 8)
    }
    func testExistingDestinationNeverOverwritten() throws {
        let f = try EditorialFixture(), root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Synthetic.politicalfactcheck")
        try EditorialPackageIO.write(f.package(), to: url)
        XCTAssertThrowsError(try EditorialPackageIO.write(f.package(), to: url)) { XCTAssertEqual($0 as? EditorialPackageError, .destinationExists) }
        XCTAssertEqual(try EditorialPackageIO.read(from: url).archive, try f.archive())
    }
    func testReadFailureControlled() { XCTAssertThrowsError(try EditorialPackageIO.read(from: URL(fileURLWithPath: "/does-not-exist/synthetic.politicalfactcheck"))) }
    func testWriteFailureLeavesNoPartialPackage() throws {
        let p = try EditorialFixture().package(), root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("missing/Synthetic.politicalfactcheck")
        XCTAssertThrowsError(try EditorialPackageIO.write(p, to: url)); XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    func testSymlinkPayloadRejected() throws {
        let f = try EditorialFixture(), root = temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Synthetic.politicalfactcheck")
        try EditorialPackageIO.write(f.package(), to: url)
        let target = url.appendingPathComponent("script.md"), outside = root.appendingPathComponent("outside.txt")
        try FileManager.default.moveItem(at: target, to: outside)
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
        XCTAssertThrowsError(try EditorialPackageIO.read(from: url))
    }
    private func evaluationGate(_ status: String, _ expected: EditorialPackageError) throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.caseEvaluations[0].status = status
        assertCreateFails(f, a, expected)
    }
    private func scriptGate(_ status: String) throws {
        let f = try EditorialFixture(); var a = try f.archive(); a.graph.scripts[0].status = status
        assertCreateFails(f, a, .scriptNotApproved)
    }
    private func assertCreateFails(_ f: EditorialFixture, _ archive: PortableCaseArchiveV1, _ expected: EditorialPackageError, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try EditorialPackage.create(graph: archive.graph.domain(), evaluationID: f.base.evaluation.id, scriptID: f.script.id), file: file, line: line) { XCTAssertEqual($0 as? EditorialPackageError, expected, file: file, line: line) }
    }
    private func assertInvalidArchive(_ f: EditorialFixture, _ archive: PortableCaseArchiveV1) throws {
        var files = try f.package().files; files["case-archive.json"] = try PortableJSON.encode(archive); try rehash(&files)
        XCTAssertThrowsError(try EditorialPackage.validate(files: files))
    }
}
func temporaryRoot() -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("SyntheticEditorial-\(UUID().uuidString)")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
func rehash(_ files: inout [String: Data]) throws {
    let m = try PortableJSON.decode(EditorialManifestV1.self, from: files["manifest.json"]!)
    let updated = EditorialManifestV1(schemaVersion: m.schemaVersion, packageType: m.packageType, exportFormatVersion: m.exportFormatVersion,
        exportedAt: m.exportedAt, caseID: m.caseID, caseEvaluationID: m.caseEvaluationID, caseRevisionID: m.caseRevisionID,
        scriptDraftID: m.scriptDraftID, scriptVersion: m.scriptVersion, methodologyVersionID: m.methodologyVersionID,
        methodologyVersion: m.methodologyVersion, methodologyHash: m.methodologyHash,
        files: EditorialPackage.payloadFilenames.map { .init(filename: $0, sha256: EditorialPackage.sha256(files[$0]!), byteCount: files[$0]!.count) })
    files["manifest.json"] = try PortableJSON.encode(updated)
}
