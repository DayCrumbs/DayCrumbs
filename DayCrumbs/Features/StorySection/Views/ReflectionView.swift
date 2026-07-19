import SwiftUI

struct ReflectionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSaveEndOfDayReflection: (String) -> Void
    
    @State private var reflectionText = ""
    @State private var navigateToOnboarding = false
    
    init(onSaveEndOfDayReflection: @escaping (String) -> Void = { _ in }) {
        self.onSaveEndOfDayReflection = onSaveEndOfDayReflection
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppColour.bgPutih
                    .ignoresSafeArea()
                
                if proxy.size.width >= 760 {
                    wideContent(in: proxy.size)
                } else {
                    compactContent(in: proxy.size)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $navigateToOnboarding) {
            OnboardingView()
        }
    }
    
    private func wideContent(in size: CGSize) -> some View {
        VStack(spacing: -84) {
            Image("ParentsReflection_Girl")
                .resizable()
                .scaledToFit()
                .frame(width: min(286, size.width * 0.34))
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
                Image("ParentsReflection_Girl")
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(250, size.width * 0.64))
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
        navigateToOnboarding = true
    }
}

#Preview {
    NavigationStack {
        ReflectionView()
    }
}
