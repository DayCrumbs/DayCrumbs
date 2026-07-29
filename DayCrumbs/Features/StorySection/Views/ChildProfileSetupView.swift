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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(StoryFlowCoordinator.self) private var storyFlow
    @State private var viewModel = ChildProfileSetupViewModel()
    @FocusState private var focusedField: ProfileField?
    @State private var hasEditedName = false
    @State private var hasEditedAge = false
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                AppColour.bgPutih
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ScrollView {
                    Group {
                        if dynamicTypeSize.isAccessibilitySize
                            || proxy.size.width < 920 {
                            compactProfileContent(in: proxy.size)
                        } else {
                            wideProfileContent(in: proxy.size)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 92)
                    .padding(.bottom, 36)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
                }

                CircularBackButton(style: .yellowBtn) {
                    storyFlow.goBack()
                }
                .padding(.top, 24)
                .padding(.leading, 32)
                .accessibilityHint("Returns to onboarding.")
            }
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

    private func wideProfileContent(in size: CGSize) -> some View {
        HStack(spacing: min(200, max(72, size.width * 0.12))) {
            profileIllustration(width: min(300, size.width * 0.25))
            profileForm
                .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity)
    }

    private func compactProfileContent(in size: CGSize) -> some View {
        VStack(spacing: 32) {
            profileIllustration(width: min(250, size.width * 0.42))
            profileForm
                .frame(maxWidth: 640)
        }
        .frame(maxWidth: .infinity)
    }

    private func profileIllustration(width: CGFloat) -> some View {
        Image(viewModel.selectedGender == .boy ? "Profile_Boy" : "Profile_Girl")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }

    private var profileForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Set Up Your Child's Profile")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(AppColour.txtCoklat)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 24) {
                profileFieldRow(title: "Name") {
                    nameInput
                }

                profileFieldRow(title: "Age") {
                    ageInput
                }

                profileFieldRow(title: "Gender") {
                    genderInput
                }

                saveProfileButton
                    .padding(.top, 8)
            }
            .padding(dynamicTypeSize.isAccessibilitySize ? 24 : 32)
            .background(AppColour.cardKuning)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    @ViewBuilder
    private func profileFieldRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                profileFieldLabel(title)
                content()
                    .frame(maxWidth: .infinity)
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                profileFieldLabel(title)
                    .frame(width: 80, alignment: .leading)
                    .padding(.top, 12)
                content()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func profileFieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .rounded))
            .foregroundColor(AppColour.txtCoklat)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("What is your child's name?", text: $viewModel.childName)
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
                .accessibilityLabel("Child's name")
                .accessibilityHint("Enter the child's name using letters.")

            if shouldShowNameError,
               let message = viewModel.nameValidationMessage {
                validationMessage(message)
            }
        }
    }

    private var ageInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("How old is your child?", text: $viewModel.childAgeText)
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
                .accessibilityLabel("Child's age")
                .accessibilityHint("Enter the child's age using numbers.")

            if shouldShowAgeError,
               let message = viewModel.ageValidationMessage {
                validationMessage(message)
            }
        }
    }

    private var genderInput: some View {
        HStack(spacing: 0) {
            ForEach(ChildGender.allCases, id: \.self) { gender in
                genderSegment(for: gender)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.3))
        .clipShape(Capsule())
        .accessibilityElement(children: .contain)
    }

    private var saveProfileButton: some View {
        Button(action: {
            let repository = ChildProfileRepository(modelContext: modelContext)
            if viewModel.saveProfile(using: repository) {
                AppIconManager.updateIcon(
                    isBoy: viewModel.selectedGender == .boy
                )
                storyFlow.didSaveChildProfile(using: repository)
            }
        }) {
            Text("Save Profile")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(AppColour.txtPutih)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.vertical, 8)
                .background(AppColour.btnCoklat)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isFormValid)
        .accessibilityLabel("Save child profile")
        .accessibilityValue(viewModel.isFormValid ? "Available" : "Unavailable")
        .accessibilityHint(
            viewModel.isFormValid
                ? "Saves the child profile and continues to session selection."
                : "Enter a valid name and age before saving the profile."
        )
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
        .accessibilityLabel("\(gender.rawValue.capitalized) gender")
        .accessibilityHint("Selects \(gender.rawValue) as the child's gender.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack {
        ChildProfileSetupView()
    }
    .environment(StoryFlowCoordinator())
}
