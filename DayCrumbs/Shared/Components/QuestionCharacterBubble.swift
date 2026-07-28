import SwiftUI

struct QuestionCharacterBubble: View {
    let characterImageName: String
    let characterHeightRatio: CGFloat
    let title: Text
    let subtitle: String
    let accessibilityLabel: String

    @ScaledMetric(relativeTo: .title2) private var preferredTitleSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var preferredSubtitleSize: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = min(40, proxy.size.width * 0.05)
            let overlap = proxy.size.width * 0.005
            let characterWidth = proxy.size.width * 0.405
            let bubbleWidth = proxy.size.width * 0.46
            let bubbleHeight = bubbleWidth * 391 / 696
            let layoutTitleSize = min(34, max(20, bubbleWidth * 0.047))
            let layoutSubtitleSize = min(24, max(16, bubbleWidth * 0.033))
            let titleSize = min(
                34,
                max(20, layoutTitleSize * (preferredTitleSize / 30))
            )
            let subtitleSize = min(
                24,
                max(16, layoutSubtitleSize * (preferredSubtitleSize / 20))
            )

            HStack(alignment: .top, spacing: -overlap) {
                Image(characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: characterWidth,
                        height: characterWidth * characterHeightRatio,
                        alignment: .bottom
                    )

                Image("BubbleAsset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bubbleWidth, height: bubbleHeight)
                    .overlay {
                        VStack(spacing: bubbleHeight * 0.045) {
                            title
                                .font(.system(size: titleSize, design: .rounded).weight(.bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .allowsTightening(true)
                                .minimumScaleFactor(20 / titleSize)

                            Text(subtitle)
                                .font(.system(size: subtitleSize, design: .rounded))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .allowsTightening(true)
                                .minimumScaleFactor(16 / subtitleSize)
                        }
                        .foregroundStyle(AppColour.txtCoklat)
                        .frame(
                            width: bubbleWidth * 0.72,
                            height: bubbleHeight * 0.66
                        )
                        .clipped()
                        .offset(x: bubbleWidth * 0.03, y: -bubbleHeight * 0.13)
                    }
                    .padding(.top, min(32, max(16, proxy.size.height * 0.035)))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, max(34, proxy.size.height * 0.10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isHeader)
        }
    }
}
