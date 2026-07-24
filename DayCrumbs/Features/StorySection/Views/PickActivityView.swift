//
//  PickActivityView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/17/26.
//

import SwiftUI

struct PickActivityView: View {
  @Environment(StoryFlowCoordinator.self) private var storyFlow

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
                      characterImageName: StoryCharacterAsset.imageName(
                          for: .activity,
                          gender: storyFlow.childGender
                      ),
                      text: "Awesome! Keep the story going.\nWhat were you doing here?"
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
                          storyFlow.selectActivity(
                              activity,
                              in: selectedSession,
                              place: selectedPlace
                          )
                      },
                      itemImageName: {
                          viewModel.activityImageName(
                              for: $0,
                              gender: storyFlow.childGender
                          )
                      }
                  )
                  .frame(height: proxy.size.height * 0.26)
              }
              .frame(width: proxy.size.width, height: proxy.size.height)
              
              CircularBackButton() {
                  storyFlow.goBack()
              }
              .padding(.top, 24)
              .padding(.leading, 32)
          }
      }
      .navigationBarBackButtonHidden(true)
  }
}

#Preview {
  NavigationStack {
      PickActivityView(selectedSession: .morning, selectedPlace: .house)
  }
  .environment(StoryFlowCoordinator())
}
