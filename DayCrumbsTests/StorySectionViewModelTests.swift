import Testing

@testable import DayCrumbs

@Suite("Story section view models")
@MainActor
struct StorySectionViewModelTests {
    @Test("Place and activity selections can be selected again after returning")
    func placeAndActivitySelectionsSupportReselection() {
        let placeViewModel = PickPlaceViewModel()
        placeViewModel.handlePlaceSelection(.house, in: .morning)
        placeViewModel.handlePlaceSelection(.house, in: .morning)

        #expect(placeViewModel.navigationRoute == .pickActivity(.morning, .house))

        let activityViewModel = PickActivityViewModel()
        activityViewModel.handleActivitySelection(
            .play,
            session: .morning,
            place: .house
        )
        activityViewModel.handleActivitySelection(
            .play,
            session: .morning,
            place: .house
        )

        #expect(
            activityViewModel.navigationRoute
                == .pickMood(.morning, .house, .play)
        )
    }

    @Test("Mood alert state is presented and dismissed by its view model")
    func moodAlertStateChanges() {
        let viewModel = PickMoodViewModel()

        viewModel.showMoodAlert(for: .happy)
        #expect(viewModel.moodAlert == .happy)

        viewModel.dismissMoodAlert()
        #expect(viewModel.moodAlert == nil)
    }

    @Test("Discussion save requires content and enforces the character limit")
    func discussionValidationAndCharacterLimit() {
        let viewModel = ReasonViewModel()

        viewModel.updateDiscussionText("   \n")
        #expect(!viewModel.isDiscussionReady)

        viewModel.updateDiscussionText(
            String(repeating: "a", count: 1_001)
        )
        #expect(viewModel.discussionCharacterCount == 1_000)
        #expect(viewModel.isDiscussionReady)
    }

    @Test("Illustrated continuation card can be shown and dismissed")
    func illustratedContinuationCardStateChanges() {
        let viewModel = IllustratedViewModel()

        viewModel.showContinuationCard()
        #expect(viewModel.isShowingContinuationCard)

        viewModel.dismissContinuationCard()
        #expect(!viewModel.isShowingContinuationCard)
    }

    @Test("Reflection can finish only after non-whitespace content is entered")
    func reflectionReadinessRequiresContent() {
        let viewModel = ReflectionViewModel()

        #expect(!viewModel.isReflectionReady)

        viewModel.reflectionText = "  \n"
        #expect(!viewModel.isReflectionReady)

        viewModel.reflectionText = "Today was calmer after playtime."
        #expect(viewModel.isReflectionReady)
    }
}
