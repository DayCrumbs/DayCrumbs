import Observation

@Observable
final class IllustratedViewModel {
    var isShowingContinuationCard = false
    var navigationRoute: StoryFlowRoute?

    func showContinuationCard() {
        isShowingContinuationCard = true
    }

    func backgroundImageNames(
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity
    ) -> [String] {
        [
            StorySelectionAsset.imageName(for: place),
            StorySelectionAsset.backgroundImageName(for: activity)
        ]
    }

    func addAnotherActivity(in session: Sessions) {
        navigationRoute = .pickPlace(session)
    }

    func continueToAnotherSession() {
        navigationRoute = .sessionOption
    }

    func finishSession(
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods
    ) {
        navigationRoute = .reflection(session, place, activity, mood)
    }

    func continuationAccessibilityHint(for title: String) -> String {
        switch title {
        case "Add Another Activity":
            return "Starts another activity in the current session."
        case "Continue to Another Session":
            return "Returns to the session selection screen."
        default:
            return "Opens the end-of-day reflection."
        }
    }
}
