//
//  DashboardView.swift
//  DayCrumbs
//

import SwiftUI

struct DashboardView: View {
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
    NavigationStack {
        DashboardView()
    }
}
