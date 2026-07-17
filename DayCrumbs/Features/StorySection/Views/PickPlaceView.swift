import SwiftUI

struct PickPlaceView: View {
    @Environment(\.dismiss) private var dismiss
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
                AppColour.bgKuning
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
                        }
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
            .onChange(of: selectedPlace) { _, newValue in
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
}

#Preview {
    PickPlaceView()
}
