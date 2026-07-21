//
//  StoryFlowRepositoryTests.swift
//  DayCrumbsTests
//
//  Created by Vrz on 21/07/26.
//

import Foundation
import Testing
import SwiftData

@testable import DayCrumbs

@Suite("Story flow repository")
@MainActor
struct StoryFlowRepositoryTests {
    
    // Helper untuk menyiapkan environment database in-memory bersih beserta profil anak
    private func setupContext() throws -> (StoryFlowRepository, ModelContext, ChildProfile) {
        let container = try DayCrumbsModelContainer.makeInMemoryContainer()
        let context = ModelContext(container)
        let repository = StoryFlowRepository(modelContext: context)
        
        let profile = ChildProfile(name: "Maya", age: 3, gender: .girl)
        context.insert(profile)
        try context.save()
        
        return (repository, context, profile)
    }
    
    // MARK: - Pengujian saveActivity()
    
    @Test("Saving an activity creates a new daily session if none exists for today")
    func saveActivityCreatesSession() throws {
        let (repository, context, profile) = try setupContext()
        
        try repository.saveActivity(
            for: profile,
            session: .morning,
            place: .house,
            activity: .wakeUp,
            mood: .happy,
            discussion: "Maya bangun pagi langsung tersenyum."
        )
        
        // Verifikasi DailySession berhasil dibuat otomatis
        let sessions = try context.fetch(FetchDescriptor<DailySession>())
        #expect(sessions.count == 1)
        
        let session = sessions.first!
        #expect(session.childProfile?.persistentModelID == profile.persistentModelID)
        
        // Verifikasi StoryEntry tersimpan dan terhubung ke sesi tersebut
        #expect(session.entries.count == 1)
        let entry = session.entries.first!
        #expect(entry.session == .morning)
        #expect(entry.place == .house)
        #expect(entry.activity == .wakeUp)
        #expect(entry.mood == .happy)
        #expect(entry.afterActivityNotes?.text == "Maya bangun pagi langsung tersenyum.")
    }
    
    @Test("Saving an activity reuses the existing daily session of today")
    func saveActivityReusesExistingSession() throws {
        let (repository, context, profile) = try setupContext()
        
        // Daftarkan sesi manual untuk hari ini terlebih dahulu
        let existingSession = DailySession(startedAt: .now, childProfile: profile)
        context.insert(existingSession)
        try context.save()
        
        try repository.saveActivity(
            for: profile,
            session: .afternoon,
            place: .school,
            activity: .eat,
            mood: .happy,
            discussion: "Makan siang dengan lahap."
        )
        
        let sessions = try context.fetch(FetchDescriptor<DailySession>())
        // Memastikan tidak ada duplikasi sesi harian (tetap berjumlah 1)
        #expect(sessions.count == 1)
        
        let session = sessions.first!
        #expect(session.entries.count == 1)
    }

    @Test("Saving an activity with empty or whitespace-only discussion does not create after-activity notes")
    func saveActivityWithEmptyDiscussion() throws {
        let (repository, context, profile) = try setupContext()
        
        try repository.saveActivity(
            for: profile,
            session: .evening,
            place: .outdoor,
            activity: .play,
            mood: .happy,
            discussion: "   " // Hanya berisi spasi (whitespaces)
        )
        
        let entries = try context.fetch(FetchDescriptor<StoryEntry>())
        #expect(entries.count == 1)
        // Catatan aktivitas harus nil karena represents teks kosong
        #expect(entries.first?.afterActivityNotes == nil)
    }

    // MARK: - Pengujian saveEndOfDayReflection()

    @Test("Saving end-of-day reflection creates a new reflection and ends the session")
    func saveReflectionNew() throws {
        let (repository, context, profile) = try setupContext()
        
        // Jalankan satu aktivitas terlebih dahulu untuk memicu inisiasi DailySession
        try repository.saveActivity(
            for: profile,
            session: .morning,
            place: .house,
            activity: .wakeUp,
            mood: .happy,
            discussion: nil
        )
        
        try repository.saveEndOfDayReflection("Secara umum hari ini berjalan dengan lancar.", for: profile)
        
        let sessions = try context.fetch(FetchDescriptor<DailySession>())
        #expect(sessions.count == 1)
        
        let session = sessions.first!
        #expect(session.endedAt != nil) // Waktu berakhir harus terisi
        #expect(session.isCompleted)    // Sesi harus bernilai komplit
        #expect(session.endOfDayReflection?.text == "Secara umum hari ini berjalan dengan lancar.")
    }

    @Test("Saving end-of-day reflection updates an existing reflection and its modification timestamp")
    func saveReflectionUpdatesExisting() throws {
        let (repository, context, profile) = try setupContext()
        
        // Daftarkan sesi manual dengan refleksi awal (diberi jarak 10 detik ke belakang)
        let session = DailySession(startedAt: .now, childProfile: profile)
        let initialReflection = EndOfDayReflection(
            text: "Teks Awal",
            createdAt: .now - 10,
            dailySession: session
        )
        session.endOfDayReflection = initialReflection
        context.insert(session)
        context.insert(initialReflection)
        try context.save()
        
        try repository.saveEndOfDayReflection("Teks Diperbarui", for: profile)
        
        let reflections = try context.fetch(FetchDescriptor<EndOfDayReflection>())
        #expect(reflections.count == 1)
        
        let reflection = reflections.first!
        #expect(reflection.text == "Teks Diperbarui")
        // Memastikan waktu pembaruan (updatedAt) lebih baru dari waktu pembuatan (createdAt)
        #expect(reflection.updatedAt > reflection.createdAt)
    }

    @Test("Daily session from yesterday is not reused for today's activities")
    func dailySessionFromYesterdayNotReused() throws {
        let (repository, context, profile) = try setupContext()
        let calendar = Calendar.current
        
        // Daftarkan sesi manual untuk kemarin (1 hari sebelum .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: .now)!
        let yesterdaySession = DailySession(startedAt: yesterday, childProfile: profile)
        context.insert(yesterdaySession)
        try context.save()
        
        // Simpan aktivitas untuk hari ini
        try repository.saveActivity(
            for: profile,
            session: .morning,
            place: .house,
            activity: .wakeUp,
            mood: .happy,
            discussion: nil
        )
        
        let sessions = try context.fetch(FetchDescriptor<DailySession>())
        // Sesi hari kemarin tidak boleh dicampur dengan hari ini, sehingga harus ada 2 sesi terpisah
        #expect(sessions.count == 2)
    }
}
