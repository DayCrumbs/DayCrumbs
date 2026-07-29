import AVFoundation
import OSLog
import UIKit

/// Owns app-wide background music playback and keeps AVFoundation details out of views.
@MainActor
final class BackgroundMusicService {
    private enum AudioAsset {
        static let backgroundMusic = "WonderfulBackgroundMusic"
        static let playbackVolume: Float = 0.12
        static let fadeInDuration: TimeInterval = 1.5
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DayCrumbs",
        category: "BackgroundMusic"
    )

    private var player: AVAudioPlayer?

    /// Starts or resumes the looping background track.
    func play() {
        do {
            if player == nil {
                player = try makePlayer()
            }

            try activateAudioSession()
            guard let player, !player.isPlaying else { return }

            player.volume = 0
            player.play()
            player.setVolume(
                AudioAsset.playbackVolume,
                fadeDuration: AudioAsset.fadeInDuration
            )
        } catch {
            Self.logger.error(
                "Unable to play background music: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Pauses playback while retaining the current position for a later resume.
    func pause() {
        player?.pause()
        deactivateAudioSession()
    }

    private func makePlayer() throws -> AVAudioPlayer {
        guard let asset = NSDataAsset(name: AudioAsset.backgroundMusic) else {
            throw BackgroundMusicError.missingAsset(AudioAsset.backgroundMusic)
        }

        let player = try AVAudioPlayer(data: asset.data)
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        return player
    }

    private func activateAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try audioSession.setActive(true)
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            Self.logger.error(
                "Unable to deactivate the background music session: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

private enum BackgroundMusicError: LocalizedError {
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case .missingAsset(let name):
            "Audio asset \(name) was not found in Assets.xcassets."
        }
    }
}
