import SwiftUI

struct ReasonView: View {
    private static let discussionCharacterLimit = 1_000

    @Environment(\.dismiss) private var dismiss

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods
    let onSaveDiscussion: (String) -> Void
    let onContinueToIllustrated: () -> Void

    @State private var discussionText = ""
    @State private var navigationRoute: StoryFlowRoute?

    init(
        selectedSession: Sessions,
        selectedPlace: Place.BuiltInPlace,
        selectedActivity: Activity.BuiltInActivity,
        selectedMood: Moods,
        onSaveDiscussion: @escaping (String) -> Void = { _ in },
        onContinueToIllustrated: @escaping () -> Void = {}
    ) {
        self.selectedSession = selectedSession
        self.selectedPlace = selectedPlace
        self.selectedActivity = selectedActivity
        self.selectedMood = selectedMood
        self.onSaveDiscussion = onSaveDiscussion
        self.onContinueToIllustrated = onContinueToIllustrated
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                BlurredStorySelectionBackground(
                    imageNames: [
                        StorySelectionAsset.imageName(for: selectedPlace),
                        StorySelectionAsset.backgroundImageName(for: selectedActivity)
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
        ZStack(alignment: .topLeading) {
            QuestionCharacterBubble(
                characterImageName: "Reason_Girl",
                characterHeightRatio: 1084.0 / 655.0,
                title: reasonQuestionTitle,
                subtitle: "Share your story with your parent so we can better understand what happened.",
                accessibilityLabel: reasonQuestionAccessibilityLabel
            )
            .frame(width: size.width, height: size.height * 0.60, alignment: .topLeading)

            discussionCard
                .frame(width: size.width * 0.43, height: size.height * 0.39)
                .offset(x: size.width * 0.49, y: size.height * 0.51)

            skipButton
                .frame(width: max(118, size.width * 0.11))
                .offset(x: size.width * 0.81, y: size.height * 0.92)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func compactContent(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                QuestionCharacterBubble(
                    characterImageName: "Reason_Girl",
                    characterHeightRatio: 1084.0 / 655.0,
                    title: reasonQuestionTitle,
                    subtitle: "Share your story with your parent so we can better understand what happened.",
                    accessibilityLabel: reasonQuestionAccessibilityLabel
                )
                .frame(height: min(520, size.height * 0.58))

                discussionCard
                    .frame(height: 390)

                skipButton
                    .frame(width: 150)
            }
            .padding(.horizontal, 24)
            .padding(.top, 88)
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

            Button(action: saveDiscussionAndContinue) {
                Text("Save Discussion")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppColour.txtCoklat)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(AppColour.bgPutih)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Save discussion")
            .accessibilityHint("Saves the optional discussion and continues to the illustration.")
        }
        .padding(24)
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var discussionEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppColour.bgPutih.opacity(0.24))

            if discussionText.isEmpty {
                Text("e.g. They felt \(selectedMood.rawValue) because they played hide and seek with friends at school")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.45))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $discussionText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 38)
                .onChange(of: discussionText) { _, newValue in
                    if newValue.count > Self.discussionCharacterLimit {
                        discussionText = String(newValue.prefix(Self.discussionCharacterLimit))
                    }
                }
                .accessibilityLabel(
                    "Write discussion, \(discussionText.count) of \(Self.discussionCharacterLimit) characters"
                )
                .accessibilityHint(
                    "Optional discussion. Enter up to \(Self.discussionCharacterLimit) characters."
                )

            HStack(spacing: 12) {
                Spacer()

                Text("\(discussionText.count)/\(Self.discussionCharacterLimit)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat)
                    .accessibilityLabel(
                        "\(discussionText.count) of \(Self.discussionCharacterLimit) characters"
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
        Button(action: continueToIllustrated) {
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
        "Can you tell us why you felt \(selectedMood.rawValue)? Share your story with your parent so we can better understand what happened."
    }

    private func saveDiscussionAndContinue() {
        onSaveDiscussion(discussionText)
        continueToIllustrated()
    }

    private func continueToIllustrated() {
        onContinueToIllustrated()
        navigationRoute = .illustrated(
            selectedSession,
            selectedPlace,
            selectedActivity,
            selectedMood
        )
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
}
