import Testing
import SwiftData

@testable import DayCrumbs

@Suite("Child profile setup view model")
@MainActor
struct ChildProfileSetupViewModelTests {
    @Test("A complete profile with a positive integer age is valid")
    func completeProfileIsValid() {
        let viewModel = ChildProfileSetupViewModel()
        viewModel.childName = "Mika"
        viewModel.childAgeText = "4"
        viewModel.selectedGender = .girl

        #expect(viewModel.isFormValid)
    }

    @Test("Zero age is invalid")
    func zeroAgeIsInvalid() {
        let viewModel = ChildProfileSetupViewModel()
        viewModel.childName = "Mika"
        viewModel.childAgeText = "0"
        viewModel.selectedGender = .girl

        #expect(!viewModel.isFormValid)
    }

    @Test("Age text keeps the numeric age and form validity in sync")
    func ageTextUpdatesFormValidity() {
        let viewModel = ChildProfileSetupViewModel()
        viewModel.childName = "Mika"
        viewModel.childAgeText = "4"
        viewModel.selectGender(.girl)

        #expect(viewModel.childAge == 4)
        #expect(viewModel.isFormValid)

        viewModel.childAgeText = ""

        #expect(viewModel.childAge == 0)
        #expect(!viewModel.isFormValid)
    }

    @Test("Name and age expose validation messages for invalid input")
    func invalidProfileInputHasValidationMessages() {
        let viewModel = ChildProfileSetupViewModel()

        viewModel.childName = "Mika2"
        viewModel.childAgeText = "four"

        #expect(viewModel.nameValidationMessage == "Name cannot contain numbers.")
        #expect(viewModel.ageValidationMessage == "Age can only contain numbers.")
        #expect(!viewModel.isFormValid)
    }

    @Test("An existing profile is loaded and updated without creating another profile")
    func existingProfileLoadsAndUpdatesInPlace() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let repository = ChildProfileRepository(modelContext: context)
        try repository.saveProfile(
            ChildProfile(name: "Mika", age: 4, gender: .girl)
        )

        let viewModel = ChildProfileSetupViewModel()
        viewModel.loadExistingProfile(using: repository)

        #expect(viewModel.childName == "Mika")
        #expect(viewModel.childAgeText == "4")
        #expect(viewModel.selectedGender == .girl)

        viewModel.childName = "Nara"
        viewModel.childAgeText = "5"
        viewModel.selectGender(.boy)
        viewModel.saveProfile(using: repository)

        let profiles = try context.fetch(FetchDescriptor<ChildProfile>())

        #expect(profiles.count == 1)
        #expect(profiles.first?.name == "Nara")
        #expect(profiles.first?.age == 5)
        #expect(profiles.first?.gender == .boy)
        #expect(viewModel.navigationRoute == .sessionOption)
    }

    @Test("Multiple child profiles are reported as a data-integrity error")
    func duplicateProfilesAreRejected() throws {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = container.mainContext
        let repository = ChildProfileRepository(modelContext: context)

        context.insert(ChildProfile(name: "Mika", age: 4, gender: .girl))
        context.insert(ChildProfile(name: "Nara", age: 5, gender: .boy))
        try context.save()

        #expect(throws: ChildProfileRepositoryError.multipleProfilesFound) {
            try repository.fetchActiveProfile()
        }
    }
}
