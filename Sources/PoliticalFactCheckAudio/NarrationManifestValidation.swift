import Foundation
import PoliticalFactCheckVideoPlanning

public enum NarrationManifestValidation {
    public static func validate(_ value: NarrationPackageManifestV1, handoff: VideoScriptHandoffV1) throws {
        guard value.schemaVersion == 1 else { throw NarrationError.unsupportedSchema }
        guard value.caseID == handoff.caseID.rawValue, value.evaluationID == handoff.evaluationID.rawValue,
              value.scriptID == handoff.scriptID.rawValue, value.scriptVersion == handoff.scriptVersion,
              value.targetDurationSeconds == handoff.targetDurationSeconds,
              value.styleVersion == NarrationStyleV1.version, value.audioFormat == .wav,
              !value.providerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !value.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.speed.isFinite, (0.85...1.15).contains(value.speed),
              value.requiresAIDisclosure, value.disclosureText == "KI-generierte Stimme",
              value.scenes.count == handoff.scenes.count, !value.scenes.isEmpty,
              value.actualDurationSeconds.isFinite, value.actualDurationSeconds > 0 else { throw NarrationError.invalidManifest }
        var end: Double = 0, totalBytes = 0
        var ids = Set<UUID>(), filenames = Set<String>(), positions = Set<Int>()
        for (scene, source) in zip(value.scenes, handoff.scenes) {
            try safeFilename(scene.relativeFilename)
            guard scene.position == source.position, scene.statementID == source.statementID.rawValue,
                  positions.insert(scene.position).inserted, ids.insert(scene.statementID).inserted,
                  filenames.insert(scene.relativeFilename).inserted,
                  scene.relativeFilename == filename(position: scene.position),
                  scene.byteCount > 0, scene.byteCount <= NarrationLimits.sceneBytes,
                  validHash(scene.sha256), scene.narrationTextSHA256 == WAVInspection.hash(Data(source.narrationText.utf8)),
                  scene.startSeconds == end, scene.endSeconds.isFinite, scene.endSeconds > scene.startSeconds,
                  scene.measuredDurationSeconds.isFinite, scene.measuredDurationSeconds > 0,
                  abs(scene.endSeconds - scene.startSeconds - scene.measuredDurationSeconds) < 0.0000001,
                  scene.estimatedDurationSeconds == source.estimatedDurationSeconds else { throw NarrationError.invalidManifest }
            totalBytes += scene.byteCount; end = scene.endSeconds
        }
        guard totalBytes <= NarrationLimits.packageBytes, abs(end - value.actualDurationSeconds) < 0.0000001,
              value.captionCues == (try SubtitleTimelineV1.build(handoff: handoff, scenes: value.scenes)) else { throw NarrationError.invalidManifest }
    }
    public static func filename(position: Int) -> String { String(format: "scene-%03ld.wav", position) }
    static func safeFilename(_ value: String) throws {
        guard !value.isEmpty, value == URL(fileURLWithPath: value).lastPathComponent,
              !value.contains("/"), !value.contains("\\"), !value.contains(".."), !value.contains(":"), !value.contains("\0") else { throw NarrationError.unsafePath }
    }
    static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
