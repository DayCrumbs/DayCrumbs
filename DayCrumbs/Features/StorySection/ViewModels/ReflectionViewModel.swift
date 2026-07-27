import Foundation
import Observation

@Observable
final class ReflectionViewModel {
    var reflectionText = ""
    var navigationRoute: StoryFlowRoute?
    var isDiscardConfirmationPresented = false

    var isReflectionReady: Bool {
        !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveReflectionAndFinish(onSave: (String) -> Void) {
        onSave(reflectionText)
    }

    func showDiscardConfirmation() {
        isDiscardConfirmationPresented = true
    }

    func dismissDiscardConfirmation() {
        isDiscardConfirmationPresented = false
    }
}
