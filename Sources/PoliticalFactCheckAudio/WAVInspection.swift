import Foundation
import AVFoundation
import CryptoKit
import PoliticalFactCheckCore

public struct WAVMeasurement: Equatable {
    public let sampleRate: Double
    public let frames: Int64
    public var durationSeconds: Double { Double(frames) / sampleRate }
}
public enum WAVInspection {
    public static func hash(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
    public static func requireHeader(_ bytes: Data) throws {
        guard !bytes.isEmpty else { throw NarrationError.emptyResponse }
        guard bytes.count >= 12 else { throw NarrationError.nonAudioResponse }
        let header = Array(bytes.prefix(12))
        guard Data(header.prefix(4)) == Data("RIFF".utf8),
              Data(header[8..<12]) == Data("WAVE".utf8) else { throw NarrationError.nonAudioResponse }
        // Bound the RIFF container; AVFoundation validates codec/chunks and fully decodes below.
        let size = (0..<4).reduce(UInt32(0)) { $0 | (UInt32(header[4 + $1]) << UInt32($1 * 8)) }
        guard Int(size) + 8 == bytes.count else { throw NarrationError.corruptWAV }
    }
    public static func measure(at url: URL) throws -> WAVMeasurement {
        do {
            let file = try AVAudioFile(forReading: url)
            let rate = file.processingFormat.sampleRate
            guard rate.isFinite, rate > 0, file.length > 0, file.processingFormat.channelCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192) else { throw NarrationError.corruptWAV }
            var decoded: Int64 = 0
            while decoded < file.length {
                try file.read(into: buffer, frameCount: AVAudioFrameCount(min(Int64(8192), file.length - decoded)))
                guard buffer.frameLength > 0 else { throw NarrationError.corruptWAV }
                decoded += Int64(buffer.frameLength)
            }
            let result = WAVMeasurement(sampleRate: rate, frames: decoded)
            guard decoded == file.length, result.durationSeconds.isFinite, result.durationSeconds > 0 else { throw NarrationError.corruptWAV }
            return result
        } catch { throw NarrationError.corruptWAV }
    }
}

/// Deterministic synthetic PCM silence; never speech or a political source.
public struct FakeNarrationProvider: NarrationProvider {
    public var identifier: NonEmptyText { try! NonEmptyText("fake-offline-narration-v1") }
    public let model = "synthetic-pcm-wav-v1"
    public let durationSeconds: Double?
    public init(durationSeconds: Double? = nil) { self.durationSeconds = durationSeconds }
    public func synthesize(request: NarrationRequest) async throws -> NarrationAudio {
        try Task.checkCancellation(); try request.validate()
        let duration = durationSeconds ?? max(0.25, Double(request.text.split(whereSeparator: { $0.isWhitespace }).count) * 0.35 / request.speed)
        return NarrationAudio(bytes: try Self.wav(durationSeconds: duration), contentType: "audio/wav")
    }
    public static func wav(durationSeconds: Double, sampleRate: UInt32 = 16000) throws -> Data {
        guard durationSeconds.isFinite, durationSeconds > 0, sampleRate > 0, sampleRate <= 384000,
              durationSeconds * Double(sampleRate) <= Double((NarrationLimits.sceneBytes - 44) / 2) else { throw NarrationError.invalidRequest }
        let frames = max(1, Int((durationSeconds * Double(sampleRate)).rounded()))
        let count = frames * 2
        var bytes = Data("RIFF".utf8)
        func append32(_ value: UInt32) { var little = value.littleEndian; withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { var little = value.littleEndian; withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) } }
        append32(UInt32(36 + count)); bytes.append(Data("WAVEfmt ".utf8)); append32(16)
        append16(1); append16(1); append32(sampleRate); append32(sampleRate * 2)
        append16(2); append16(16); bytes.append(Data("data".utf8)); append32(UInt32(count))
        bytes.append(Data(repeating: 0, count: count)); return bytes
    }
}
