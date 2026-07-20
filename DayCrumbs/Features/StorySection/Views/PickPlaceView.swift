import SwiftUI

struct PickPlaceView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedSession: Sessions

    @State private var viewModel = PickPlaceViewModel()
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                sessionBackground(in: proxy.size)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    CharacterBubble(
                        characterImageName: "PickPlace_Girl",
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
                        itemImageName: viewModel.placeImageName(for:)
                    )
                    .frame(height: proxy.size.height * 0.26)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                
                CircularBackButton() {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
            .onChange(of: viewModel.selectedPlace) { _, newValue in
                if let newValue {
                    viewModel.handlePlaceSelection(newValue, in: selectedSession)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .storyFlowNavigationDestination(route: $viewModel.navigationRoute)
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
}

#Preview {
    PickPlaceView(selectedSession: .morning)
}
