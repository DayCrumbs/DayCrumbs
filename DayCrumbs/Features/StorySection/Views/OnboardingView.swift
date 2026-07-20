//
//  OnboardingView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
        
    var body: some View {
        ZStack {
            AppColour.bgPutih
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .background(Color.black)
                    .aspectRatio(4/3, contentMode: .fit)
                    .frame(maxWidth: 600)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "photo.artframe")
                                .font(.system(size: 64))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Ilustrasi akan ditempatkan di sini")
                                .font(.title3)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    )
                    .padding(.horizontal, 40)
                                
                Button(action: {
                    viewModel.startStory()
                }) {
                    Text("Start The Story")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .background(AppColour.btnKuning)
                .clipShape(Capsule())
                .frame(maxWidth: 500)
                .padding(.top, 80)
                .padding(.bottom, 20)
                
                Button(action: {
                    viewModel.openModels()
                }) {
                    Text("Models")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .background(AppColour.btnKuning)
                .clipShape(Capsule())
                .frame(maxWidth: 500)
                .padding(.bottom, 20)
                
                Button(action: {
                    viewModel.openDashboard()
                }) {
                    Text("Dashboard")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
                .background(AppColour.btnKuning)
                .clipShape(Capsule())
                .frame(maxWidth: 500)
                
                Spacer()
            }
        }
        
        .navigationDestination(isPresented: $viewModel.navigateToModel) {
            ModelsView()
        }
        
        .navigationDestination(isPresented: $viewModel.navigateToDashboard) {
            DashboardView()
        }
        .navigationDestination(isPresented: $viewModel.navigateToProfile) {
            ChildProfileSetupView()
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    OnboardingView()
}
