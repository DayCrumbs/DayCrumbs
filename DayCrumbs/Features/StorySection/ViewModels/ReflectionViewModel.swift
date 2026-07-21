import Foundation
import Observation

@Observable
final class ReflectionViewModel {
    var reflectionText = ""
    var navigationRoute: StoryFlowRoute?

    var isReflectionReady: Bool {
        !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveReflectionAndFinish(onSave: (String) -> Void) {
        onSave(reflectionText)
    }
}
