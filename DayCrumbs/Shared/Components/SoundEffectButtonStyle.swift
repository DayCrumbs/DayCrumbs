import SwiftUI

private struct SoundEffectServiceKey: EnvironmentKey {
    static let defaultValue: SoundEffectService? = nil
}

extension EnvironmentValues {
    var soundEffectService: SoundEffectService? {
        get { self[SoundEffectServiceKey.self] }
        set { self[SoundEffectServiceKey.self] = newValue }
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
    @Environment(\.soundEffectService) private var soundEffectService

    let configuration: PrimitiveButtonStyleConfiguration
    let baseStyle: BaseStyle
    let effect: SoundEffect

    var body: some View {
        Button(role: configuration.role) {
            soundEffectService?.play(effect)
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
