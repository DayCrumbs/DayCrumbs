import Foundation
import Testing

@testable import DayCrumbs

@Suite("Model initialization")
struct ModelInitializationTests {
    @Test("Child profile stores and updates profile values")
    func childProfile() {
        let profile = ChildProfile(name: "Mika", age: 4, gender: .girl)

        #expect(profile.name == "Mika")
        #expect(profile.age == 4)
        #expect(profile.gender == .girl)

        profile.gender = .boy
        #expect(profile.gender == .boy)
    }

    @Test("After-activity notes store typed and transcribed text")
    func afterActivityNotes() {
        let date = Date(timeIntervalSince1970: 100)
        let notes = AfterActivityNotes(
            text: "Played calmly",
            transcribedText: "Asked to play again",
            createdAt: date
        )

        #expect(notes.text == "Played calmly")
        #expect(notes.transcribedText == "Asked to play again")
        #expect(notes.createdAt == date)
    }

    @Test("Custom activities store user-provided images")
    func customActivity() {
        let imageData = Data([0x01, 0x02, 0x03])
        let activity = CustomActivity(name: "Swimming", imageData: imageData)

        #expect(activity.name == "Swimming")
        #expect(activity.imageData == imageData)
    }

    @Test("Custom places store user-provided images")
    func customPlace() {
        let imageData = Data([0x04, 0x05, 0x06])
        let place = CustomPlace(name: "Grandma's house", imageData: imageData)

        #expect(place.name == "Grandma's house")
        #expect(place.imageData == imageData)
    }
}

@Suite("End-of-day reflection validation")
struct EndOfDayReflectionTests {
    @Test(
        "Reflection content ignores missing and whitespace-only input",
        arguments: [
            (text: nil, transcript: nil, expected: false),
            (text: "   ", transcript: "\n", expected: false),
            (text: "A calm day", transcript: nil, expected: true),
            (text: nil, transcript: "Enjoyed outdoor play", expected: true)
        ]
    )
    func contentValidation(
        text: String?,
        transcript: String?,
        expected: Bool
    ) {
        let reflection = EndOfDayReflection(
            text: text,
            transcribedText: transcript
        )

        #expect(reflection.hasContent == expected)
        #expect(reflection.createdAt == reflection.updatedAt)
    }
}
