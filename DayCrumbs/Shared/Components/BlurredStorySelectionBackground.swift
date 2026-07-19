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

    static func sliderImageName(for activity: Activity.BuiltInActivity) -> String {
        switch activity {
        case .play: return "Activity_Girl_Play"
        case .sleep: return "Activity_Girl_Sleep"
        case .study: return "Activity_Girl_Study"
        case .eat: return "Activity_Girl_Eat"
        case .getReady: return "Activity_Girl_GetReady"
        case .wakeUp: return "Activity_Girl_WakeUp"
        }
    }

    static func backgroundImageName(for activity: Activity.BuiltInActivity) -> String {
        switch activity {
        case .play: return "Background_Activity_Girl_Play"
        case .sleep: return "Background_Activity_Girl_Sleep"
        case .study: return "Background_Activity_Girl_Study"
        case .eat: return "Background_Activity_Girl_Eat"
        case .getReady: return "Background_Activity_Girl_GetReady"
        case .wakeUp: return "Background_Activity_Girl_WakeUp"
        }
    }
}
