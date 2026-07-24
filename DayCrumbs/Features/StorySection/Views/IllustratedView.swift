import SwiftUI

struct IllustratedView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods

    @State private var viewModel = IllustratedViewModel()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                StorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                if viewModel.isShowingContinuationCard {
                    BlurredStorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)

                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .onTapGesture {
                            viewModel.dismissContinuationCard()
                        }

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
                    storyFlow.goBack()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
            .animation(.easeInOut(duration: 0.22), value: viewModel.isShowingContinuationCard)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var illustratedBackgroundImageNames: [String] {
        viewModel.backgroundImageNames(
            place: selectedPlace,
            activity: selectedActivity,
            gender: storyFlow.childGender
        )
    }

    private var continueButton: some View {
        Button {
            viewModel.showContinuationCard()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(AppColour.txtPutih)
            .padding(.horizontal, 24)
            .frame(minHeight: 48)
            .background(AppColour.btnCoklat)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue story")
        .accessibilityHint("Shows options for another activity, another session, or finishing the session.")
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
                continuationActionButton(title: "Add Another Activity") {
                    storyFlow.addAnotherActivity()
                }

                if selectedSession != .night {
                    continuationActionButton(title: "Continue to Another Session") {
                        storyFlow.continueToAnotherSession()
                    }
                }

                continuationActionButton(title: "Finish Session") {
                    storyFlow.finishSession()
                }
            }
        }
        .padding(48)
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onTapGesture { }
    }

    private func continuationActionButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColour.txtPutih)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppColour.btnCoklat)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(viewModel.continuationAccessibilityHint(for: title))
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
    .environment(StoryFlowCoordinator())
}
