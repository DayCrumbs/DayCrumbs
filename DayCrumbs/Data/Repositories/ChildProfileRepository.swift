//
//  ChildProfileRepository.swift
//  DayCrumbs
//
//  Created by Vrz on 17/07/26.
//

import Foundation
import SwiftData

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

    /// Mengambil profil anak yang saat ini aktif (mengembalikan profil pertama yang ditemukan).
    func fetchActiveProfile() throws -> ChildProfile? {
        let descriptor = FetchDescriptor<ChildProfile>()
        let profiles = try modelContext.fetch(descriptor)
        return profiles.first
    }

    /// Menyimpan profil anak baru ke database lokal.
    /// Skenario anak pertama: Jika sudah ada profil lama, profil tersebut akan dihapus terlebih dahulu untuk mencegah duplikasi.
    func saveProfile(_ profile: ChildProfile) throws {
        if let existing = try fetchActiveProfile() {
            modelContext.delete(existing)
        }
        modelContext.insert(profile)
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
