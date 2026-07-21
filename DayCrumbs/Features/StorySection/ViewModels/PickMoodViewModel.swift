import Observation

@Observable
final class PickMoodViewModel {
    let moodOptions: [Moods] = [
        .disgust,
        .sad,
        .angry,
        .surprise,
        .fear,
        .happy
    ]

    var moodAlert: Moods?
    var navigationRoute: StoryFlowRoute?

    func selectMood(
        _ mood: Moods,
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity
    ) {
        navigationRoute = .reason(session, place, activity, mood)
    }

    func showMoodAlert(for mood: Moods) {
        moodAlert = mood
    }

    func dismissMoodAlert() {
        moodAlert = nil
    }

    func activityPastTense(_ activity: Activity.BuiltInActivity) -> String {
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
