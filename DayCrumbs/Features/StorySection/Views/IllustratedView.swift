import SwiftUI

struct IllustratedView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods

    @State private var viewModel = IllustratedViewModel()
    @AccessibilityFocusState private var isContinuationTitleFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                StorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(illustrationAccessibilityLabel)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityHidden(viewModel.isShowingContinuationCard)

                if viewModel.isShowingContinuationCard {
                    BlurredStorySelectionBackground(imageNames: illustratedBackgroundImageNames)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)

                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { }
                        .accessibilityHidden(true)

                    continuationCard(in: proxy.size)
                        .frame(
                            width: dynamicTypeSize.isAccessibilitySize
                                ? min(proxy.size.width - 48, 680)
                                : min(proxy.size.width * 0.58, 620),
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
                .disabled(viewModel.isShowingContinuationCard)
                .accessibilityHidden(viewModel.isShowingContinuationCard)
                .accessibilityHint("Returns to the discussion.")
            }
            .animation(.easeInOut(duration: 0.22), value: viewModel.isShowingContinuationCard)
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.isShowingContinuationCard) { _, isPresented in
            guard isPresented else { return }
            Task { @MainActor in
                await Task.yield()
                isContinuationTitleFocused = true
            }
        }
    }

    private var illustratedBackgroundImageNames: [String] {
        viewModel.backgroundImageNames(
            place: selectedPlace,
            activity: selectedActivity,
            gender: storyFlow.childGender
        )
    }

    private var illustrationAccessibilityLabel: String {
        "Story illustration. \(formattedStoryValue(selectedActivity.rawValue)) at \(formattedStoryValue(selectedPlace.rawValue)), with a \(selectedMood.rawValue) mood."
    }

    private func formattedStoryValue(_ value: String) -> String {
        value
            .replacingOccurrences(
                of: "([A-Z])",
                with: " $1",
                options: .regularExpression
            )
            .capitalized
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
        .accessibilityHint("Shows options to add another story or finish the session.")
    }

    private var continuationCardContent: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 20 : 24) {
            Text("Did anything else happen this \(Text(selectedSession.title.lowercased()).underline())?")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isContinuationTitleFocused)

            Text("You can add another activity or finish the session.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 14) {
                continuationActionButton(title: "Add Another Story", isPrimary: true) {
                    storyFlow.addAnotherStory()
                }

                continuationActionButton(title: "Finish Story") {
                    storyFlow.finishSession()
                }

                continuationActionButton(title: "Cancel") {
                    viewModel.dismissContinuationCard()
                }
            }
        }
    }

    @ViewBuilder
    private func continuationCard(in size: CGSize) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    continuationCardContent
                        .padding(30)
                }
                .frame(maxHeight: max(280, size.height - 48))
            } else {
                continuationCardContent
                    .padding(48)
            }
        }
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onTapGesture { }
    }

    private func continuationActionButton(
        title: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColour.txtPutih)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppColour.btnCoklat.opacity(isPrimary ? 1 : 0.58))
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
