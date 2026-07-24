import SwiftUI

struct PickMoodView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    
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
                
                VStack(spacing: 0) {
                    QuestionCharacterBubble(
                        characterImageName: StoryCharacterAsset.imageName(
                            for: .mood,
                            gender: storyFlow.childGender
                        ),
                        characterHeightRatio: 1084.0 / 655.0,
                        title: moodQuestionTitle,
                        subtitle: "Pick a face that looks like how you felt.You can also hold any emotion to learn more about it.",
                        accessibilityLabel: "How did you feel when you \(viewModel.activityPastTense(selectedActivity))? Pick a face that looks like how you felt.You can also hold any emotion to learn more about it."
                    )
                    .frame(height: proxy.size.height * 0.60)
                    
                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                            .frame(width: proxy.size.width * 0.47)
                        
                        VStack(spacing: 0) {
                            moodGrid
                                .offset(y: -84)
                                .padding(.bottom, -84)
                            
                        }
                        .frame(width: proxy.size.width * 0.47)
                        
                        Spacer(minLength: 0)
                    }
                    .frame(height: proxy.size.height * 0.40, alignment: .top)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                
                CircularBackButton(style: .yellowBtn) {
                    storyFlow.goBack()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .accessibilityHidden(viewModel.moodAlert != nil)
                
                if let moodAlert = viewModel.moodAlert {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                        .transition(.opacity)
                    
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
    
    private var moodQuestionTitle: Text {
        Text("How did you feel when you \(Text(viewModel.activityPastTense(selectedActivity)).underline())?")
    }
}

private struct MoodExpressionButton: View {
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
                    
                    Image(mood.expressionImageName(for: gender))
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
        }
        .frame(height: 180)
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
    NavigationStack {
        PickMoodView(
            selectedSession: .morning,
            selectedPlace: .house,
            selectedActivity: .study
        )
    }
    .environment(StoryFlowCoordinator())
}
