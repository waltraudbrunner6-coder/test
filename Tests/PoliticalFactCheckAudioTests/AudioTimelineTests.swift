import Foundation
import XCTest
@testable import PoliticalFactCheckAudio

final class AudioTimelineTests: XCTestCase {
    func testFakeAudioIsDeterministicAndHashStable() async throws {
        let provider = FakeNarrationProvider(durationSeconds: 1.25), request = try audioRequest()
        let first = try await provider.synthesize(request: request), second = try await provider.synthesize(request: request)
        XCTAssertEqual(first, second); XCTAssertEqual(WAVInspection.hash(first.bytes), WAVInspection.hash(second.bytes))
        XCTAssertEqual(first.bytes.count, 44 + 40000)
    }
    func testFakeWAVIsFullyReadableWithMeasuredFramesAndRate() throws {
        let root = try audioTestDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("synthetic.wav")
        try FakeNarrationProvider.wav(durationSeconds: 1.25).write(to: file)
        let measured = try WAVInspection.measure(at: file)
        XCTAssertEqual(measured.sampleRate, 16000); XCTAssertEqual(measured.frames, 20000)
        XCTAssertEqual(measured.durationSeconds, 1.25, accuracy: 0.00000001)
    }
    func testInvalidWAVIsRejectedByLocalDecoder() throws {
        let root = try audioTestDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("synthetic.wav"); try Data("Synthetic non-audio".utf8).write(to: file)
        XCTAssertThrowsError(try WAVInspection.measure(at: file)) { XCTAssertEqual($0 as? NarrationError, .corruptWAV) }
    }
    func testFakeInvalidDurationCannotAllocateUnboundedAudio() throws {
        for duration in [Double.nan, Double.infinity, 0, -1, 100000000] { XCTAssertThrowsError(try FakeNarrationProvider.wav(durationSeconds: duration)) }
        XCTAssertThrowsError(try FakeNarrationProvider.wav(durationSeconds: 1, sampleRate: UInt32.max))
    }
    func testShortCaptionRemainsSingleCueText() { XCTAssertEqual(SubtitleTimelineV1.chunks("Synthetic short text"), ["Synthetic short text"]) }
    func testPunctuationSplittingPreservesOriginalWords() {
        XCTAssertEqual(SubtitleTimelineV1.chunks("First synthetic sentence. Second synthetic sentence!"), ["First synthetic sentence.", "Second synthetic sentence!"])
    }
    func testClosingQuotesPreserveTextAndPreferPunctuationBoundary() {
        XCTAssertEqual(SubtitleTimelineV1.chunks("Synthetic quoted end.” Another sentence"), ["Synthetic quoted end.”", "Another sentence"])
    }
    func testLongTextSplitsOnlyAtCompleteWords() {
        let words = (0..<25).map { "synthetic\($0)" }, parts = SubtitleTimelineV1.chunks(words.joined(separator: " "))
        XCTAssertEqual(parts.count, 3); XCTAssertEqual(parts.flatMap { $0.split(separator: " ").map(String.init) }, words)
        XCTAssertTrue(parts.allSatisfy { $0.split(separator: " ").count <= 10 })
    }
    func testWhitespaceNormalizationDoesNotInventOrDropTokens() {
        let value = "  Synthetic\ntext\twith  12,5 units.  "
        XCTAssertEqual(SubtitleTimelineV1.chunks(value).joined(separator: " "), "Synthetic text with 12,5 units.")
    }
    func testEmptyCaptionTextProducesNoCues() { XCTAssertTrue(SubtitleTimelineV1.chunks(" \n ").isEmpty) }
    @MainActor func testMeasuredSceneTimelineIsContiguousAndDifferentFromPlan() async throws {
        let root = try audioTestDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let handoff = try audioHandoff(), store = NarrationPackageStore(root: root)
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 2.25), validateCurrent: {})
        let scenes = package.manifest.scenes
        XCTAssertEqual(scenes[0].startSeconds, 0); XCTAssertEqual(scenes[0].endSeconds, scenes[1].startSeconds)
        XCTAssertEqual(scenes[1].endSeconds, package.manifest.actualDurationSeconds); XCTAssertEqual(package.manifest.actualDurationSeconds, 4.5)
        XCTAssertEqual(scenes.map { $0.position }, handoff.scenes.map { $0.position })
        XCTAssertEqual(scenes.map { $0.estimatedDurationSeconds }, handoff.scenes.map { $0.estimatedDurationSeconds })
        XCTAssertNotEqual(package.manifest.actualDurationSeconds, package.manifest.targetDurationSeconds)
        XCTAssertFalse(package.readyForRendering(handoff: handoff)); XCTAssertEqual(package.manifest.targetDurationSeconds, 45)
    }
    @MainActor func testCaptionTimesUseMeasuredSceneBoundariesWithoutGapsOrOverlaps() async throws {
        let root = try audioTestDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let handoff = try audioHandoff(texts: ["First synthetic phrase. Second synthetic phrase.", (0..<23).map { "word\($0)" }.joined(separator: " ")])
        let package = try await NarrationPackageStore(root: root).generate(handoff: handoff,
            provider: FakeNarrationProvider(durationSeconds: 3), validateCurrent: {})
        let cues = package.manifest.captionCues
        XCTAssertEqual(cues, try SubtitleTimelineV1.build(handoff: handoff, scenes: package.manifest.scenes))
        XCTAssertEqual(cues.first?.startSeconds, 0); XCTAssertEqual(cues.last?.endSeconds, package.manifest.actualDurationSeconds)
        for pair in zip(cues, cues.dropFirst()) { XCTAssertEqual(pair.0.endSeconds, pair.1.startSeconds) }
        for scene in package.manifest.scenes {
            let group = cues.filter { $0.statementID == scene.statementID }
            XCTAssertEqual(group.first?.startSeconds, scene.startSeconds); XCTAssertEqual(group.last?.endSeconds, scene.endSeconds)
            XCTAssertTrue(group.allSatisfy { $0.startSeconds >= scene.startSeconds && $0.endSeconds <= scene.endSeconds && $0.endSeconds > $0.startSeconds })
        }
        XCTAssertEqual(cues.map { $0.index }, Array(0..<cues.count))
        XCTAssertEqual(cues.map { $0.text }.joined(separator: " "), handoff.scenes.map { $0.narrationText }.joined(separator: " "))
    }
    @MainActor func testDisclosureAlwaysPresentAndMeasuredDurationControlsRenderRange() async throws {
        let root = try audioTestDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let handoff = try audioHandoff(), store = NarrationPackageStore(root: root)
        let package = try await store.generate(handoff: handoff, provider: FakeNarrationProvider(durationSeconds: 20), validateCurrent: {})
        XCTAssertEqual(package.manifest.actualDurationSeconds, 40); XCTAssertTrue(package.readyForRendering(handoff: handoff))
        XCTAssertTrue(package.manifest.requiresAIDisclosure); XCTAssertEqual(package.manifest.disclosureText, "KI-generierte Stimme")
        XCTAssertFalse(package.readyForRendering(handoff: nil))
    }
}
