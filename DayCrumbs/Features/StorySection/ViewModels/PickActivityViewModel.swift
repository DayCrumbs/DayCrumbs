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

    func activityImageNames(
        for activity: Activity.BuiltInActivity,
        place: Place.BuiltInPlace,
        gender: ChildGender = .girl
    ) -> [String] {
        [
            StorySelectionAsset.imageName(for: place),
            StorySelectionAsset.backgroundImageName(for: activity, gender: gender)
        ]
    }
}
