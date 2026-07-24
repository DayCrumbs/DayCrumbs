import SwiftUI
import UIKit

struct ReflectionView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    
    let selectedSession: Sessions
    let selectedPlace: Place.BuiltInPlace
    let selectedActivity: Activity.BuiltInActivity
    let selectedMood: Moods
    @State private var viewModel = ReflectionViewModel()
    @State private var isKeyboardVisible = false
    
    init(
        selectedSession: Sessions,
        selectedPlace: Place.BuiltInPlace,
        selectedActivity: Activity.BuiltInActivity,
        selectedMood: Moods
    ) {
        self.selectedSession = selectedSession
        self.selectedPlace = selectedPlace
        self.selectedActivity = selectedActivity
        self.selectedMood = selectedMood
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BlurredStorySelectionBackground(
                    imageNames: [
                        StorySelectionAsset.imageName(for: selectedPlace),
                        StorySelectionAsset.backgroundImageName(
                            for: selectedActivity,
                            gender: storyFlow.childGender
                        )
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
            .animation(.easeInOut(duration: 0.22), value: isKeyboardVisible)
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }
    
    private func wideContent(in size: CGSize) -> some View {
        let illustrationWidth = isKeyboardVisible ? 0 : min(286, size.width * 0.34)
        let cardWidth = isKeyboardVisible
            ? min(580, max(size.width * 0.82, size.width - 48))
            : min(556, size.width * 0.66)
        let cardHeight = isKeyboardVisible
            ? min(390, max(280, size.height - 36))
            : size.height * 0.47

        return VStack(spacing: isKeyboardVisible ? 0 : -84) {
            OutlinedParentReflectionIllustration(gender: storyFlow.childGender)
                .frame(width: illustrationWidth)
                .offset(y: isKeyboardVisible ? 0 : -24)
                .zIndex(1)
                .opacity(isKeyboardVisible ? 0 : 1)
            
            reflectionCard
                .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .offset(y: isKeyboardVisible ? -min(24, size.height * 0.05) : -26)
    }
    
    private func compactContent(in size: CGSize) -> some View {
        let illustrationWidth = isKeyboardVisible ? 0 : min(250, size.width * 0.64)
        let cardHeight = isKeyboardVisible
            ? min(390, max(280, size.height - 36))
            : 370
        let cardWidth = min(580, max(size.width * 0.82, size.width - 48))

        return ScrollView {
            VStack(spacing: isKeyboardVisible ? 0 : -54) {
                OutlinedParentReflectionIllustration(gender: storyFlow.childGender)
                    .frame(width: illustrationWidth)
                    .offset(y: isKeyboardVisible ? 0 : -20)
                    .zIndex(1)
                    .opacity(isKeyboardVisible ? 0 : 1)

                Color.clear
                    .frame(
                        height: isKeyboardVisible
                            ? max(0, (size.height - cardHeight) / 2 - 16)
                            : 0
                    )
                
                reflectionCard
                    .frame(
                        width: isKeyboardVisible ? cardWidth : nil,
                        height: cardHeight
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, isKeyboardVisible ? 16 : 62)
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
                CircularBackButton(style: .brownBtn) {
                    storyFlow.goBack()
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
            
            if viewModel.reflectionText.isEmpty {
                Text("e.g. Today, she was mostly happy because she got to spend time with her dad who's usually busy at work. But, she had difficulty doing a part of her homework in the evening. Her dad came to help and her mood eventually returned to normal.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.45))
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $viewModel.reflectionText)
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
                .foregroundStyle(AppColour.txtPutih)
                .frame(width: 34, height: 34)
                .background (
                    AppColour.btnCoklat
                        .opacity(viewModel.isReflectionReady ? 1.0 : 0.45)
                )
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isReflectionReady)
        .accessibilityLabel("Finish reflection")
        .accessibilityValue(
            viewModel.isReflectionReady
                ? "Ready to finish"
                : "Disabled until an end-of-day reflection is entered"
        )
        .accessibilityHint(
            viewModel.isReflectionReady
            ? "Saves the reflection and returns to the dashboard."
            : "Write an end-of-day reflection before continuing."
        )
    }
    
    private func saveReflectionAndFinish() {
        storyFlow.finishReflection(viewModel.reflectionText)
    }
}

private struct OutlinedParentReflectionIllustration: View {
    let gender: ChildGender
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
                Image(StoryCharacterAsset.imageName(for: .reflection, gender: gender))
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(AppColour.btnKuning)
                    .offset(
                        x: outlineOffsets[index].width,
                        y: outlineOffsets[index].height
                    )
            }

            Image(StoryCharacterAsset.imageName(for: .reflection, gender: gender))
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
    .environment(StoryFlowCoordinator())
}
