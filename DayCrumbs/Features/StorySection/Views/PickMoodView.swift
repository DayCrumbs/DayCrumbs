import SwiftUI

struct PickMoodView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    @State private var viewModel = PickMoodViewModel()

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

                VStack(spacing: 0) {
                    QuestionCharacterBubble(
                        characterImageName: "PickMood_Girl",
                        characterHeightRatio: 1084.0 / 655.0,
                        title: moodQuestionTitle,
                        subtitle: "Pick a face that looks like how you felt.",
                        accessibilityLabel: "How did you feel when you \(viewModel.activityPastTense(selectedActivity))? Pick a face that looks like how you felt."
                    )
                    .frame(height: proxy.size.height * 0.60)

                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                            .frame(width: proxy.size.width * 0.47)

                        VStack(spacing: 0) {
                            moodGrid
                                .offset(y: -84)
                                .padding(.bottom, -84)

                            Text("Hold any emotion to learn more about it")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppColour.txtCoklat.opacity(0.9))
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(AppColour.bgPutih)
                                .clipShape(Capsule())
                                .padding(.top, 20)
                        }
                        .frame(width: proxy.size.width * 0.47)

                        Spacer(minLength: 0)
                    }
                    .frame(height: proxy.size.height * 0.40, alignment: .top)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                CircularBackButton(style: .yellowBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .accessibilityHidden(viewModel.moodAlert != nil)

                if let moodAlert = viewModel.moodAlert {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)

                    MoodAlertView(mood: moodAlert) {
                        viewModel.dismissMoodAlert()
                    }
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .center
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.moodAlert)
        }
        .navigationBarBackButtonHidden(true)
        .storyFlowNavigationDestination(route: $viewModel.navigationRoute)
    }

    private var moodGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18),
                GridItem(.flexible(), spacing: 18)
            ],
            spacing: 22
        ) {
            ForEach(viewModel.moodOptions, id: \.self) { mood in
                MoodExpressionButton(
                    mood: mood,
                    selectMood: {
                        viewModel.selectMood(
                            mood,
                            session: selectedSession,
                            place: selectedPlace,
                            activity: selectedActivity
                        )
                    },
                    showMoodAlert: { viewModel.showMoodAlert(for: mood) }
                )
            }
        }
        .padding(.horizontal, 8)
    }

    private var moodQuestionTitle: Text {
        Text("How did you feel when you \(Text(viewModel.activityPastTense(selectedActivity)).underline())?")
    }
}

private struct MoodExpressionButton: View {
    let mood: Moods
    let selectMood: () -> Void
    let showMoodAlert: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(mood.expressionImageName)
                .resizable()
                .scaledToFit()
                .frame(height: 132)

            Text(mood.rawValue.capitalized)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(AppColour.txtCoklat)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(AppColour.btnKuning)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    showMoodAlert()
                }
                .exclusively(before: TapGesture().onEnded { _ in
                    selectMood()
                })
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(mood.accessibilityLabel)
        .accessibilityHint("Activate to choose this mood. Hold for half a second to learn more.")
        .accessibilityAction {
            selectMood()
        }
        .accessibilityAction(named: "Learn more") {
            showMoodAlert()
        }
    }
}

#Preview {
    PickMoodView(
        selectedSession: .morning,
        selectedPlace: .house,
        selectedActivity: .study
    )
}
