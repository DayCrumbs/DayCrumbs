import Observation

@Observable
final class SessionOptionViewModel {
    var navigationRoute: StoryFlowRoute?

    func selectSession(_ session: Sessions) {
        navigationRoute = .pickPlace(session)
    }
}
