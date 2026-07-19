import SwiftUI

struct SessionOptionView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var navigationRoute: StoryFlowRoute?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                AppColour.bgPutih
                    .ignoresSafeArea()

                if proxy.size.width >= 760 {
                    wideContent(in: proxy.size)
                } else {
                    compactContent(in: proxy.size)
                }

                CircularBackButton(style: .yellowBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .storyFlowNavigationDestination(route: $navigationRoute)
    }

    private func wideContent(in size: CGSize) -> some View {
        let leftPanelWidth = size.width * 0.22
        let gridLeading = size.width * 0.236
        let gridTop = size.height * 0.083
        let gridTrailing = size.width * 0.032
        let gridGap = size.width * 0.019
        let gridWidth = max(0, size.width - gridLeading - gridTrailing)
        let cardWidth = max(0, (gridWidth - gridGap) / 2)
        let cardHeight = min(size.height * 0.405, (size.height - gridTop - 84) / 2)
        let characterWidth = leftPanelWidth * 1.22
        let characterHeight = characterWidth * 905 / 555

        return ZStack(alignment: .topLeading) {
            SessionPromptBubble(
                text: "Which part of your day would you like to talk about?"
            )
            .frame(width: leftPanelWidth * 0.90)
            .padding(.top, size.height * 0.13)
            .padding(.leading, size.width * 0.022)

            Image("PickSession_Girl")
                .resizable()
                .scaledToFit()
                .frame(width: characterWidth, height: characterHeight, alignment: .bottomLeading)
                .offset(
                    x: -characterWidth * 0.21,
                    y: max(0, size.height - characterHeight - 10)
                )

            VStack(spacing: size.height * 0.023) {
                HStack(spacing: gridGap) {
                    sessionCard(for: .morning)
                        .frame(width: cardWidth, height: cardHeight)
                    sessionCard(for: .afternoon)
                        .frame(width: cardWidth, height: cardHeight)
                }

                HStack(spacing: gridGap) {
                    sessionCard(for: .evening)
                        .frame(width: cardWidth, height: cardHeight)
                    sessionCard(for: .night)
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .frame(width: gridWidth, height: (cardHeight * 2) + (size.height * 0.023))
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, gridTop)
            .padding(.leading, gridLeading)
            .padding(.trailing, gridTrailing)
        }
    }

    private func compactContent(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                SessionPromptBubble(
                    text: "Which part of your day would you like to talk about?"
                )
                .frame(width: min(size.width * 0.72, 300))

                Image("PickSession_Girl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(size.width * 0.58, 320))

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 18),
                        GridItem(.flexible(), spacing: 18)
                    ],
                    spacing: 18
                ) {
                    ForEach(Sessions.allCases, id: \.self) { session in
                        sessionCard(for: session)
                            .frame(height: 210)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 112)
            .padding(.bottom, 32)
        }
    }

    private func sessionCard(for session: Sessions) -> some View {
        SessionSelectionCard(session: session) {
            navigationRoute = .pickPlace(session)
        }
    }
}

private struct SessionSelectionCard: View {
    let session: Sessions
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 36

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                let horizontalInset: CGFloat = 6
                let verticalInset: CGFloat = 6
                let imageHeight = max(0, proxy.size.height * 0.80)
                let titleHeight = max(0, proxy.size.height - imageHeight - (verticalInset * 2))

                VStack(spacing: 0) {
                    Image(session.imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: max(0, proxy.size.width - (horizontalInset * 2)),
                            height: imageHeight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Text(session.title)
                        .font(.system(size: titleSize, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColour.txtCoklat)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(
                            width: max(0, proxy.size.width - (horizontalInset * 2)),
                            height: titleHeight
                        )
                }
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, verticalInset)
            }
            .background(AppColour.btnKuning)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose \(session.title) session")
        .accessibilityHint("Starts a story for the \(session.title.lowercased()) session.")
    }
}

#Preview {
    SessionOptionView()
}
