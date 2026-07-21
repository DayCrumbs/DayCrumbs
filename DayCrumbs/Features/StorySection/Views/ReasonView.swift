import SwiftUI
import UIKit

struct ReasonView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods
    @State private var viewModel = ReasonViewModel()
    @State private var isKeyboardVisible = false

    init(
        selectedSession: Sessions,
        selectedPlace: Place.BuiltInPlace,
        selectedActivity: Activity.BuiltInActivity,
        selectedMood: Moods
    ) {
        self.selectedSession = selectedSession
        self.selectedPlace = selectedPlace
        self.selectedActivity = selectedActivity
        self.selectedMood = selectedMood
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                BlurredStorySelectionBackground(
                    imageNames: [
                        StorySelectionAsset.imageName(for: selectedPlace),
                        StorySelectionAsset.backgroundImageName(
                            for: selectedActivity,
                            gender: storyFlow.childGender
                        )
                    ]
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)

                if proxy.size.width >= 760 {
                    wideContent(in: proxy.size)
                } else {
                    compactContent(in: proxy.size)
                }

                CircularBackButton(style: .yellowBtn) {
                    storyFlow.goBack()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
            .animation(.easeInOut(duration: 0.22), value: isKeyboardVisible)
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private func wideContent(in size: CGSize) -> some View {
        let cardWidth = isKeyboardVisible
            ? min(680, max(size.width * 0.70, size.width - 48))
            : size.width * 0.43
        let cardHeight = isKeyboardVisible
            ? min(390, max(280, size.height - 44))
            : size.height * 0.39
        let cardOffsetX = isKeyboardVisible
            ? (size.width - cardWidth) / 2
            : size.width * 0.49
        let cardOffsetY = isKeyboardVisible
            ? max(0, (size.height - cardHeight) / 2) - min(30, size.height * 0.06)
            : size.height * 0.51

        return ZStack(alignment: .topLeading) {
            QuestionCharacterBubble(
                characterImageName: StoryCharacterAsset.imageName(
                    for: .reason,
                    gender: storyFlow.childGender
                ),
                characterHeightRatio: 1084.0 / 655.0,
                title: reasonQuestionTitle,
                subtitle: "Share your story with your parent so we can better understand what happened.",
                accessibilityLabel: reasonQuestionAccessibilityLabel
            )
            .frame(width: size.width, height: size.height * 0.60, alignment: .topLeading)
            .opacity(isKeyboardVisible ? 0 : 1)
            .allowsHitTesting(!isKeyboardVisible)
            .accessibilityHidden(isKeyboardVisible)

            discussionCard
                .frame(width: cardWidth, height: cardHeight)
                .offset(x: cardOffsetX, y: cardOffsetY)

            skipButton
                .frame(width: max(118, size.width * 0.11))
                .offset(x: size.width * 0.81, y: size.height * 0.92)
                .opacity(isKeyboardVisible ? 0 : 1)
                .allowsHitTesting(!isKeyboardVisible)
                .accessibilityHidden(isKeyboardVisible)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func compactContent(in size: CGSize) -> some View {
        let cardHeight = isKeyboardVisible
            ? min(390, max(280, size.height - 44))
            : 390
        let cardWidth = min(680, max(size.width * 0.70, size.width - 48))

        return ScrollView {
            VStack(spacing: isKeyboardVisible ? 0 : 24) {
                QuestionCharacterBubble(
                    characterImageName: StoryCharacterAsset.imageName(
                        for: .reason,
                        gender: storyFlow.childGender
                    ),
                    characterHeightRatio: 1084.0 / 655.0,
                    title: reasonQuestionTitle,
                    subtitle: "Share your story with your parent so we can better understand what happened.",
                    accessibilityLabel: reasonQuestionAccessibilityLabel
                )
                .frame(height: isKeyboardVisible ? 0 : min(520, size.height * 0.58))
                .opacity(isKeyboardVisible ? 0 : 1)
                .accessibilityHidden(isKeyboardVisible)

                Color.clear
                    .frame(
                        height: isKeyboardVisible
                            ? max(0, (size.height - cardHeight) / 2 - 16)
                            : 0
                    )

                discussionCard
                    .frame(
                        width: isKeyboardVisible ? cardWidth : nil,
                        height: cardHeight
                    )

                skipButton
                    .frame(width: 150)
                    .opacity(isKeyboardVisible ? 0 : 1)
                    .allowsHitTesting(!isKeyboardVisible)
                    .accessibilityHidden(isKeyboardVisible)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, isKeyboardVisible ? 16 : 88)
            .padding(.bottom, 32)
        }
    }

    private var discussionCard: some View {
        VStack(spacing: 14) {
            Text("Write Discussion")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .accessibilityAddTraits(.isHeader)

            Text("Document your discussion to provide additional context that helps the app better understand and analyze your child's behavior.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            discussionEditor

            Button {
                storyFlow.continueFromReason(
                    session: selectedSession,
                    place: selectedPlace,
                    activity: selectedActivity,
                    mood: selectedMood,
                    discussion: viewModel.discussionText
                )
            } label: {
                Text("Save Discussion")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppColour.txtCoklat)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppColour.bgPutih)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isDiscussionReady)
            .accessibilityLabel("Save discussion")
            .accessibilityValue(
                viewModel.isDiscussionReady
                    ? "Ready to save"
                    : "Disabled until a discussion is entered"
            )
            .accessibilityHint(
                viewModel.isDiscussionReady
                    ? "Saves the discussion and continues to the illustration."
                    : "Write a discussion before saving. You can also skip this step."
            )
        }
        .padding(24)
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var discussionEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColour.bgPutih.opacity(0.24))

            if viewModel.discussionText.isEmpty {
                Text(viewModel.discussionPlaceholder(for: selectedMood))
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $viewModel.discussionText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 38)
                .accessibilityLabel(
                    "Write discussion, \(viewModel.discussionCharacterCount) of \(viewModel.discussionCharacterLimit) characters"
                )
                .accessibilityHint(
                    "Optional discussion. Enter up to \(viewModel.discussionCharacterLimit) characters."
                )

            HStack(spacing: 12) {
                Spacer()

                Text("\(viewModel.discussionCharacterCount)/\(viewModel.discussionCharacterLimit)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat)
                    .accessibilityLabel(
                        "\(viewModel.discussionCharacterCount) of \(viewModel.discussionCharacterLimit) characters"
                    )

                Button {
                    // Voice-to-text will be added after the MVP.
                } label: {
                    Image(systemName: "mic")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(AppColour.txtCoklat)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Voice input")
                .accessibilityHint("Voice-to-text is coming after the MVP.")
            }
            .padding(.trailing, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var skipButton: some View {
        Button {
            storyFlow.continueFromReason(
                session: selectedSession,
                place: selectedPlace,
                activity: selectedActivity,
                mood: selectedMood,
                discussion: nil
            )
        } label: {
            Text("Skip")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColour.txtCoklat)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(AppColour.bgPutih)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Skip discussion")
        .accessibilityHint("Continues to the illustration without saving a discussion.")
    }

    private var reasonQuestionTitle: Text {
        Text("Can you tell us why you felt \(Text(selectedMood.rawValue).underline())?")
    }

    private var reasonQuestionAccessibilityLabel: String {
        viewModel.reasonQuestionAccessibilityLabel(for: selectedMood)
    }
}

#Preview {
    NavigationStack {
        ReasonView(
            selectedSession: .morning,
            selectedPlace: .school,
            selectedActivity: .study,
            selectedMood: .happy
        )
    }
    .environment(StoryFlowCoordinator())
}
