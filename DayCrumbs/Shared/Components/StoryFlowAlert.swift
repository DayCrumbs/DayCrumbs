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

/// A small, blocking confirmation dialog shared by the story flow.
struct StoryFlowAlert: View {
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

            if let message {
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppColour.txtCoklat.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            actionButtons
                .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: 330, alignment: .leading)
        .background(AppColour.bgPutih)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if actions.count == 1, let action = actions.first {
            alertButton(for: action)
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
