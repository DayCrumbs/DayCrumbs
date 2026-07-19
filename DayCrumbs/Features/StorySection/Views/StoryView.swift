//
//  StoryView.swift
//  DayCrumbs
//

import SwiftUI

struct StoryView: View {
    var body: some View {
        ContentUnavailableView(
            "Story Coming Soon",
            systemImage: "book.pages",
            description: Text("Guided storytelling will be implemented in a later phase.")
        )
        .navigationTitle("Story")
    }
}

#Preview {
    NavigationStack {
        StoryView()
    }
}
