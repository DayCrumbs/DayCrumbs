import SwiftUI

struct CharacterBubble: View {
    let characterImageName: String
    let text: String

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = min(40, proxy.size.width * 0.05)
            let overlap = proxy.size.width * 0.005
            let characterWidth = proxy.size.width * 0.405
            let characterHeight = characterWidth * 905 / 555
            let bubbleWidth = proxy.size.width * 0.46
            let bubbleHeight = bubbleWidth * 391 / 696

            HStack(alignment: .top, spacing: -overlap) {
                Image(characterImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: characterWidth, height: characterHeight, alignment: .bottom)

                Image("BubbleAsset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: bubbleWidth, height: bubbleHeight)
                    .overlay {
                        Text(text)
                            .font(.system(size: min(34, max(18, bubbleWidth * 0.047)), design: .rounded).weight(.bold))
                            .foregroundColor(AppColour.txtCoklat)
                            .multilineTextAlignment(.center)
                            .lineSpacing(0)
                            .lineLimit(6)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.35)
                            .frame(
                                width: bubbleWidth * 0.72,
                                height: bubbleHeight * 0.58,
                                alignment: .center
                            )
                            .offset(x: -bubbleWidth * -0.03,y: -bubbleHeight * 0.13)
                    }
                    .padding(.top, min(32, max(16, proxy.size.height * 0.035)))
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, max(34, proxy.size.height * 0.10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
        }
    }
}
