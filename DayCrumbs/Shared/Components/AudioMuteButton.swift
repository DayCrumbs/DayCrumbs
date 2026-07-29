import SwiftUI

struct AudioMuteButton: View {
    let isMuted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColour.txtCoklat)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMuted ? "Unmute audio" : "Mute audio")
        .accessibilityValue(isMuted ? "Muted" : "Playing")
        .accessibilityHint(
            isMuted
                ? "Turns on background music and the Back button sound."
                : "Turns off background music and the Back button sound."
        )
    }
}

#Preview {
    AudioMuteButton(isMuted: false) { }
        .padding()
}
