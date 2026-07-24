//
//  ChildProfileSetupView.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI
import SwiftData

struct ChildProfileSetupView: View {
    private enum ProfileField: Hashable {
        case name
        case age
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    @State private var viewModel = ChildProfileSetupViewModel()
    @FocusState private var focusedField: ProfileField?
    @State private var hasEditedName = false
    @State private var hasEditedAge = false
    
    var body: some View {
        ZStack {
            AppColour.bgPutih
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    CircularBackButton(style: .yellowBtn) {
                        storyFlow.goBack()
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
                        HStack(alignment: .top) {
                            Text("Name")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                                .padding(.top, 12)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("What is your name?", text: $viewModel.childName)
                                    .focused($focusedField, equals: .name)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                shouldShowNameError ? Color.red : .clear,
                                                lineWidth: 1
                                            )
                                    }
                                    .foregroundColor(AppColour.txtCoklat)

                                if shouldShowNameError, let message = viewModel.nameValidationMessage {
                                    validationMessage(message)
                                }
                            }
                        }
                        
                        // Baris 2: Age
                        HStack(alignment: .top) {
                            Text("Age")
                                .font(.system(.title3, design: .rounded))
                                .foregroundColor(AppColour.txtCoklat)
                                .frame(width: 80, alignment: .leading)
                                .padding(.top, 12)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("How old are you?", text: $viewModel.childAgeText)
                                    .focused($focusedField, equals: .age)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                shouldShowAgeError ? Color.red : .clear,
                                                lineWidth: 1
                                            )
                                    }
                                    .foregroundColor(AppColour.txtCoklat)

                                if shouldShowAgeError, let message = viewModel.ageValidationMessage {
                                    validationMessage(message)
                                }
                            }
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
                            if viewModel.saveProfile(using: repository) {
                                storyFlow.didSaveChildProfile(using: repository)
                            }
                        }) {
                            Text("Save Profile")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(AppColour.txtPutih)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    AppColour.btnCoklat.opacity(viewModel.isFormValid ? 1 : 0.45)
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
        .task {
            let repository = ChildProfileRepository(modelContext: modelContext)
            viewModel.loadExistingProfile(using: repository)
        }
        .onChange(of: viewModel.childName) { _, _ in
            hasEditedName = true
        }
        .onChange(of: viewModel.childAgeText) { _, _ in
            hasEditedAge = true
        }
        .onChange(of: focusedField) { previousField, currentField in
            if previousField == .name, currentField != .name {
                hasEditedName = true
            }
            if previousField == .age, currentField != .age {
                hasEditedAge = true
            }
        }
    }

    private var shouldShowNameError: Bool {
        hasEditedName && viewModel.nameValidationMessage != nil
    }

    private var shouldShowAgeError: Bool {
        hasEditedAge && viewModel.ageValidationMessage != nil
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(.red)
            .accessibilityLabel("Validation error: \(message)")
    }
    
    @ViewBuilder
    private func genderSegment(for gender: ChildGender) -> some View {
        let isSelected = viewModel.selectedGender == gender
        
        Button {
            viewModel.selectGender(gender)
        } label: {
            Text(gender.rawValue.capitalized)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundColor(AppColour.txtCoklat)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppColour.btnCoklat : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

#Preview {
    NavigationStack {
        ChildProfileSetupView()
    }
    .environment(StoryFlowCoordinator())
}
