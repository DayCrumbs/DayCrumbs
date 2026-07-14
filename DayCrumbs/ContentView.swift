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
                    OnboardingView()
                }
            }

            Tab("Dashboard", systemImage: "chart.bar.xaxis") {
                NavigationStack {
                    DashboardView()
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

#Preview {
    ContentView()
}
