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
    
    // MARK: - Computed Properties
    var isFormValid: Bool {
        !childName.trimmingCharacters(in: .whitespaces).isEmpty &&
        childAge > 0 &&
        selectedGender != nil
    }
    
    @MainActor
    func selectGender(_ gender: ChildGender) {
        selectedGender = gender
    }

    @MainActor
    func saveProfile(using repository: ChildProfileRepository) {
        guard isFormValid, let gender = selectedGender else { return }
        
        let newProfile = ChildProfile(
            name: childName,
            age: childAge,
            gender: gender
        )
        
        do {
            try repository.saveProfile(newProfile)
            self.errorMessage = nil
            navigationRoute = .sessionOption
            print("Profil \(childName) berhasil disimpan!")
        } catch {
            self.errorMessage = "Gagal menyimpan profil: \(error.localizedDescription)"
            print("Error: \(error)")
        }
    }
}
