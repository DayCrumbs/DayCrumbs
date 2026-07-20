//
//  ChildProfileSetupView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI
import SwiftData

struct ChildProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ChildProfileSetupViewModel()
    
    var body: some View {
        ZStack {
            AppColour.bgPutih
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    CircularBackButton(style: .yellowBtn) {
                        dismiss()
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                
                Spacer()
            }
            
            HStack(spacing: 200) {
                
                Image(viewModel.selectedGender == .boy ? "Profile_Boy" : "Profile_Girl")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 500)
                    .frame(width: 300)
                
                // --- KANAN: FORM ---
                VStack(alignment: .leading, spacing: 24) {
                    
                    Text("Set Up Your Child's Profile")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundColor(AppColour.txtCoklat)
                    
                    // Card Form
                    VStack(spacing: 24) {
                        
                        // Baris 1: Name
                        HStack {
                            Text("Name")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("What is your name", text: $viewModel.childName)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(AppColour.txtCoklat)
                        }
                        
                        // Baris 2: Age
                        HStack {
                            Text("Age")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            TextField("How old are you", text: $viewModel.childAgeText)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(16)
                                .foregroundColor(AppColour.txtCoklat)
                        }
                        
                        // Baris 3: Gender
                        HStack {
                            Text("Gender")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                            
                            HStack(spacing: 0) {
                                ForEach(ChildGender.allCases, id: \.self) { gender in
                                    genderSegment(for: gender)
                                }
                            }
                            .padding(3)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Capsule())
                        }
                        
                        // Baris 4: Save Button
                        Button(action: {
                            // Inisialisasi repositori menggunakan modelContext
                            let repository = ChildProfileRepository(modelContext: modelContext)
                            viewModel.saveProfile(using: repository)
                        }) {
                            Text("Save Profile")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    AppColour.btnPutih.opacity(viewModel.isFormValid ? 1 : 0.45)
                                )
                                .clipShape(Capsule())
                        }
                        .disabled(!viewModel.isFormValid)
                        .accessibilityHint(
                            viewModel.isFormValid
                                ? "Menyimpan profil anak"
                                : "Masukkan nama dan umur anak yang valid untuk menyimpan profil"
                        )
                        .padding(.top, 8)
                        
                    }
                    .padding(32)
                    .background(AppColour.cardKuning)
                    .cornerRadius(24)
                    
                }
                .frame(maxWidth: 500)
            }
            .padding(.horizontal, 40)
        }
        .navigationBarBackButtonHidden(true)
        .storyFlowNavigationDestination(route: $viewModel.navigationRoute)
    }
    
    // MARK: - Komponen Bantuan
    @ViewBuilder
    private func genderSegment(for gender: ChildGender) -> some View {
        let isSelected = viewModel.selectedGender == gender
        
        Button(action: {
            viewModel.selectGender(gender)
        }) {
            Text(gender.rawValue.capitalized)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(AppColour.txtCoklat)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(isSelected ? AppColour.btnPutih : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

#Preview {
    ChildProfileSetupView()
}
