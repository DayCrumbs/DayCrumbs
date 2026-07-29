import Observation

/// Coordinates all app audio so mute state applies consistently across features.
@MainActor
@Observable
final class AppAudioService {
    private let backgroundMusicService = BackgroundMusicService()
    private let soundEffectService = SoundEffectService()
    private var shouldPlayBackgroundMusic = false

    private(set) var isMuted = false

    func playBackgroundMusic() {
        shouldPlayBackgroundMusic = true
        guard !isMuted else { return }
        backgroundMusicService.play()
    }

    func pauseBackgroundMusic() {
        shouldPlayBackgroundMusic = false
        backgroundMusicService.pause()
    }

    func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        soundEffectService.play(effect)
    }

    func toggleMute() {
        isMuted.toggle()

        if isMuted {
            backgroundMusicService.pause()
        } else if shouldPlayBackgroundMusic {
            backgroundMusicService.play()
        }
    }
}
