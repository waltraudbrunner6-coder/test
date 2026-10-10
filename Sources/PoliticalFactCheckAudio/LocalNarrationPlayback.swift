import Foundation
import AVFoundation

/// Explicit scene playback only. No autoplay and no audio editing/rendering.
@MainActor public final class LocalNarrationPlayback: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    public var onFinished: (() -> Void)?
    public func play(url: URL) throws {
        stop()
        do {
            let value = try AVAudioPlayer(contentsOf: url)
            value.delegate = self
            guard value.prepareToPlay(), value.play() else { throw NarrationError.playbackFailure }
            player = value
        } catch { throw NarrationError.playbackFailure }
    }
    public func stop() { player?.stop(); player = nil }
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let identifier = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == identifier else { return }
            self.stop(); self.onFinished?()
        }
    }
    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let identifier = ObjectIdentifier(player)
        Task { @MainActor [weak self] in
            guard let self, let current = self.player, ObjectIdentifier(current) == identifier else { return }
            self.stop(); self.onFinished?()
        }
    }
}
