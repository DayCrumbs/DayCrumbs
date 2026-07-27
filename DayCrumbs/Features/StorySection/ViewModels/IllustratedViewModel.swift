import Observation

@Observable
final class IllustratedViewModel {
    var isShowingContinuationCard = false

    func showContinuationCard() {
        isShowingContinuationCard = true
    }

    func dismissContinuationCard() {
        isShowingContinuationCard = false
    }

    func backgroundImageNames(
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        gender: ChildGender = .girl
    ) -> [String] {
        [
            StorySelectionAsset.imageName(for: place),
            StorySelectionAsset.backgroundImageName(for: activity, gender: gender)
        ]
    }

    func continuationAccessibilityHint(for title: String) -> String {
        switch title {
        case "Add Another Story":
            return "Saves this activity and returns to session selection."
        case "Finish Story":
            return "Saves this activity and opens the end-of-day reflection."
        default:
            return "Closes these story options."
        }
    }
}
