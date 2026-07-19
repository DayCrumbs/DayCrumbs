import SwiftUI

struct QuestionCharacterBubble: View {
    let characterImageName: String
    let characterHeightRatio: CGFloat
    let title: Text
    let subtitle: String
    let accessibilityLabel: String

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = min(40, proxy.size.width * 0.05)
            let overlap = proxy.size.width * 0.005
            let characterWidth = proxy.size.width * 0.405
            let bubbleWidth = proxy.size.width * 0.46
            let bubbleHeight = bubbleWidth * 391 / 696
            let titleSize = min(34, max(20, bubbleWidth * 0.047))
            let subtitleSize = min(24, max(16, bubbleWidth * 0.033))

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
                                .fixedSize(horizontal: false, vertical: true)

                            Text(subtitle)
                                .font(.system(size: subtitleSize, design: .rounded))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(AppColour.txtCoklat)
                        .frame(width: bubbleWidth * 0.72)
                        .offset(x: bubbleWidth * 0.03, y: -bubbleHeight * 0.13)
                    }
                    .padding(.top, min(32, max(16, proxy.size.height * 0.035)))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, max(34, proxy.size.height * 0.10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}
