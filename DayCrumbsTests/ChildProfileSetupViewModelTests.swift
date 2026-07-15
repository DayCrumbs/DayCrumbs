import Testing

@testable import DayCrumbs

@Suite("Child profile setup view model")
struct ChildProfileSetupViewModelTests {
    @Test("A complete profile with a positive integer age is valid")
    func completeProfileIsValid() {
        let viewModel = ChildProfileSetupViewModel()
        viewModel.childName = "Mika"
        viewModel.childAge = 4
        viewModel.selectedGender = .girl

        #expect(viewModel.isFormValid)
    }

    @Test("Zero age is invalid")
    func zeroAgeIsInvalid() {
        let viewModel = ChildProfileSetupViewModel()
        viewModel.childName = "Mika"
        viewModel.childAge = 0
        viewModel.selectedGender = .girl

        #expect(!viewModel.isFormValid)
    }
}
