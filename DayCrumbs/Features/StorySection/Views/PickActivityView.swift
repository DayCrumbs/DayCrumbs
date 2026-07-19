//
//  PickActivityView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/17/26.
//

import SwiftUI

struct PickActivityView: View {
  @Environment(\.dismiss) private var dismiss

  let selectedSession: Sessions
  let selectedPlace: Place.BuiltInPlace
  @State private var selectedActivity: Activity.BuiltInActivity?
  @State private var navigateToMood = false
  
  private let activityOptions: [Activity.BuiltInActivity] = [
      .play,
      .sleep,
      .study,
      .eat,
      .getReady,
      .wakeUp
  ]
  
  var body: some View {
      GeometryReader { proxy in
          ZStack(alignment: .topLeading) {
              BlurredStorySelectionBackground(
                  imageNames: [StorySelectionAsset.imageName(for: selectedPlace)]
              )
                  .ignoresSafeArea()
              
              VStack(spacing: 0) {
                  CharacterBubble(
                      characterImageName: "PickActivity_Girl",
                      text: "Let's tell today's story together!\nWhat was your child doing?"
                  )
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
                  
                  SelectionSlider(
                      title: "Choose the activity where it happened",
                      items: activityOptions,
                      selectedItem: $selectedActivity,
                      itemName: { $0.rawValue },
                      onAddCustom: {
                          // Custom activity creation will be added in a later flow.
                      },
                      itemImageName: activityImageName(for:)
                  )
                  .frame(height: proxy.size.height * 0.26)
              }
              .frame(width: proxy.size.width, height: proxy.size.height)
              .onChange(of: selectedActivity) {_, newValue in
                  navigateToMood = newValue != nil
              }
              .navigationDestination(isPresented: $navigateToMood) {
                  if let selectedActivity {
                      PickMoodView(
                          selectedSession: selectedSession,
                          selectedPlace: selectedPlace,
                          selectedActivity: selectedActivity
                      )
                  }
              }
              
              CircularBackButton() {
                  dismiss()
              }
              .padding(.top, 24)
              .padding(.leading, 32)
          }
      }
      .navigationBarBackButtonHidden(true)
  }
  
  private func activityImageName(for activity: Activity.BuiltInActivity) -> String {
      StorySelectionAsset.sliderImageName(for: activity)
  }
}

#Preview {
  PickActivityView(selectedSession: .morning, selectedPlace: .house)
}
