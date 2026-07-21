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
        !childName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        childAge > 0 &&
        selectedGender != nil
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
    func saveProfile(using repository: ChildProfileRepository) {
        guard isFormValid, let gender = selectedGender else { return }

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
        } catch {
            self.errorMessage = "Gagal menyimpan profil: \(error.localizedDescription)"
            print("Error: \(error)")
        }
    }
}
