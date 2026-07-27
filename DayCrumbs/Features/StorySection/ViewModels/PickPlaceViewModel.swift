import Observation

@Observable
final class PickPlaceViewModel {
    let placeOptions: [Place.BuiltInPlace] = [
        .house,
        .outdoor,
        .publicPlace,
        .school
    ]

    var selectedPlace: Place.BuiltInPlace?
    var navigationRoute: StoryFlowRoute?

    func handlePlaceSelection(_ place: Place.BuiltInPlace, in session: Sessions) {
        navigationRoute = .pickActivity(session, place)
    }

    func placeImageName(for place: Place.BuiltInPlace) -> String {
        switch place {
        case .house: return "Place_House"
        case .outdoor: return "Place_Outdoor"
        case .school: return "Place_School"
        case .publicPlace: return "Place_PublicArea"
        }
    }
}
