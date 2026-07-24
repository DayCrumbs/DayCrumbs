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
        ZStack {
            AppColour.bgPutih
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                Image("Onboarding_DayCrumbs")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 1000)
                    .padding(.horizontal, 40)
                                
                Button(action: {
                    storyFlow.showChildProfileSetup()
                }) {
                    Text("Start The Story")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtPutih)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .background(AppColour.btnCoklat)
                .clipShape(Capsule())
                .frame(maxWidth: 500)
                .padding(.top, 80)
                .padding(.bottom, 20)

                
                Spacer()
            }
        }

        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingView()
        .environment(StoryFlowCoordinator())
}
