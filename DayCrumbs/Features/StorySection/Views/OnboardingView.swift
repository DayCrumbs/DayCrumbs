//
//  OnboardingView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI

struct OnboardingView: View {
    
    @State private var navigateToProfile: Bool = false
    @State private var navigateToDashboard: Bool = false
    @State private var navigateToModel: Bool = false
        
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
                    navigateToProfile = true
                    print("Tombol Start ditekan") //buat ngecek
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
                    navigateToModel = true
                    print("Tombol Start ditekan") //buat ngecek
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
                    navigateToDashboard = true
                    print("Tombol Start ditekan") //buat ngecek
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
        
        .navigationDestination(isPresented: $navigateToModel) {
            ModelsView()
        }
        
        .navigationDestination(isPresented: $navigateToDashboard) {
            DashboardView()
        }
        .navigationDestination(isPresented: $navigateToProfile) {
            ChildProfileSetupView()
        }
    }
}

#Preview {
    OnboardingView()
}
