//
//  ChildProfileRepositoryTests.swift
//  DayCrumbsTests
//
//  Created by Vrz on 21/07/26.
//

import Foundation
import Testing
import SwiftData

@testable import DayCrumbs

@Suite("Child profile repository")
@MainActor
struct ChildProfileRepositoryTests {
    
    // Helper untuk membuat repositori baru dengan kontainer database in-memory yang bersih
    private func makeRepository() throws -> (ChildProfileRepository, ModelContext) {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = ModelContext(container)
        let repository = ChildProfileRepository(modelContext: context)
        return (repository, context)
    }
    
    // MARK: - Pengujian fetchActiveProfile()
    
    @Test("Fetching active profile when empty returns nil")
    func fetchActiveProfileWhenEmpty() throws {
        let (repository, _) = try makeRepository()
        
        let profile = try repository.fetchActiveProfile()
        
        #expect(profile == nil)
    }
    
    @Test("Fetching active profile when one exists returns that profile")
    func fetchActiveProfileWhenOneExists() throws {
        let (repository, context) = try makeRepository()
        let newProfile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        context.insert(newProfile)
        try context.save()
        
        let fetchedProfile = try repository.fetchActiveProfile()
        
        #expect(fetchedProfile != nil)
        #expect(fetchedProfile?.name == "Maya")
        #expect(fetchedProfile?.age == 3)
        #expect(fetchedProfile?.gender == .girl)
    }
    
    @Test("Fetching active profile throws error when multiple profiles exist")
    func fetchActiveProfileThrowsOnMultiple() throws {
        let (repository, context) = try makeRepository()
        let firstProfile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        let secondProfile = ChildProfile(name: "Leo", age: 4, gender: .boy)
        context.insert(firstProfile)
        context.insert(secondProfile)
        try context.save()
        
        #expect(throws: ChildProfileRepositoryError.multipleProfilesFound) {
            try repository.fetchActiveProfile()
        }
    }
    
    // MARK: - Pengujian saveProfile()
    
    @Test("Saving a profile when none exists inserts the profile")
    func saveProfileWhenNoneExists() throws {
        let (repository, context) = try makeRepository()
        let profile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        
        try repository.saveProfile(profile)
        
        // Verifikasi langsung ke SwiftData model context
        let descriptor = FetchDescriptor<ChildProfile>()
        let storedProfiles = try context.fetch(descriptor)
        
        #expect(storedProfiles.count == 1)
        #expect(storedProfiles.first?.name == "Maya")
    }
    
    @Test("Saving a profile when one exists updates the existing profile instead of creating a duplicate")
    func saveProfileWhenOneExistsUpdatesExisting() throws {
        let (repository, context) = try makeRepository()
        let initialProfile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        context.insert(initialProfile)
        try context.save()
        
        // Buat objek profil baru dengan data berbeda untuk memperbarui profil yang ada
        let updatedProfile = ChildProfile(name: "Maya Olivia", age: 4, gender: .girl)
        try repository.saveProfile(updatedProfile)
        
        let descriptor = FetchDescriptor<ChildProfile>()
        let storedProfiles = try context.fetch(descriptor)
        
        #expect(storedProfiles.count == 1) // Memastikan tidak ada duplikasi record
        #expect(storedProfiles.first?.name == "Maya Olivia")
        #expect(storedProfiles.first?.age == 4)
    }
    
    // MARK: - Pengujian updateProfile()
    
    @Test("Updating a profile updates its fields")
    func updateProfileWhenOneExists() throws {
        let (repository, context) = try makeRepository()
        let initialProfile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        context.insert(initialProfile)
        try context.save()
        
        try repository.updateProfile(name: "Maya Olivia", age: 4, gender: .girl)
        
        let descriptor = FetchDescriptor<ChildProfile>()
        let storedProfiles = try context.fetch(descriptor)
        
        #expect(storedProfiles.count == 1)
        #expect(storedProfiles.first?.name == "Maya Olivia")
        #expect(storedProfiles.first?.age == 4)
        #expect(storedProfiles.first?.gender == .girl)
    }
    
    @Test("Updating a profile when none exists creates and saves a new profile")
    func updateProfileWhenNoneExists() throws {
        let (repository, context) = try makeRepository()
        
        try repository.updateProfile(name: "Leo", age: 2, gender: .boy)
        
        let descriptor = FetchDescriptor<ChildProfile>()
        let storedProfiles = try context.fetch(descriptor)
        
        #expect(storedProfiles.count == 1)
        #expect(storedProfiles.first?.name == "Leo")
        #expect(storedProfiles.first?.age == 2)
        #expect(storedProfiles.first?.gender == .boy)
    }
    
    // MARK: - Pengujian deleteProfile()
    
    @Test("Deleting a profile removes it from the database")
    func deleteProfile() throws {
        let (repository, context) = try makeRepository()
        let profile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        context.insert(profile)
        try context.save()
        
        try repository.deleteProfile()
        
        let descriptor = FetchDescriptor<ChildProfile>()
        let storedProfiles = try context.fetch(descriptor)
        
        #expect(storedProfiles.isEmpty)
    }
}
