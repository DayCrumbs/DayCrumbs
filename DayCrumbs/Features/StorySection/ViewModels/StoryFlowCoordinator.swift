import Observation
import SwiftData
import Foundation

enum StoryFlowRoot: Equatable {
    case loading
    case onboarding
    case dashboard
    case profileDataError(String)
}

private struct StoryActivityDraft {
    let session: Sessions
    let place: Place.BuiltInPlace
    let activity: Activity.BuiltInActivity
    let mood: Moods
    let discussion: String?
}

@MainActor
@Observable
final class StoryFlowCoordinator {
    var root: StoryFlowRoot = .loading
    var navigationPath: [StoryFlowRoute] = []
    var childGender: ChildGender = .girl
    var isStoryCompletedToday = false
    var errorMessage: String?
    var cachedDiscussionText: String = ""

    private var childProfile: ChildProfile?
    private var repository: StoryFlowRepositoryProtocol?
    private var currentActivityDraft: StoryActivityDraft?
    private var currentActivityIsPersisted = false
    private var isConfigured = false

    func configure(using modelContext: ModelContext) {
        guard !isConfigured else { return }

        let storyRepository = StoryFlowRepository(modelContext: modelContext)
        repository = storyRepository
        let profileRepository = ChildProfileRepository(modelContext: modelContext)

        do {
            childProfile = try profileRepository.fetchActiveProfile()
            childGender = childProfile?.gender ?? .girl
            if let childProfile {
                isStoryCompletedToday = try storyRepository.hasCompletedStoryToday(
                    for: childProfile
                )
            } else {
                isStoryCompletedToday = false
            }
            root = childProfile == nil ? .onboarding : .dashboard
            errorMessage = nil
        } catch {
            root = .profileDataError(error.localizedDescription)
            errorMessage = error.localizedDescription
        }

        isConfigured = true
    }

    func showChildProfileSetup() {
        guard case .onboarding = root else { return }
        navigationPath = [.childProfileSetup]
    }

    func didSaveChildProfile(using repository: ChildProfileRepository) {
        do {
            guard let profile = try repository.fetchActiveProfile() else {
                errorMessage = "Profil anak tidak ditemukan setelah disimpan."
                return
            }

            childProfile = profile
            childGender = profile.gender
            isStoryCompletedToday = false
            currentActivityDraft = nil
            currentActivityIsPersisted = false
            cachedDiscussionText = ""
            errorMessage = nil
            root = .dashboard
            navigationPath = [.sessionOption]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startStoryFromDashboard() {
        guard childProfile != nil else {
            root = .onboarding
            navigationPath = []
            return
        }

        guard !isStoryCompletedToday else { return }

        currentActivityDraft = nil
        currentActivityIsPersisted = false
        cachedDiscussionText = ""
        navigationPath = [.sessionOption]
    }

    func returnToDashboard() {
        currentActivityDraft = nil
        currentActivityIsPersisted = false
        cachedDiscussionText = ""
        navigationPath = []
        root = childProfile == nil ? .onboarding : .dashboard
    }

    func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    func selectSession(_ session: Sessions) {
        navigationPath = [.sessionOption, .pickPlace(session)]
    }

    func selectPlace(
        _ place: Place.BuiltInPlace,
        in session: Sessions
    ) {
        navigationPath.append(.pickActivity(session, place))
    }

    func selectActivity(
        _ activity: Activity.BuiltInActivity,
        in session: Sessions,
        place: Place.BuiltInPlace
    ) {
        navigationPath.append(.pickMood(session, place, activity))
    }

    func selectMood(
        _ mood: Moods,
        in session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity
    ) {
        navigationPath.append(.reason(session, place, activity, mood))
    }
    
    func updateDiscussionCache(_ text: String) {
        cachedDiscussionText = text
    }

    func continueFromReason(
        session: Sessions,
        place: Place.BuiltInPlace,
        activity: Activity.BuiltInActivity,
        mood: Moods,
        discussion: String?
    ) {
        currentActivityDraft = StoryActivityDraft(
            session: session,
            place: place,
            activity: activity,
            mood: mood,
            discussion: discussion
        )
        currentActivityIsPersisted = false
        navigationPath.append(.illustrated(session, place, activity, mood))
    }

    func addAnotherStory() {
        guard commitCurrentActivity() else { return }

        currentActivityDraft = nil
        currentActivityIsPersisted = false
        cachedDiscussionText = ""
        navigationPath = [.sessionOption]
    }

    func discardStoryAndReturnToSessionOption() {
        currentActivityDraft = nil
        currentActivityIsPersisted = false
        cachedDiscussionText = ""
        navigationPath = [.sessionOption]
    }

    func discardReflectionAndReturnToIllustrated() {
        goBack()
    }

    func finishSession() {
        guard let draft = currentActivityDraft else { return }
        let reflectionRoute = StoryFlowRoute.reflection(
            draft.session,
            draft.place,
            draft.activity,
            draft.mood
        )

        guard commitCurrentActivity() else { return }
        navigationPath.append(reflectionRoute)
    }

    func finishReflection(_ reflection: String) {
        guard
            let childProfile,
            let repository
        else {
            errorMessage = "Profil anak belum siap untuk menyimpan refleksi."
            return
        }

        do {
            try repository.saveEndOfDayReflection(reflection, for: childProfile)
            isStoryCompletedToday = true
            currentActivityDraft = nil
            currentActivityIsPersisted = false
            cachedDiscussionText = ""
            errorMessage = nil
            navigationPath = []
            root = .dashboard
        } catch {
            errorMessage = "Refleksi belum dapat disimpan: \(error.localizedDescription)"
        }
    }

    private func commitCurrentActivity() -> Bool {
        guard
            let draft = currentActivityDraft,
            let childProfile,
            let repository
        else {
            errorMessage = "Aktivitas belum siap untuk disimpan."
            return false
        }

        if currentActivityIsPersisted {
            return true
        }

        do {
            try repository.saveActivity(
                for: childProfile,
                session: draft.session,
                place: draft.place,
                activity: draft.activity,
                mood: draft.mood,
                discussion: draft.discussion
            )
            currentActivityIsPersisted = true
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Aktivitas belum dapat disimpan: \(error.localizedDescription)"
            return false
        }
    }

}
