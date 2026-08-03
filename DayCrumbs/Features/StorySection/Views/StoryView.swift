import SwiftUI

struct StoryView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppColour.btnKuning)
                .accessibilityHidden(true)

            Text("Tell today's story")
                .font(.title.bold())

            Text(
                "Add an activity, place, mood, and optional note. DayCrumbs keeps the story on this device."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Add Story") {
                storyFlow.startStoryFromDashboard()
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColour.btnCoklat)
            .disabled(storyFlow.isStoryCompletedToday)
            .accessibilityHint(
                storyFlow.isStoryCompletedToday
                    ? "Today's story is complete."
                    : "Starts the guided storytelling flow."
            )
        }
        .padding(24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColour.bgPutih)
        .navigationTitle("Story")
    }
}
