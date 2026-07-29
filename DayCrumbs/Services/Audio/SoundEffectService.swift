import AVFoundation
import OSLog
import UIKit

enum SoundEffect: CaseIterable, Hashable {
    case backPress

    fileprivate var assetName: String {
        "BackPressSound"
    }

    fileprivate var playbackVolume: Float {
        0.75
    }
}

/// Preloads short app interaction sounds and provides low-latency polyphonic playback.
@MainActor
final class SoundEffectService {
    private static let voiceCount = 3
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "DayCrumbs",
        category: "SoundEffects"
    )

    private var players: [SoundEffect: [AVAudioPlayer]] = [:]
    private var nextVoiceIndex: [SoundEffect: Int] = [:]

    init() {
        preloadEffects()
    }

    func play(_ effect: SoundEffect) {
        do {
            let effectPlayers = try playersForEffect(effect)
            guard !effectPlayers.isEmpty else { return }

            let index = effectPlayers.firstIndex(where: { !$0.isPlaying })
                ?? nextVoiceIndex[effect, default: 0]
            let player = effectPlayers[index]

            player.currentTime = 0
            player.play()
            nextVoiceIndex[effect] = (index + 1) % effectPlayers.count
        } catch {
            Self.logger.error(
                "Unable to play \(effect.assetName, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func preloadEffects() {
        for effect in SoundEffect.allCases {
            do {
                players[effect] = try makePlayers(for: effect)
            } catch {
                Self.logger.error(
                    "Unable to preload \(effect.assetName, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func playersForEffect(_ effect: SoundEffect) throws -> [AVAudioPlayer] {
        if let effectPlayers = players[effect] {
            return effectPlayers
        }

        let effectPlayers = try makePlayers(for: effect)
        players[effect] = effectPlayers
        return effectPlayers
    }

    private func makePlayers(for effect: SoundEffect) throws -> [AVAudioPlayer] {
        guard let asset = NSDataAsset(name: effect.assetName) else {
            throw SoundEffectError.missingAsset(effect.assetName)
        }

        return try (0..<Self.voiceCount).map { _ in
            let player = try AVAudioPlayer(data: asset.data)
            player.volume = effect.playbackVolume
            player.prepareToPlay()
            return player
        }
    }
}

private enum SoundEffectError: LocalizedError {
    case missingAsset(String)

    var errorDescription: String? {
        switch self {
        case .missingAsset(let name):
            "Audio asset \(name) was not found in Assets.xcassets."
        }
    }
}
