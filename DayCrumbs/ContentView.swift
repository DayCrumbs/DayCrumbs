//
//  ContentView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/9/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var storyFlow = StoryFlowCoordinator()

    var body: some View {
        @Bindable var navigation = storyFlow

        NavigationStack(path: $navigation.navigationPath) {
            rootView
                .storyFlowNavigationDestinations()
        }
        .environment(storyFlow)
        .task {
            storyFlow.configure(using: modelContext)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch storyFlow.root {
        case .loading:
            ZStack {
                AppColour.bgPutih
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                ProgressView()
                    .accessibilityLabel("Loading DayCrumbs")
                    .accessibilityHint("Preparing your child profile and dashboard.")
            }

        case .onboarding:
            OnboardingView()

        case .dashboard:
            DashboardView(modelContext: modelContext)

        case .profileDataError(let message):
            ContentUnavailableView(
                "Profile data needs attention",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }
}

#Preview {
    ContentView()
}
