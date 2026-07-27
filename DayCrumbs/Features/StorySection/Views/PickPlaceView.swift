import SwiftUI

struct PickPlaceView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedSession: Sessions

    @State private var viewModel = PickPlaceViewModel()
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                sessionBackground(in: proxy.size)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                VStack(spacing: 0) {
                    CharacterBubble(
                        characterImageName: StoryCharacterAsset.imageName(
                            for: .place,
                            gender: storyFlow.childGender
                        ),
                        text: "Let's tell today's story together!\nWhere did your activity happen?"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHint(
                        "You are adding a story to the \(selectedSession.title.lowercased()) session."
                    )
                    
                    SelectionSlider(
                        title: "Choose the place where it happened",
                        items: viewModel.placeOptions,
                        selectedItem: $viewModel.selectedPlace,
                        itemName: { $0.rawValue },
                        onAddCustom: {
                            // Custom place creation will be added in a later flow.
                        },
                        onSelectItem: { place in
                            storyFlow.selectPlace(place, in: selectedSession)
                        },
                        itemImageName: viewModel.placeImageName(for:)
                    )
                    .frame(
                        height: proxy.size.height
                            * (dynamicTypeSize.isAccessibilitySize ? 0.30 : 0.26)
                    )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                
                CircularBackButton() {
                    storyFlow.discardStoryAndReturnToSessionOption()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .accessibilityHint("Discards this story and returns to session selection.")
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private func sessionBackground(in size: CGSize) -> some View {
        Image(selectedSession.backgroundImageName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width * 1.08, height: size.height * 1.08)
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 12)
    }
}

#Preview {
    NavigationStack {
        PickPlaceView(selectedSession: .morning)
    }
    .environment(StoryFlowCoordinator())
}
