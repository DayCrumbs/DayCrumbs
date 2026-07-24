import Foundation
import Observation

@Observable
final class ReasonViewModel {
    let discussionCharacterLimit = 1_000

    var discussionText = "" {
        didSet {
            if discussionText.count > discussionCharacterLimit {
                discussionText = String(discussionText.prefix(discussionCharacterLimit))
            }
        }
    }
    var navigationRoute: StoryFlowRoute?
    
    init(initialText: String = "") {
        self.discussionText = initialText
    }

    var discussionCharacterCount: Int {
        discussionText.count
    }

    var isDiscussionReady: Bool {
        !discussionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func reasonQuestionAccessibilityLabel(for mood: Moods) -> String {
        "Can you tell us why you felt \(mood.rawValue)? Share your story with your parent so we can better understand what happened."
    }

    func discussionPlaceholder(for mood: Moods) -> String {
        "e.g. They felt \(mood.rawValue) because they played hide and seek with friends at school"
    }

    func saveDiscussion(
        onSave: (String) -> Void,
        onContinue: () -> Void,
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods
    ) {
        onSave(discussionText)
        continueToIllustrated(
            onContinue: onContinue,
            session: session,
            place: place,
            activity: activity,
            mood: mood
        )
    }

    func continueToIllustrated(
        onContinue: () -> Void,
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods
    ) {
        onContinue()
        navigationRoute = .illustrated(session, place, activity, mood)
    }
}
