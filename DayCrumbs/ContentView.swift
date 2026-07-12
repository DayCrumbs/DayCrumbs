//
//  ContentView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/9/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Story", systemImage: "book.pages") {
                NavigationStack {
                    StoryPlaceholderView()
                }
            }

            Tab("Dashboard", systemImage: "chart.bar.xaxis") {
                NavigationStack {
                    DashboardPlaceholderView()
                }
            }

            Tab("Models", systemImage: "cpu") {
                NavigationStack {
                    ModelsView()
                }
            }
        }
    }
}

private struct StoryPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Story Coming Soon",
            systemImage: "book.pages",
            description: Text("Guided storytelling will be implemented in a later phase.")
        )
        .navigationTitle("Story")
    }
}

private struct DashboardPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            "Dashboard Coming Soon",
            systemImage: "chart.bar.xaxis",
            description: Text("Story analytics will be implemented in a later phase.")
        )
        .navigationTitle("Dashboard")
    }
}

#Preview {
    ContentView()
}
