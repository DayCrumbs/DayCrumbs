import SwiftUI

struct MoodAlertView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool

    let mood: Moods
    let gender: ChildGender 
    let dismiss: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    alertContent
                        .padding(30)
                }
                .frame(maxWidth: 560, maxHeight: .infinity)
            } else {
                alertContent
                    .padding(42)
                    .frame(maxWidth: 420, alignment: .leading)
            }
        }
        .background(AppColour.bgPutih)
        .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About feeling \(mood.rawValue)")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isTitleFocused = true
            }
        }
    }

    private var alertContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            
            // --- BAGIAN GAMBAR WAJAH ANAK ---
            Image(mood.expressionImageName(for: gender))
                .resizable()
                .scaledToFit()
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 120 : 160)
                .frame(maxWidth: .infinity, alignment: .center)
                .offset(x: -20)
                .accessibilityHidden(true)
            
            Text(mood.alertTitle)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(mood.alertDetails, id: \.self) { detail in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("•")
                        Text(detail)
                    }
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
                }
            }

            Button(action: dismiss) {
                Text("Done")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColour.txtPutih)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(AppColour.btnCoklat)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .accessibilityLabel("Done")
            .accessibilityHint("Closes the mood information.")
        }
    }
}

private extension Moods {
    var alertTitle: String {
        switch self {
        case .angry: return "Someone who's angry may:"
        case .disgust: return "Someone who feels disgusted may:"
        case .fear: return "Someone who's scared may:"
        case .happy: return "Someone who's happy would:"
        case .sad: return "Someone who's sad may:"
        case .surprise: return "Someone who's surprised may:"
        }
    }

    var alertDetails: [String] {
        switch self {
        case .angry:
            return ["Frown or make a tight face.", "Speak loudly or cry.", "Clench their hands.", "Want more space.", "Need a calm moment."]
        case .disgust:
            return ["Make a scrunched-up face.", "Pull away from something.", "Say something feels yucky.", "Cover their nose.", "Ask for help."]
        case .fear:
            return ["Hold on tightly.", "Look for a familiar adult.", "Want to stay close.", "Cry or become quiet.", "Need reassurance."]
        case .happy:
            return ["Smile a lot.", "Laugh or giggle.", "Clap their hands.", "Jump up and down.", "Want to play."]
        case .sad:
            return ["Have tears in their eyes.", "Speak more quietly.", "Want a hug or comfort.", "Need time to rest.", "Want someone nearby."]
        case .surprise:
            return ["Open their eyes or mouth wide.", "Pause and look closely.", "Laugh or gasp.", "Ask what happened.", "Want to talk about it."]
        }
    }
}
