import SwiftUI

enum StoryFlowRoute: Hashable {
    case pickPlace(Sessions)
    case pickActivity(Sessions, Place.BuiltInPlace)
    case pickMood(Sessions, Place.BuiltInPlace, Activity.BuiltInActivity)
    case reason(Sessions, Place.BuiltInPlace, Activity.BuiltInActivity, Moods)
    case illustrated(Sessions, Place.BuiltInPlace, Activity.BuiltInActivity, Moods)
    case reflection(Sessions, Place.BuiltInPlace, Activity.BuiltInActivity, Moods)
    case sessionOption
    case onboarding
}

private struct StoryFlowDestinationView: View {
    let route: StoryFlowRoute

    var body: some View {
        switch route {
        case .pickPlace(let session):
            PickPlaceView(selectedSession: session)

        case .pickActivity(let session, let place):
            PickActivityView(selectedSession: session, selectedPlace: place)

        case .pickMood(let session, let place, let activity):
            PickMoodView(
                selectedSession: session,
                selectedPlace: place,
                selectedActivity: activity
            )

        case .reason(let session, let place, let activity, let mood):
            ReasonView(
                selectedSession: session,
                selectedPlace: place,
                selectedActivity: activity,
                selectedMood: mood
            )

        case .illustrated(let session, let place, let activity, let mood):
            IllustratedView(
                selectedSession: session,
                selectedPlace: place,
                selectedActivity: activity,
                selectedMood: mood
            )

        case .reflection(let session, let place, let activity, let mood):
            ReflectionView(
                selectedSession: session,
                selectedPlace: place,
                selectedActivity: activity,
                selectedMood: mood
            )

        case .sessionOption:
            SessionOptionView()

        case .onboarding:
            OnboardingView()
        }
    }
}

extension View {
    func storyFlowNavigationDestination(
        route: Binding<StoryFlowRoute?>
    ) -> some View {
        navigationDestination(item: route) { destination in
            StoryFlowDestinationView(route: destination)
        }
    }
}
