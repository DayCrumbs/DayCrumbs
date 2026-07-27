import SwiftUI

struct PickPlaceView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow

    let selectedSession: Sessions

    @State private var viewModel = PickPlaceViewModel()
    
    var body: some View {
        GeometryReader { proxy in
            let isDiscardConfirmationPresented = viewModel.isDiscardConfirmationPresented

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
                    .frame(height: proxy.size.height * 0.26)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .accessibilityHidden(isDiscardConfirmationPresented)
                
                CircularBackButton() {
                    viewModel.showDiscardConfirmation()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .disabled(isDiscardConfirmationPresented)
                .accessibilityHidden(isDiscardConfirmationPresented)

                if isDiscardConfirmationPresented {
                    discardStoryAlert
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: .center
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(
                .easeInOut(duration: 0.2),
                value: isDiscardConfirmationPresented
            )
        }
        .navigationBarBackButtonHidden(true)
    }

    private func sessionBackground(in size: CGSize) -> some View {
        Image(selectedSession.imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width * 1.08, height: size.height * 1.08)
            .frame(width: size.width, height: size.height)
            .clipped()
            .blur(radius: 12)
    }

    private var discardStoryAlert: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }
                .accessibilityHidden(true)

            StoryFlowAlert(
                title: "Discard Story?",
                message: "If you go back now, your story progress will be discarded.",
                actions: [
                    StoryFlowAlertAction(
                        title: "Discard",
                        style: .destructive,
                        action: storyFlow.discardStoryAndReturnToSessionOption
                    ),
                    StoryFlowAlertAction(
                        title: "Cancel",
                        style: .emphasized,
                        action: viewModel.dismissDiscardConfirmation
                    )
                ]
            )
        }
    }
}

#Preview {
    NavigationStack {
        PickPlaceView(selectedSession: .morning)
    }
    .environment(StoryFlowCoordinator())
}
