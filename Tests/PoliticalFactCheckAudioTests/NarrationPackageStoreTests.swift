import Foundation
import XCTest
import PoliticalFactCheckCore
import PoliticalFactCheckVideoPlanning
@testable import PoliticalFactCheckAudio

final class NarrationPackageStoreTests: XCTestCase {
    @MainActor private func setup() throws -> (URL, NarrationPackageStore, VideoScriptHandoffV1) {
        let root = try audioTestDirectory()
        return (root, NarrationPackageStore(root: root), try audioHandoff())
    }
    private func cleanup(_ root: URL) { try? FileManager.default.removeItem(at: root) }
    private func assertNoTemporaryFiles(_ root: URL, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".tmp-") }, file: file, line: line)
    }
    private func mutateManifest(_ package: NarrationPackageV1, _ change: (inout [String: Any]) -> Void) throws {
        let url = package.directory.appendingPathComponent("manifest.json")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        change(&object)
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
    }
    @MainActor func testPublishesOnlyCompletePackageAndRemovesTemporaryDirectory() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        var progress: [Int] = [], validations = 0
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 20),
            progress: { current, total in
                progress.append(current); XCTAssertEqual(total, handoff.scenes.count)
                XCTAssertFalse(store.exists(for: handoff))
            }, validateCurrent: { validations += 1 })
        XCTAssertEqual(progress, [1, 2]); XCTAssertEqual(validations, 2)
        XCTAssertEqual(package.directory, store.directory(for: handoff)); XCTAssertTrue(store.exists(for: handoff))
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: package.directory.path)), ["manifest.json", "scene-000.wav", "scene-001.wav"])
        try assertNoTemporaryFiles(root)
    }
    @MainActor func testFreshStoreReopensIdenticalManifestAndChecksEveryByteHash() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let before = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let after = try XCTUnwrap(NarrationPackageStore(root: root).load(handoff: handoff))
        XCTAssertEqual(after, before)
        for scene in after.manifest.scenes {
            let url = try store.audioURL(package: after, scenePosition: scene.position, handoff: handoff)
            let bytes = try Data(contentsOf: url)
            XCTAssertEqual(WAVInspection.hash(bytes), scene.sha256); XCTAssertEqual(bytes.count, scene.byteCount)
        }
        let json = try String(contentsOf: after.directory.appendingPathComponent("manifest.json"))
        XCTAssertFalse(json.contains(root.path)); XCTAssertFalse(json.contains("OPENAI_API_KEY"))
    }
    @MainActor func testExistingPackageRequiresExplicitRegenerationWithoutCallingProvider() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let original = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let provider = RecordingNarrationProvider()
        do { _ = try await store.generate(handoff: handoff, provider: provider, validateCurrent: {}); XCTFail("Implicit regeneration accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .alreadyExists) }
        let positions = await provider.positions()
        XCTAssertEqual(positions, []); XCTAssertEqual(try store.load(handoff: handoff), original)
    }
    @MainActor func testExplicitRegenerationAtomicallyReplacesCompletePackage() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let old = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 1), validateCurrent: {})
        let fresh = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 20), regenerate: true, validateCurrent: {})
        XCTAssertNotEqual(fresh.manifest.scenes.first?.sha256, old.manifest.scenes.first?.sha256)
        XCTAssertEqual(fresh.manifest.actualDurationSeconds, 40); XCTAssertEqual(try store.load(handoff: handoff), fresh)
        try assertNoTemporaryFiles(root)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: fresh.directory.deletingLastPathComponent().path).contains { $0.hasPrefix(".backup-") })
    }
    @MainActor func testSceneThreeFailureNeverPublishesHalfPackage() async throws {
        let root = try audioTestDirectory(); defer { cleanup(root) }
        let store = NarrationPackageStore(root: root), handoff = try audioHandoff(texts: ["Synthetic first.", "Synthetic second.", "Synthetic third.", "Synthetic fourth."])
        let provider = RecordingNarrationProvider(failAt: 2)
        do { _ = try await store.generate(handoff: handoff, provider: provider, validateCurrent: {}); XCTFail("Failed generation accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .serviceUnavailable) }
        let positions = await provider.positions()
        XCTAssertEqual(positions, [0, 1, 2]); XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
    }
    @MainActor func testFailedRegenerationPreservesPriorCompletePackage() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let old = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        do { _ = try await store.generate(handoff: handoff, provider: RecordingNarrationProvider(failAt: 1), regenerate: true, validateCurrent: {}); XCTFail("Failure accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .serviceUnavailable) }
        XCTAssertEqual(try store.load(handoff: handoff), old); try assertNoTemporaryFiles(root)
    }
    @MainActor func testCancellationCleansStagingAndPreservesPreviousPackage() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let old = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let started = expectation(description: "Offline synthesis started")
        let task = Task { @MainActor in
            try await store.generate(handoff: handoff, provider: WaitingNarrationProvider(started: { started.fulfill() }), regenerate: true, validateCurrent: {})
        }
        await fulfillment(of: [started], timeout: 5); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled synthesis published") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try store.load(handoff: handoff), old); try assertNoTemporaryFiles(root)
    }
    @MainActor func testFreshValidationFailureCleansAllSuccessfulScenesBeforePublication() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        var validations = 0
        do {
            _ = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {
                validations += 1; if validations == 2 { throw NarrationError.staleInput }
            }); XCTFail("Stale input published")
        } catch { XCTAssertEqual(error as? NarrationError, .staleInput) }
        XCTAssertEqual(validations, 2); XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
    }
    @MainActor func testInitialValidationFailureDoesNotCallProviderOrCreateFiles() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let provider = RecordingNarrationProvider()
        do { _ = try await store.generate(handoff: handoff, provider: provider, validateCurrent: { throw NarrationError.staleInput }); XCTFail("Invalid input accepted") }
        catch { XCTAssertEqual(error as? NarrationError, .staleInput) }
        let positions = await provider.positions()
        XCTAssertTrue(positions.isEmpty); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])
    }
    @MainActor func testRequestsAreSerialAndKeepExactScenePositionStatementAndText() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let provider = RecordingNarrationProvider()
        _ = try await store.generate(handoff: handoff, provider: provider, validateCurrent: {})
        let requests = await provider.requests()
        XCTAssertEqual(requests.map { $0.scenePosition }, handoff.scenes.map { $0.position })
        XCTAssertEqual(requests.map { $0.statementID }, handoff.scenes.map { $0.statementID })
        XCTAssertEqual(requests.map { $0.text }, handoff.scenes.map { $0.narrationText })
        let maximum = await provider.maximumConcurrent(); XCTAssertEqual(maximum, 1)
    }
    @MainActor func testNonAudioAndUnsupportedWAVNeverPublish() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        // Correct RIFF length and WAVE marker, but no fmt/data chunks: decoder must reject it.
        let invalid = Data([82, 73, 70, 70, 4, 0, 0, 0, 87, 65, 86, 69])
        for bytes in [Data(), Data("synthetic non-audio".utf8), invalid] {
            do { _ = try await store.generate(handoff: handoff, provider: BytesNarrationProvider(bytes: bytes), validateCurrent: {}); XCTFail("Invalid WAV published") }
            catch { XCTAssertTrue(error is NarrationError) }
            XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
        }
    }
    @MainActor func testPerSceneByteLimitRejectsBeforeWriting() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        do { _ = try await store.generate(handoff: handoff, provider: BytesNarrationProvider(bytes: Data(repeating: 0, count: NarrationLimits.sceneBytes + 1)), validateCurrent: {}); XCTFail("Oversize published") }
        catch { XCTAssertEqual(error as? NarrationError, .responseTooLarge) }
        XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
    }
    @MainActor func testTotalPackageByteLimitCleansAlreadyWrittenScenes() async throws {
        let root = try audioTestDirectory(); defer { cleanup(root) }
        let store = NarrationPackageStore(root: root), handoff = try audioHandoff(texts: (0..<9).map { "Synthetic scene \($0)." })
        // ~16 MB each, below per-scene cap; the ninth would exceed 128 MiB in total.
        do { _ = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 500), validateCurrent: {}); XCTFail("Oversize package published") }
        catch { XCTAssertEqual(error as? NarrationError, .responseTooLarge) }
        XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
    }
    @MainActor func testTamperedAudioHashIsRejectedWithoutRepair() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let url = package.directory.appendingPathComponent(package.manifest.scenes[0].relativeFilename)
        var bytes = try Data(contentsOf: url); bytes[bytes.count - 1] ^= 1; try bytes.write(to: url)
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .hashMismatch) }
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    @MainActor func testMissingSceneIsRejectedWithoutRepair() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        try FileManager.default.removeItem(at: package.directory.appendingPathComponent(package.manifest.scenes[0].relativeFilename))
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .missingScene) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: package.directory.appendingPathComponent("manifest.json").path))
    }
    @MainActor func testManifestRejectsTraversalAndAbsolutePaths() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let original = try Data(contentsOf: package.directory.appendingPathComponent("manifest.json"))
        for path in ["../scene.wav", "/tmp/scene.wav", "file:///Users/synthetic/scene.wav", "folder/scene.wav", "folder\\scene.wav"] {
            try original.write(to: package.directory.appendingPathComponent("manifest.json"))
            try mutateManifest(package) { object in
                var scenes = object["scenes"] as! [[String: Any]]; scenes[0]["relativeFilename"] = path; object["scenes"] = scenes
            }
            XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .unsafePath) }
        }
    }
    @MainActor func testAudioSymlinkCannotEscapeMediaRoot() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let path = package.directory.appendingPathComponent(package.manifest.scenes[0].relativeFilename)
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data(contentsOf: path).write(to: outside); try FileManager.default.removeItem(at: path)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: outside)
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .unsafePath) }
    }
    @MainActor func testUnsupportedSchemaAndUnknownFieldsAreRejected() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let original = try Data(contentsOf: package.directory.appendingPathComponent("manifest.json"))
        try mutateManifest(package) { $0["schemaVersion"] = 2 }
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .unsupportedSchema) }
        try original.write(to: package.directory.appendingPathComponent("manifest.json"))
        try mutateManifest(package) { $0["unknown"] = "synthetic" }
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
    }
    @MainActor func testDisclosureAndTextDerivedCaptionTamperingAreRejected() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let original = try Data(contentsOf: package.directory.appendingPathComponent("manifest.json"))
        try mutateManifest(package) { $0["requiresAIDisclosure"] = false }
        XCTAssertThrowsError(try store.load(handoff: handoff))
        try original.write(to: package.directory.appendingPathComponent("manifest.json"))
        try mutateManifest(package) { object in
            var cues = object["captionCues"] as! [[String: Any]]; cues[0]["text"] = "Synthetic invented replacement"; object["captionCues"] = cues
        }
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
    }
    @MainActor func testNarrationTextHashCannotBeSubstituted() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        try mutateManifest(package) { object in
            var scenes = object["scenes"] as! [[String: Any]]; scenes[0]["narrationTextSHA256"] = String(repeating: "0", count: 64); object["scenes"] = scenes
        }
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
    }
    @MainActor func testUnknownVoiceAndCorruptManifestAreControlled() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        try mutateManifest(package) { $0["voice"] = "synthetic-custom-voice" }
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
        try Data("invalid synthetic manifest".utf8).write(to: package.directory.appendingPathComponent("manifest.json"))
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
    }
    @MainActor func testAnotherScriptIDDoesNotResolveHistoricalAudio() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let old = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let other = try audioHandoff()
        XCTAssertNil(try store.load(handoff: other)); XCTAssertTrue(FileManager.default.fileExists(atPath: old.directory.path))
        XCTAssertFalse(old.readyForRendering(handoff: other))
    }
    @MainActor func testDestinationFileCollisionIsNotDestroyed() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let path = store.directory(for: handoff), bytes = Data("Synthetic existing file".utf8)
        try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: path)
        do { _ = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), regenerate: true, validateCurrent: {}); XCTFail("Collision overwritten") }
        catch { XCTAssertEqual(error as? NarrationError, .collision) }
        XCTAssertEqual(try Data(contentsOf: path), bytes); try assertNoTemporaryFiles(root)
    }
    @MainActor func testExtraUnreferencedFileIsRejected() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        try Data().write(to: package.directory.appendingPathComponent("unexpected.wav"))
        XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertEqual($0 as? NarrationError, .invalidManifest) }
    }
    @MainActor func testWrongSceneReferenceByteCountAndMeasuredTimeAreRejected() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(), validateCurrent: {})
        let manifestURL = package.directory.appendingPathComponent("manifest.json"), original = try Data(contentsOf: manifestURL)
        for field in ["statementID", "byteCount", "measuredDurationSeconds", "startSeconds"] {
            try original.write(to: manifestURL)
            try mutateManifest(package) { object in
                var scenes = object["scenes"] as! [[String: Any]]
                switch field {
                case "statementID": scenes[0][field] = UUID().uuidString
                case "byteCount": scenes[0][field] = 1
                default: scenes[0][field] = 99.0
                }
                object["scenes"] = scenes
            }
            XCTAssertThrowsError(try store.load(handoff: handoff)) { XCTAssertTrue($0 is NarrationError) }
        }
    }
    @MainActor func testAllControlledProviderErrorsLeaveNoCompleteOrTemporaryPackage() async throws {
        let (root, store, handoff) = try setup(); defer { cleanup(root) }
        for error in [NarrationError.missingAPIKey, .badRequest, .authenticationFailed, .permissionDenied, .timeout,
                      .rateLimited, .serviceUnavailable, .transportFailure, .emptyResponse, .responseTooLarge, .corruptWAV] {
            do { _ = try await store.generate(handoff: handoff, provider: FailedNarrationProvider(error: error), validateCurrent: {}); XCTFail("Provider error published") }
            catch let actual { XCTAssertEqual(actual as? NarrationError, error) }
            XCTAssertFalse(store.exists(for: handoff)); try assertNoTemporaryFiles(root)
        }
    }
}

private actor RecordingNarrationProvider: NarrationProvider {
    nonisolated var identifier: NonEmptyText { try! NonEmptyText("synthetic-recording-narration") }
    nonisolated let model = "synthetic-test-wav"
    private let failAt: Int?
    private var captured: [NarrationRequest] = [], concurrent = 0, maximum = 0
    init(failAt: Int? = nil) { self.failAt = failAt }
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        concurrent += 1; maximum = max(maximum, concurrent); defer { concurrent -= 1 }
        captured.append(request); await Task.yield()
        if request.scenePosition == failAt { throw NarrationError.serviceUnavailable }
        return try await FakeNarrationProvider(durationSeconds: 1).synthesize(request: request)
    }
    func requests() -> [NarrationRequest] { captured }
    func positions() -> [Int] { captured.map { $0.scenePosition } }
    func maximumConcurrent() -> Int { maximum }
}
private struct WaitingNarrationProvider: NarrationProvider {
    let started: () -> Void
    var identifier: NonEmptyText { try! NonEmptyText("synthetic-waiting-narration") }
    let model = "synthetic-test-wav"
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        started(); try await Task.sleep(nanoseconds: 60_000_000_000)
        return try await FakeNarrationProvider().synthesize(request: request)
    }
}
private struct BytesNarrationProvider: NarrationProvider {
    let bytes: Data
    var identifier: NonEmptyText { try! NonEmptyText("synthetic-invalid-audio") }
    let model = "synthetic-test-wav"
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio { NarrationAudio(bytes: bytes) }
}
private struct FailedNarrationProvider: NarrationProvider {
    let error: NarrationError
    var identifier: NonEmptyText { try! NonEmptyText("synthetic-error-narration") }
    let model = "synthetic-test-wav"
    func synthesize(request: NarrationRequest) async throws -> NarrationAudio { throw error }
}
