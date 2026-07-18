


//
//  PickActivityView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/17/26.
//

import SwiftUI

struct PickActivityView: View {
  @Environment(\.dismiss) private var dismiss

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
              selectedPlaceBackground
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
                          selectedPlace: selectedPlace,
                          selectedActivity: selectedActivity
                      )
                  }
              }
              
              CircularBackButton(style: .whiteBtn) {
                  dismiss()
              }
              .padding(.top, 24)
              .padding(.leading, 32)
          }
      }
      .navigationBarBackButtonHidden(true)
  }
  
  @ViewBuilder
  private var selectedPlaceBackground: some View {
      switch selectedPlace {
      case .house:
          Color(red: 0.96, green: 0.84, blue: 0.67)
      case .outdoor:
          Color(red: 0.86, green: 0.92, blue: 0.73)
      case .publicPlace:
          Color(red: 0.93, green: 0.88, blue: 0.75)
      case .school:
          Color(red: 0.88, green: 0.90, blue: 0.97)
      }
  }

  private func activityImageName(for activity: Activity.BuiltInActivity) -> String {
      switch activity {
      case .play: return "Activity_Play"
      case .sleep: return "Activity_Sleep"
      case .study: return "Activity_Study"
      case .eat: return "Activity_Eat"
      case .getReady: return "Activity_GetReady"
      case .wakeUp: return "Activity_WakeUp"
      }
  }
}

#Preview {
  PickActivityView(selectedPlace: .house)
}
