import Testing

@testable import DayCrumbs

@Suite("Onboarding navigation")
@MainActor
struct OnboardingViewModelTests {
    @Test("Repeated Dashboard taps create one navigation intent")
    func dashboardNavigationIsIdempotent() {
        let viewModel = OnboardingViewModel()

        #expect(viewModel.openDashboard())
        #expect(!viewModel.openDashboard())
        #expect(viewModel.navigateToDashboard)

        // SwiftUI resets this binding after the destination is dismissed.
        viewModel.navigateToDashboard = false
        #expect(viewModel.openDashboard())
    }
}
