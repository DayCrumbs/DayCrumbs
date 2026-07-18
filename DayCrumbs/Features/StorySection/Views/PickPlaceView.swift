import SwiftUI

struct PickPlaceView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedSession: Sessions

    @State private var selectedPlace: Place.BuiltInPlace?
    @State private var navigateToActivity = false
    
    // The order follows the current illustration reference.
    private let placeOptions: [Place.BuiltInPlace] = [
        .house,
        .outdoor,
        .publicPlace,
        .school
    ]
    
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
                        items: placeOptions,
                        selectedItem: $selectedPlace,
                        itemName: { $0.rawValue },
                        onAddCustom: {
                            // Custom place creation will be added in a later flow.
                        },
                        itemImageName: placeImageName(for:)
                    )
                    .frame(height: proxy.size.height * 0.26)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                
                CircularBackButton(style: .whiteBtn) {
                    dismiss()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
            }
            .onChange(of: selectedPlace) {_, newValue in
                navigateToActivity = newValue != nil
            }
            .navigationDestination(isPresented: $navigateToActivity) {
                if let selectedPlace {
                    PickActivityView(selectedPlace: selectedPlace)
                }
            }
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

    private func placeImageName(for place: Place.BuiltInPlace) -> String {
        switch place {
        case .house: return "Place_House"
        case .outdoor: return "Place_Outdoor"
        case .school: return "Place_School"
        case .publicPlace: return "Place_PublicArea"
        }
    }
}

#Preview {
    PickPlaceView(selectedSession: .morning)
}
