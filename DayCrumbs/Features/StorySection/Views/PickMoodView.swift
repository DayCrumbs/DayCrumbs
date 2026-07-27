import SwiftUI

struct PickMoodView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
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
                        StorySelectionAsset.backgroundImageName(
                            for: selectedActivity,
                            gender: storyFlow.childGender
                        )
                    ]
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityMoodContent(in: proxy.size)
                    } else {
                        standardMoodContent(in: proxy.size)
                    }
                }
                .accessibilityHidden(viewModel.moodAlert != nil)
                
                CircularBackButton(style: .yellowBtn) {
                    storyFlow.goBack()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .accessibilityHidden(viewModel.moodAlert != nil)
                .accessibilityHint("Returns to activity selection.")
                
                if let moodAlert = viewModel.moodAlert {
                    StoryFlowBlockingOverlay(opacity: 0.18)
                    
                    MoodAlertView(
                        mood: moodAlert,
                        gender: storyFlow.childGender
                    ) {
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
    }

    private func standardMoodContent(in size: CGSize) -> some View {
        VStack(spacing: 0) {
            moodQuestionBubble
                .frame(height: size.height * 0.60)

            HStack(alignment: .top, spacing: 0) {
                Spacer()
                    .frame(width: size.width * 0.47)

                moodGrid
                    .offset(y: -200)
                    .padding(.bottom, -84)
                    .frame(width: size.width * 0.47)

                Spacer(minLength: 0)
            }
            .frame(height: size.height * 0.40, alignment: .top)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func accessibilityMoodContent(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: 28) {
                moodQuestionBubble
                    .frame(height: min(540, max(390, size.height * 0.54)))

                moodGrid
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
            .padding(.bottom, 36)
        }
    }

    private var moodQuestionBubble: some View {
        QuestionCharacterBubble(
            characterImageName: StoryCharacterAsset.imageName(
                for: .mood,
                gender: storyFlow.childGender
            ),
            characterHeightRatio: 1084.0 / 655.0,
            title: moodQuestionTitle,
            subtitle: "Pick a face that looks like how you felt. You can also hold any emotion to learn more about it.",
            accessibilityLabel: "How did you feel when you \(viewModel.activityPastTense(selectedActivity))? Pick a face that looks like how you felt. You can also hold any emotion to learn more about it."
        )
    }
    
    private var moodGrid: some View {
        LazyVGrid(
            columns: moodGridColumns,
            spacing: 22
        ) {
            ForEach(viewModel.moodOptions, id: \.self) { mood in
                MoodExpressionButton(
                    mood: mood,
                    gender: storyFlow.childGender,
                    selectMood: {
                        storyFlow.selectMood(
                            mood,
                            in: selectedSession,
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

    private var moodGridColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 2 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: 18),
            count: count
        )
    }
    
    private var moodQuestionTitle: Text {
        Text("How did you feel when you \(Text(viewModel.activityPastTense(selectedActivity)).underline())?")
    }
}

private struct MoodExpressionButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mood: Moods
    let gender: ChildGender
    let selectMood: () -> Void
    let showMoodAlert: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Background utama kartu (kuning)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColour.btnKuning)

            VStack(spacing: 0) {
                // 2. Kotak putih di bagian atas untuk wajah anak
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColour.bgPutih)
                    
                    Image(mood.clothedExpressionImageName(for: gender))
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 12)
                        .padding(.horizontal, 4)
                        .accessibilityHidden(true)
                }
                .padding([.top, .horizontal], 6)

                // 3. Area teks mood di bagian bawah
                Text(mood.rawValue.capitalized)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColour.txtCoklat)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 220 : 180)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        
        // Efek visual saat ditekan / ditahan
        .opacity(isPressed ? 0.6 : 1.0)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isPressed)
        
        .onTapGesture {
            selectMood()
        }
        .onLongPressGesture(
            minimumDuration: 0.5,
            perform: {
                showMoodAlert()
            },
            onPressingChanged: { pressing in
                isPressed = pressing
            }
        )
        
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(mood.accessibilityLabel)
        .accessibilityHint(
            "Double-tap to choose this mood. Use the Learn more action for details."
        )
        .accessibilityAction {
            selectMood()
        }
        .accessibilityAction(named: "Learn more") {
            showMoodAlert()
        }
    }
}

#Preview {
    NavigationStack {
        PickMoodView(
            selectedSession: .morning,
            selectedPlace: .house,
            selectedActivity: .study
        )
    }
    .environment(StoryFlowCoordinator())
}
