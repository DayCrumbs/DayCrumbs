//
//  ChildProfileRepository.swift
//  DayCrumbs
//
//  Created by Vrz on 17/07/26.
//

import Foundation
import SwiftData

enum ChildProfileRepositoryError: LocalizedError, Equatable {
    case multipleProfilesFound

    var errorDescription: String? {
        switch self {
        case .multipleProfilesFound:
            "More than one child profile was found. Please resolve the local data before continuing."
        }
    }
}

@MainActor
protocol ChildProfileRepositoryProtocol {
    func fetchActiveProfile() throws -> ChildProfile?
    func saveProfile(_ profile: ChildProfile) throws
    func updateProfile(name: String, age: Int, gender: ChildGender) throws
    func deleteProfile() throws
}

@MainActor
final class ChildProfileRepository: ChildProfileRepositoryProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// The app supports exactly one child profile. Multiple records are a data-integrity error.
    func fetchActiveProfile() throws -> ChildProfile? {
        let descriptor = FetchDescriptor<ChildProfile>()
        let profiles = try modelContext.fetch(descriptor)

        guard profiles.count <= 1 else {
            throw ChildProfileRepositoryError.multipleProfilesFound
        }

        return profiles.first
    }

    /// Creates a profile only when none exists; otherwise, updates the existing profile.
    func saveProfile(_ profile: ChildProfile) throws {
        if let existing = try fetchActiveProfile() {
            existing.name = profile.name
            existing.age = profile.age
            existing.gender = profile.gender
        } else {
            modelContext.insert(profile)
        }
        try modelContext.save()
    }

    /// Memperbarui data profil anak yang ada, atau membuat baru jika belum terdaftar.
    func updateProfile(name: String, age: Int, gender: ChildGender) throws {
        if let profile = try fetchActiveProfile() {
            profile.name = name
            profile.age = age
            profile.gender = gender
            try modelContext.save()
        } else {
            let newProfile = ChildProfile(name: name, age: age, gender: gender)
            try saveProfile(newProfile)
        }
    }

    /// Menghapus profil anak beserta seluruh data terkait (DailySessions akan terhapus otomatis karena deleteRule: .cascade).
    func deleteProfile() throws {
        if let profile = try fetchActiveProfile() {
            modelContext.delete(profile)
            try modelContext.save()
        }
    }
}
