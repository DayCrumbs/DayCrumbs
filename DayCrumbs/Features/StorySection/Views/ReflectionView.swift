import SwiftUI

struct ReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods
    let onSaveEndOfDayReflection: (String) -> Void
    
    @State private var reflectionText = ""
    @State private var navigationRoute: StoryFlowRoute?
    
    init(
        selectedSession: Sessions,
        selectedPlace: Place.BuiltInPlace,
        selectedActivity: Activity.BuiltInActivity,
        selectedMood: Moods,
        onSaveEndOfDayReflection: @escaping (String) -> Void = { _ in }
    ) {
        self.selectedSession = selectedSession
        self.selectedPlace = selectedPlace
        self.selectedActivity = selectedActivity
        self.selectedMood = selectedMood
        self.onSaveEndOfDayReflection = onSaveEndOfDayReflection
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BlurredStorySelectionBackground(
                    imageNames: [
                        StorySelectionAsset.imageName(for: selectedPlace),
                        StorySelectionAsset.backgroundImageName(for: selectedActivity)
                    ]
                )
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                
                if proxy.size.width >= 760 {
                    wideContent(in: proxy.size)
                } else {
                    compactContent(in: proxy.size)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .storyFlowNavigationDestination(route: $navigationRoute)
    }
    
    private func wideContent(in size: CGSize) -> some View {
        VStack(spacing: -84) {
            OutlinedParentReflectionIllustration()
                .frame(width: min(286, size.width * 0.34))
                .offset(y: -24)
                .zIndex(1)
            
            reflectionCard
                .frame(width: min(556, size.width * 0.66), height: size.height * 0.47)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .offset(y: -26)
    }
    
    private func compactContent(in size: CGSize) -> some View {
        ScrollView {
            VStack(spacing: -54) {
                OutlinedParentReflectionIllustration()
                    .frame(width: min(250, size.width * 0.64))
                    .offset(y: -20)
                    .zIndex(1)
                
                reflectionCard
                    .frame(height: 370)
            }
            .padding(.horizontal, 24)
            .padding(.top, 62)
            .padding(.bottom, 32)
        }
    }
    
    private var reflectionCard: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                Text("Write Discussion")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColour.txtCoklat)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Document your discussion to provide additional context that helps the app better understand and analyze your child's behavior.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                reflectionEditor
            }
            .padding(.top, 82)
            .padding(.horizontal, 30)
            .padding(.bottom, 26)
            
            HStack {
                CircularBackButton(style: .whiteBtn) {
                    dismiss()
                }
                .scaleEffect(0.7)
                
                Spacer()
                
                confirmationButton
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
        }
        .background(AppColour.cardKuning)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    
    private var reflectionEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColour.bgPutih.opacity(0.24))
            
            if reflectionText.isEmpty {
                Text("e.g. Today, she was mostly happy because she got to spend time with her dad who's usually busy at work. But, she had difficulty doing a part of her homework in the evening. Her dad came to help and her mood eventually returned to normal.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.45))
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $reflectionText)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppColour.txtCoklat)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .accessibilityLabel("End-of-day reflection")
                .accessibilityHint("Required. Describe the day before finishing the session.")
            
            Button {
                // Voice-to-text will be added after the MVP.
            } label: {
                Image(systemName: "mic")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(AppColour.txtCoklat)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voice input")
            .accessibilityHint("Voice-to-text is coming after the MVP.")
            .padding(.trailing, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var confirmationButton: some View {
        Button(action: saveReflectionAndFinish) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isReflectionReady ? AppColour.txtCoklat : AppColour.txtCoklat.opacity(0.35))
                .frame(width: 34, height: 34)
                .background(AppColour.bgPutih)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(AppColour.txtCoklat.opacity(isReflectionReady ? 0.8 : 0.3), lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isReflectionReady)
        .accessibilityLabel("Finish reflection")
        .accessibilityValue(
            isReflectionReady
                ? "Ready to finish"
                : "Disabled until an end-of-day reflection is entered"
        )
        .accessibilityHint(
            isReflectionReady
            ? "Saves the reflection and returns to onboarding."
            : "Write an end-of-day reflection before continuing."
        )
    }
    
    private var isReflectionReady: Bool {
        !reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveReflectionAndFinish() {
        onSaveEndOfDayReflection(reflectionText)
        navigationRoute = .onboarding
    }
}

private struct OutlinedParentReflectionIllustration: View {
    private let outlineOffsets: [CGSize] = [
        CGSize(width: -5, height: -5),
        CGSize(width: 0, height: -7),
        CGSize(width: 5, height: -5),
        CGSize(width: -7, height: 0),
        CGSize(width: 7, height: 0),
        CGSize(width: -5, height: 5),
        CGSize(width: 0, height: 7),
        CGSize(width: 5, height: 5)
    ]

    var body: some View {
        ZStack {
            ForEach(outlineOffsets.indices, id: \.self) { index in
                Image("ParentsReflection_Girl")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColour.btnKuning)
                    .offset(
                        x: outlineOffsets[index].width,
                        y: outlineOffsets[index].height
                    )
            }

            Image("ParentsReflection_Girl")
                .resizable()
                .scaledToFit()
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        ReflectionView(
            selectedSession: .night,
            selectedPlace: .house,
            selectedActivity: .sleep,
            selectedMood: .happy
        )
    }
}
