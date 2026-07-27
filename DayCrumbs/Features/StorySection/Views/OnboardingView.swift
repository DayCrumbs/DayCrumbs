//
//  OnboardingView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(StoryFlowCoordinator.self) private var storyFlow
        
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppColour.bgPutih
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ScrollView {
                    VStack(spacing: 40) {
                        Image("Onboarding_DayCrumbs")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 1000)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "Welcome to DayCrumbs, guided storytelling for your child's day."
                            )
                            .accessibilityAddTraits(.isHeader)

                        Button(action: {
                            storyFlow.showChildProfileSetup()
                        }) {
                            Text("Start The Story")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(AppColour.txtPutih)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .padding(.vertical, 10)
                        }
                        .background(AppColour.btnCoklat)
                        .clipShape(Capsule())
                        .frame(maxWidth: 500)
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start the story")
                        .accessibilityHint("Opens child profile setup.")
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 36)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingView()
        .environment(StoryFlowCoordinator())
}
