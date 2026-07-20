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

    func openDashboard() {
        navigateToDashboard = true
        print("Tombol Start ditekan")
    }
}
