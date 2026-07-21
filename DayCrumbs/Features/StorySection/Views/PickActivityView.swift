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
  @State private var viewModel = PickActivityViewModel()
  
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
                      items: viewModel.activityOptions,
                      selectedItem: $viewModel.selectedActivity,
                      itemName: { $0.rawValue },
                      onAddCustom: {
                          // Custom activity creation will be added in a later flow.
                      },
                      onSelectItem: { activity in
                          viewModel.handleActivitySelection(
                              activity,
                              session: selectedSession,
                              place: selectedPlace
                          )
                      },
                      itemImageName: viewModel.activityImageName(for:)
                  )
                  .frame(height: proxy.size.height * 0.26)
              }
              .frame(width: proxy.size.width, height: proxy.size.height)
              
              CircularBackButton() {
                  dismiss()
              }
              .padding(.top, 24)
              .padding(.leading, 32)
          }
      }
      .navigationBarBackButtonHidden(true)
      .storyFlowNavigationDestination(route: $viewModel.navigationRoute)
  }
}

#Preview {
  PickActivityView(selectedSession: .morning, selectedPlace: .house)
}
