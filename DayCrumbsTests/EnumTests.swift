import Testing

@testable import DayCrumbs

@Suite("Domain enums")
struct EnumTests {
    @Test("Child genders expose every picker option")
    func childGenderCases() {
        #expect(ChildGender.allCases == [.boy, .girl])
        #expect(ChildGender.girl.rawValue == "girl")
    }

    @Test("Sessions expose every part of the day")
    func sessionCases() {
        #expect(Sessions.allCases == [.morning, .afternoon, .evening, .night])
        #expect(Sessions(rawValue: "evening") == .evening)
    }

    @Test("Moods expose every picker option")
    func moodCases() {
        #expect(Moods.allCases == [.angry, .disgust, .fear, .happy, .sad, .surprise])
        #expect(Moods(rawValue: "surprise") == .surprise)
    }

    @Test("Built-in activities expose stable raw values")
    func activityCases() {
        #expect(Activity.BuiltInActivity.allCases == [
            .play, .sleep, .study, .eat, .getReady, .wakeUp
        ])
        #expect(Activity.BuiltInActivity(rawValue: "getReady") == .getReady)
        #expect(Activity.CustomActivity.customActivity.rawValue == "customActivity")
    }

    @Test("Built-in places expose stable raw values")
    func placeCases() {
        #expect(Place.BuiltInPlace.allCases == [
            .house, .outdoor, .school, .publicPlace
        ])
        #expect(Place.BuiltInPlace(rawValue: "publicPlace") == .publicPlace)
        #expect(Place.CustomPlace.customPlace.rawValue == "customPlace")
    }

    @Test(
        "Only the available Foundation Models status is available",
        arguments: [
            AppleFoundationModelAvailability.deviceNotEligible,
            .appleIntelligenceNotEnabled,
            .modelNotReady,
            .unsupportedOS,
            .unavailable
        ]
    )
    func unavailableFoundationModelStatuses(
        _ status: AppleFoundationModelAvailability
    ) {
        #expect(!status.isAvailable)
        #expect(AppleFoundationModelAvailability.available.isAvailable)
    }
}
