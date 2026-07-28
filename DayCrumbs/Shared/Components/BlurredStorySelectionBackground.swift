import SwiftUI

struct StorySelectionBackground: View {
    let imageNames: [String]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(imageNames.enumerated()), id: \.offset) { _, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width * 1.08,
                            height: proxy.size.height * 1.08
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

struct BlurredStorySelectionBackground: View {
    let imageNames: [String]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(imageNames.enumerated()), id: \.offset) { index, imageName in
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width * 1.08,
                            height: proxy.size.height * 1.08
                        )
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 12)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .accessibilityHidden(true)
        }
    }
}

enum StorySelectionAsset {
    static func imageName(for place: Place.BuiltInPlace) -> String {
        switch place {
        case .house: return "Place_House"
        case .outdoor: return "Place_Outdoor"
        case .school: return "Place_School"
        case .publicPlace: return "Place_PublicArea"
        }
    }

    static func sliderImageName(
        for activity: Activity.BuiltInActivity,
        gender: ChildGender
    ) -> String {
        "Activity_\(gender == .girl ? "Girl" : "Boy")_\(activity.assetSuffix)"
    }

    static func backgroundImageName(
        for activity: Activity.BuiltInActivity,
        gender: ChildGender
    ) -> String {
        "Background_Activity_\(gender == .girl ? "Girl" : "Boy")_\(activity.assetSuffix)"
    }
}

enum StoryCharacterAsset {
    static func imageName(for screen: Screen, gender: ChildGender) -> String {
        switch (screen, gender) {
        case (.session, .girl): return "PickSession_Girl"
        case (.session, .boy): return "PickSession_Boy"
        case (.place, .girl): return "PickPlace_Girl"
        case (.place, .boy): return "PickPlaceBoy"
        case (.activity, .girl): return "PickActivity_Girl"
        case (.activity, .boy): return "PickActivity_Boy"
        case (.mood, .girl): return "PickMood_Girl"
        case (.mood, .boy): return "PickMood_Boy"
        case (.reason, .girl): return "Reason_Girl"
        case (.reason, .boy): return "Reason_Boy"
        case (.reflection, .girl): return "ParentsReflection_Girl"
        case (.reflection, .boy): return "ParentsReflection_Boy"
        }
    }

    enum Screen {
        case session
        case place
        case activity
        case mood
        case reason
        case reflection
    }
}

private extension Activity.BuiltInActivity {
    var assetSuffix: String {
        switch self {
        case .play: return "Play"
        case .sleep: return "Sleep"
        case .study: return "Study"
        case .eat: return "Eat"
        case .getReady: return "GetReady"
        case .wakeUp: return "WakeUp"
        }
    }
}
