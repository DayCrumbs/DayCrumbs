import SwiftUI

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
                        .opacity(index == 0 ? 1 : 0.58)
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

    static func imageName(for activity: Activity.BuiltInActivity) -> String {
        switch activity {
        case .play: return "Activity_Play"
        case .sleep: return "Activity_Sleep"
        case .study: return "Activity_Study"
        case .eat: return "Activity_Eat"
        case .getReady: return "Activity_GetReady"
        case .wakeUp: return "Activity_WakeUp"
        }
    }
}
