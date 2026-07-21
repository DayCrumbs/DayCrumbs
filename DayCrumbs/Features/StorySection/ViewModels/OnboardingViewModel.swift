import Observation

@Observable
final class OnboardingViewModel {
    var navigateToProfile = false
    var navigateToDashboard = false
    var navigateToModel = false

    func startStory() {
        navigateToProfile = true
        print("Tombol Start ditekan")
    }

    func openModels() {
        navigateToModel = true
        print("Tombol Start ditekan")
    }

    /// Accepts only one Dashboard navigation intent until SwiftUI resets the
    /// presentation binding after the destination is dismissed.
    @discardableResult
    func openDashboard() -> Bool {
        guard !navigateToDashboard else {
            return false
        }

        navigateToDashboard = true
        print("Tombol Start ditekan")
        return true
    }
}
