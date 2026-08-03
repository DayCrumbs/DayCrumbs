import SwiftData
import SwiftUI

/// Friendly, one-purpose setup surfaced from Dashboard when the preferred
/// system intelligence is unavailable. Runtime and model names remain internal.
struct PrivateInsightsSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ModelsViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColour.btnKuning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Set Up Private Insights")
                        .font(.title.bold())

                    Text(
                        "To create insights privately on this device, DayCrumbs needs a one-time download of about 2.58 GB. The downloaded files stay on this iPhone or iPad."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)
                }

                setupStatus

                Spacer(minLength: 0)

                setupActions
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColour.bgPutih)
            .toolbar {
                if !isDownloading {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not Now") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isDownloading)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.gemmaState) { _, newState in
            if newState == .ready {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private var setupStatus: some View {
        switch viewModel.gemmaState {
        case .checking:
            Label {
                Text("Checking what this device needs…")
            } icon: {
                ProgressView()
            }
            .accessibilityElement(children: .combine)

        case .notInstalled:
            Label(
                "Ready to set up",
                systemImage: "arrow.down.circle"
            )
            .foregroundStyle(.secondary)

        case .downloading:
            VStack(alignment: .leading, spacing: 10) {
                Text("Preparing private insights…")
                    .font(.headline)

                ProgressView(value: viewModel.downloadProgress ?? 0)
                    .accessibilityLabel("Private insights setup progress")
                    .accessibilityValue(
                        viewModel.downloadProgressLabel ?? ""
                    )

                if let label = viewModel.downloadProgressLabel {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .ready:
            Label(
                "Private insights are ready",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    "Setup needs attention",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(.orange)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var setupActions: some View {
        if viewModel.canRequestDownload {
            Button {
                viewModel.startDownload()
            } label: {
                Text(
                    viewModel.gemmaState == .notInstalled
                        ? "Set Up Now"
                        : "Try Again"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColour.btnCoklat)
            .controlSize(.large)
            .accessibilityHint(
                "Downloads the files needed to create private insights on this device."
            )
        }

        if isDownloading {
            Button("Cancel Setup", role: .cancel) {
                viewModel.cancelDownload()
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .accessibilityHint(
                "Stops setup. Downloaded progress can be resumed later."
            )
        }
    }

    private var isDownloading: Bool {
        if case .downloading = viewModel.gemmaState {
            return true
        }
        return false
    }
}

#Preview {
    let container = try! DayCrumbsModelContainer.makeInMemoryContainer()
    PrivateInsightsSetupView(
        viewModel: ModelsViewModel(modelContext: container.mainContext)
    )
}
