import SwiftUI

/// Bubble kecil untuk layar pemilihan sesi.
/// Komponen ini terpisah dari `CharacterBubble` karena aset dan komposisinya berbeda.
struct SessionPromptBubble: View {
    let text: String

    @ScaledMetric(relativeTo: .title2) private var textSize: CGFloat = 30

    var body: some View {
        let responsiveTextSize = min(36, max(20, textSize))

        Image("MiniBubbleAsset")
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    Text(text)
                        .font(
                            .system(
                                size: responsiveTextSize,
                                design: .rounded
                            )
                            .weight(.bold)
                        )
                        .foregroundStyle(AppColour.txtCoklat)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .minimumScaleFactor(20 / responsiveTextSize)
                        .lineLimit(5)
                        .frame(
                            width: proxy.size.width * 0.74,
                            height: proxy.size.height * 0.36
                        )
                        .clipped()
                        .position(
                            x: proxy.size.width * 0.52,
                            y: proxy.size.height * 0.33
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    SessionPromptBubble(text: "Which part of your day would you like to talk about? can you tell me more about it aku mau coba coba ibnu ganteng banget anjay")
        .frame(width: 300)
        .padding()
        .background(AppColour.bgPutih)
}
