import SwiftUI

struct PickMoodView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    @State private var selectedMood: Moods?

    private let moodOptions: [Moods] = [
        .disgust,
        .sad,
        .angry,
        .surprise,
        .fear,
        .happy
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.white
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    CharacterBubble(
                        characterImageName: "PickMood_Girl",
                        text: "How did you feel when you \(activityPastTense(selectedActivity))?\nPick a face that looks like how you felt."
                    )
                    .frame(height: proxy.size.height * 0.68)

                    HStack(alignment: .top, spacing: 0) {
                        Spacer()
                            .frame(width: proxy.size.width * 0.47)

                        VStack(spacing: 0) {
                            moodGrid

                            Text("Hold any emotion to learn more about it")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppColour.txtCoklat.opacity(0.9))
                                .padding(.top, 26)
                        }
                        .frame(width: proxy.size.width * 0.47)

                        Spacer(minLength: 0)
                    }
                    .frame(height: proxy.size.height * 0.32, alignment: .top)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)

                CircularBackButton(style: .yellowBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
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
            ForEach(moodOptions, id: \.self) { mood in
                Button {
                    selectedMood = mood
                } label: {
                    VStack(spacing: 10) {
                        Image(mood.expressionImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 78)

                        Text(mood.rawValue.capitalized)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppColour.txtCoklat)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
    }

    private func activityPastTense(_ activity: Activity.BuiltInActivity) -> String {
        switch activity {
        case .play: return "played"
        case .sleep: return "slept"
        case .study: return "studied"
        case .eat: return "ate"
        case .getReady: return "got ready"
        case .wakeUp: return "woke up"
        }
    }
}

#Preview {
    PickMoodView(selectedPlace: .house, selectedActivity: .study)
}
