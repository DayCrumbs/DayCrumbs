import SwiftUI

struct IllustratedView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods

    @State private var isShowingContinuationCard = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                StorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                    .ignoresSafeArea()

                if isShowingContinuationCard {
                    BlurredStorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    continuationCard
                        .frame(
                            width: min(proxy.size.width * 0.58, 620),
                            alignment: .center
                        )
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                        .transition(.scale.combined(with: .opacity))
                } else {
                    continueButton
                        .padding(.trailing, 44)
                        .padding(.bottom, 44)
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .bottomTrailing
                        )
                        .transition(.opacity)
                }

                CircularBackButton(style: .yellowBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
            .animation(.easeInOut(duration: 0.22), value: isShowingContinuationCard)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var illustratedBackgroundImageNames: [String] {
        [
            StorySelectionAsset.imageName(for: selectedPlace),
            StorySelectionAsset.backgroundImageName(for: selectedActivity)
        ]
    }

    private var continueButton: some View {
        Button {
            isShowingContinuationCard = true
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "chevron.right")
            }
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(AppColour.txtCoklat)
            .padding(.horizontal, 24)
            .frame(minHeight: 48)
            .background(AppColour.bgPutih)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var continuationCard: some View {
        VStack(spacing: 24) {
            Text("Did anything else happen this \(Text(selectedSession.title.lowercased()).underline())?")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .multilineTextAlignment(.center)

            Text("You can add another activity or continue to the next session.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .multilineTextAlignment(.center)

            VStack(spacing: 14) {
                continuationActionButton(title: "Add Another Activity")

                if let nextSession {
                    continuationActionButton(title: "Continue to \(nextSession.title)")
                }

                continuationActionButton(title: "Finish Session")
            }
        }
        .padding(48)
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    private var nextSession: Sessions? {
        switch selectedSession {
        case .morning: return .afternoon
        case .afternoon: return .evening
        case .evening: return .night
        case .night: return nil
        }
    }

    private func continuationActionButton(title: String) -> some View {
        Button {
            // The next story-session actions will be connected in the Story flow work.
        } label: {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColour.txtCoklat)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppColour.bgPutih)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        IllustratedView(
            selectedSession: .morning,
            selectedPlace: .house,
            selectedActivity: .study,
            selectedMood: .happy
        )
    }
}
