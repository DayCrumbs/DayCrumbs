//
//  ModelsView.swift
//  DayCrumbs
//

import SwiftUI

struct ModelsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = ModelsViewModel()

    var body: some View {
        List {
            Section("Preferred Engine") {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: viewModel.isAppleFoundationModelsAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.isAppleFoundationModelsAvailable ? .green : .orange)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(AppleFoundationModelsRuntime.displayName)
                            .font(.headline)

                        Text(viewModel.isAppleFoundationModelsAvailable ? "Ready" : "Not Ready")
                            .font(.subheadline.weight(.semibold))

                        Text(viewModel.readinessMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }

            Section {
                Text("Apple manages this model as part of iOS and iPadOS. DayCrumbs does not download it or send child data to a server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Models")
        .task {
            viewModel.refreshAvailability()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            viewModel.refreshAvailability()
        }
    }
}

#Preview {
    NavigationStack {
        ModelsView()
    }
}
