//
//  ChildeProfileSetupViewModel.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI
import Foundation

@Observable
final class ChildProfileSetupViewModel {
    // MARK: - Properties
    var childName: String = ""
    var childAge: Int = 0
    var childAgeText: String = "" {
        didSet {
            childAge = Int(childAgeText) ?? 0
        }
    }
    var selectedGender: ChildGender? = .boy
    var errorMessage: String? = nil
    var navigationRoute: StoryFlowRoute?
    private var hasLoadedExistingProfile = false
    
    // MARK: - Computed Properties
    var isFormValid: Bool {
        nameValidationMessage == nil &&
        ageValidationMessage == nil &&
        selectedGender != nil
    }

    var nameValidationMessage: String? {
        let trimmedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return "Name is required."
        }

        if trimmedName.rangeOfCharacter(from: .decimalDigits) != nil {
            return "Name cannot contain numbers."
        }

        let allowedCharacters = CharacterSet.letters
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-'"))
        if trimmedName.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return "Use letters, spaces, hyphens, or apostrophes only."
        }

        return nil
    }

    var ageValidationMessage: String? {
        let trimmedAge = childAgeText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAge.isEmpty else {
            return "Age is required."
        }

        guard trimmedAge.rangeOfCharacter(from: .decimalDigits.inverted) == nil else {
            return "Age can only contain numbers."
        }

        guard let age = Int(trimmedAge), (1...18).contains(age) else {
            return "Age must be between 1 and 18."
        }

        return nil
    }
    
    @MainActor
    func selectGender(_ gender: ChildGender) {
        selectedGender = gender
    }

    @MainActor
    func loadExistingProfile(using repository: ChildProfileRepository) {
        guard !hasLoadedExistingProfile else { return }

        do {
            if let profile = try repository.fetchActiveProfile() {
                childName = profile.name
                childAge = profile.age
                childAgeText = String(profile.age)
                selectedGender = profile.gender
            }
            errorMessage = nil
            hasLoadedExistingProfile = true
        } catch {
            errorMessage = "Gagal memuat profil: \(error.localizedDescription)"
        }
    }

    @MainActor
    @discardableResult
    func saveProfile(using repository: ChildProfileRepository) -> Bool {
        guard isFormValid, let gender = selectedGender else { return false }

        do {
            try repository.updateProfile(
                name: childName,
                age: childAge,
                gender: gender
            )
            self.errorMessage = nil
            hasLoadedExistingProfile = true
            navigationRoute = .sessionOption
            print("Profil \(childName) berhasil disimpan!")
            return true
        } catch {
            self.errorMessage = "Gagal menyimpan profil: \(error.localizedDescription)"
            print("Error: \(error)")
            return false
        }
    }
}
