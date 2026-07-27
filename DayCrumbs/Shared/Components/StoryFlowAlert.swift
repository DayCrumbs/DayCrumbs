import SwiftUI

struct StoryFlowAlertAction {
    enum Style {
        case emphasized
        case secondary
        case destructive
    }

    let title: String
    let style: Style
    let action: () -> Void
}

/// A non-dismissible dimming layer that blocks interaction with content behind
/// story-flow dialogs. The identity transition keeps the dimming layer from
/// growing or fading in with the dialog card.
struct StoryFlowBlockingOverlay: View {
    var opacity: Double = 0.38

    var body: some View {
        Color.black.opacity(opacity)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { }
            .accessibilityHidden(true)
            .transition(.identity)
    }
}

/// A small, blocking confirmation dialog shared by the story flow.
struct StoryFlowAlert: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var isTitleFocused: Bool

    let title: String
    let message: String?
    let actions: [StoryFlowAlertAction]

    var body: some View {
        VStack(alignment: message == nil ? .center : .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppColour.txtCoklat)
                .frame(
                    maxWidth: .infinity,
                    alignment: message == nil ? .center : .leading
                )
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($isTitleFocused)

            if let message {
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons
                .padding(.top, 8)
        }
        .padding(dynamicTypeSize.isAccessibilitySize ? 20 : 24)
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? 480 : 330,
            alignment: .leading
        )
        .background(AppColour.bgPutih)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isTitleFocused = true
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if actions.count == 1, let action = actions.first {
            alertButton(for: action)
        } else if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) {
                ForEach(actions.indices, id: \.self) { index in
                    alertButton(for: actions[index])
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(actions.indices, id: \.self) { index in
                    alertButton(for: actions[index])
                }
            }
        }
    }

    private func alertButton(for action: StoryFlowAlertAction) -> some View {
        Button(action: action.action) {
            Text(action.title)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(foregroundColour(for: action.style))
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 6 : 0)
                .background(backgroundColour(for: action.style))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }

    private func backgroundColour(for style: StoryFlowAlertAction.Style) -> Color {
        switch style {
        case .emphasized:
            AppColour.btnCoklat
        case .secondary:
            AppColour.btnPutih
        case .destructive:
            AppColour.btnCoklat.opacity(0.2)
        }
    }

    private func foregroundColour(for style: StoryFlowAlertAction.Style) -> Color {
        switch style {
        case .emphasized:
            AppColour.txtPutih
        case .secondary:
            AppColour.txtCoklat
        case .destructive:
            .red
        }
    }
}
