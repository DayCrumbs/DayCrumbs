//
//  ChildeProfileSetupViewModel.swift
//  DayCrumbs
//
//  Created by Ibnu Taufick Ahraza on 7/14/26.
//

import SwiftUI
import Foundation

@Observable
class ChildProfileSetupViewModel {
    // MARK: - Properties
    var childName: String = ""
    var childAge: String = ""
    var selectedGender: ChildGender? = nil // Menggunakan enum baru
    
    // MARK: - Computed Properties
    var isFormValid: Bool {
        !childName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !childAge.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedGender != nil
    }
    
    // MARK: - Actions
    func saveProfile() {
        guard isFormValid else { return }
        
        print("Data Siap Disimpan!")
        print("Nama: \(childName)")
        print("Umur: \(childAge)")
        print("Gender: \(selectedGender?.rawValue.capitalized ?? "Belum diisi")")
    }
}
