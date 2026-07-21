import Observation

@Observable
final class PickActivityViewModel {
    let activityOptions: [Activity.BuiltInActivity] = [
        .play,
        .sleep,
        .study,
        .eat,
        .getReady,
        .wakeUp
    ]

    var selectedActivity: Activity.BuiltInActivity?
    var navigationRoute: StoryFlowRoute?

    func handleActivitySelection(
        _ activity: Activity.BuiltInActivity,
        session: Sessions,
        place: Place.BuiltInPlace
    ) {
        navigationRoute = .pickMood(session, place, activity)
    }

    func activityImageName(
        for activity: Activity.BuiltInActivity,
        gender: ChildGender = .girl
    ) -> String {
        StorySelectionAsset.sliderImageName(for: activity, gender: gender)
    }
}
