import SwiftUI

private struct AppAudioServiceKey: EnvironmentKey {
    static let defaultValue: AppAudioService? = nil
}

extension EnvironmentValues {
    var appAudioService: AppAudioService? {
        get { self[AppAudioServiceKey.self] }
        set { self[AppAudioServiceKey.self] = newValue }
    }
}

/// Adds sound without replacing a button's native role, accessibility, or appearance.
struct SoundEffectButtonStyle<BaseStyle: PrimitiveButtonStyle>: PrimitiveButtonStyle {
    let baseStyle: BaseStyle
    let effect: SoundEffect

    func makeBody(configuration: Configuration) -> some View {
        SoundEffectButton(
            configuration: configuration,
            baseStyle: baseStyle,
            effect: effect
        )
    }
}

private struct SoundEffectButton<BaseStyle: PrimitiveButtonStyle>: View {
    @Environment(\.appAudioService) private var appAudioService

    let configuration: PrimitiveButtonStyleConfiguration
    let baseStyle: BaseStyle
    let effect: SoundEffect

    var body: some View {
        Button(role: configuration.role) {
            appAudioService?.play(effect)
            configuration.trigger()
        } label: {
            configuration.label
        }
        .buttonStyle(baseStyle)
    }
}

extension PrimitiveButtonStyle
where Self == SoundEffectButtonStyle<PlainButtonStyle> {
    static func soundEffectPlain(
        _ effect: SoundEffect = .backPress
    ) -> Self {
        Self(baseStyle: PlainButtonStyle(), effect: effect)
    }
}
