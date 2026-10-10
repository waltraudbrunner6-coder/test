import Foundation
import PoliticalFactCheckVideoPlanning

public enum SubtitleTimelineV1 {
    /// Preserve every whitespace-delimited token and its punctuation; normalize only whitespace.
    /// Terminal punctuation ends a cue, otherwise split after ten complete words.
    public static func chunks(_ text: String) -> [String] {
        let words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var result: [String] = [], current: [String] = []
        for word in words {
            current.append(word)
            let terminal = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’»«)]}"))
            if current.count == 10 || terminal.last.map({ ".!?;".contains($0) }) == true {
                result.append(current.joined(separator: " ")); current.removeAll()
            }
        }
        if !current.isEmpty { result.append(current.joined(separator: " ")) }
        return result
    }
    public static func build(handoff: VideoScriptHandoffV1, scenes: [NarrationSceneAudioV1]) throws -> [CaptionCueV1] {
        guard handoff.scenes.count == scenes.count else { throw NarrationError.invalidManifest }
        var cues: [CaptionCueV1] = []
        var previousEnd: Double = 0
        for (source, audio) in zip(handoff.scenes, scenes) {
            guard source.position == audio.position, source.statementID.rawValue == audio.statementID,
                  audio.startSeconds == previousEnd, audio.endSeconds.isFinite, audio.endSeconds > audio.startSeconds,
                  audio.measuredDurationSeconds.isFinite, audio.measuredDurationSeconds > 0,
                  abs(audio.endSeconds - audio.startSeconds - audio.measuredDurationSeconds) < 0.0000001 else { throw NarrationError.invalidManifest }
            let parts = chunks(source.narrationText)
            guard !parts.isEmpty else { throw NarrationError.invalidManifest }
            let weights = parts.map { Double($0.split(whereSeparator: { $0.isWhitespace }).count) }
            let total = weights.reduce(0, +)
            var start = audio.startSeconds
            for (index, part) in parts.enumerated() {
                let end = index == parts.count - 1 ? audio.endSeconds : start + audio.measuredDurationSeconds * weights[index] / total
                cues.append(CaptionCueV1(index: cues.count, statementID: audio.statementID, scenePosition: audio.position,
                    startSeconds: start, endSeconds: end, text: part))
                start = end
            }
            previousEnd = audio.endSeconds
        }
        return cues
    }
}
