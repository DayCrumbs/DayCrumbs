//
//  DummyStory.swift
//  DayCrumbs
//
//  Created by Vrz on 16/07/26.
//

import Foundation

enum DummyStory {
    
    struct EntryTemplate {
        let session: Sessions
        let mood: Moods
        let activity: Activity.BuiltInActivity
        let place: Place.BuiltInPlace
        let noteText: String?
    }

    struct DayTemplate {
        let entries: [EntryTemplate]
        let reflectionText: String
    }

    // MARK: - Generator Utama
    /// Menghasilkan array `DailySession` berdasarkan rentang hari (1-based index).
    /// - Parameters:
    ///   - child: Profil anak yang diasosiasikan dengan data dummy.
    ///   - startDay: Hari awal yang ingin diambil (Indeks dimulai dari 1).
    ///   - endDay: Hari akhir yang ingin diambil (Opsional, default adalah hari terakhir dari jumlah template).
    ///   - referenceDate: Tanggal acuan untuk template terbaru; dapat diinjeksi agar test deterministik.
    ///   - calendar: Kalender dan zona waktu yang dipakai untuk membentuk batas hari.
    /// - Returns: Array berisi `DailySession` yang berada dalam rentang tersebut dengan tanggal yang disesuaikan secara logis.
    static func generateSessions(
        for child: ChildProfile,
        startDay: Int = 1,
        endDay: Int? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [DailySession] {
        let maxDays = templates.count
        
        // ERROR HANDLING & PROTEKSI INDEKS (Clamping)
        // 1. Tentukan batas akhir (endDay). Jika nil atau melebihi batas template, turunkan otomatis ke maxDays.
        let resolvedEndDay = min(endDay ?? maxDays, maxDays)
        
        // 2. Tentukan batas awal (startDay). Batasi minimal di angka 1 dan maksimal tidak boleh melampaui resolvedEndDay.
        let resolvedStartDay = max(1, min(startDay, resolvedEndDay))
        
        // Jika parameter setelah penyesuaian masih tidak logis (misalnya start > end), kembalikan array kosong
        guard resolvedStartDay <= resolvedEndDay else { return [] }
        
        // Buat terlebih dahulu semua sesi (seluruh template) agar kalkulasi tanggal mundurnya tepat terhadap "Hari Ini"
        let allSessions = generateAllAvailableSessions(
            for: child,
            referenceDate: referenceDate,
            calendar: calendar
        )
        
        // Slicing menggunakan indeks berbasis 0 (0-based index)
        let startIndex = resolvedStartDay - 1
        let endIndex = resolvedEndDay - 1
        
        return Array(allSessions[startIndex...endIndex])
    }
    
    // MARK: - Helper Internal
    /// Membuat seluruh sesi harian yang tersedia berdasarkan jumlah template.
    private static func generateAllAvailableSessions(
        for child: ChildProfile,
        referenceDate: Date,
        calendar: Calendar
    ) -> [DailySession] {
        let totalTemplates = templates.count
        var sessions: [DailySession] = []

        for i in 0..<totalTemplates {
            // Anchor the newest template to the injected day so tests and
            // development reseeds do not depend on the wall clock.
            let dayOffset = -(totalTemplates - 1 - i)
            guard let baseDate = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: referenceDate
            ) else { continue }
            
            let startOfDay = calendar.startOfDay(for: baseDate)
            let template = templates[i]

            let morningTime = calendar.date(byAdding: .hour, value: 8, to: startOfDay) ?? baseDate
            let afternoonTime = calendar.date(byAdding: .hour, value: 13, to: startOfDay) ?? baseDate
            let eveningTime = calendar.date(byAdding: .hour, value: 17, to: startOfDay) ?? baseDate
            let nightTime = calendar.date(byAdding: .hour, value: 20, to: startOfDay) ?? baseDate
            let endOfDayTime = calendar.date(byAdding: .hour, value: 21, to: startOfDay) ?? baseDate

            let dailySession = DailySession(startedAt: morningTime, childProfile: child)
            dailySession.endedAt = endOfDayTime

            var entries: [StoryEntry] = []
            
            for entryTemplate in template.entries {
                let entryTime: Date
                switch entryTemplate.session {
                case .morning: entryTime = morningTime
                case .afternoon: entryTime = afternoonTime
                case .evening: entryTime = eveningTime
                case .night: entryTime = nightTime
                }

                var notes: AfterActivityNotes? = nil
                if let noteText = entryTemplate.noteText {
                    notes = AfterActivityNotes(text: noteText, createdAt: entryTime)
                }

                let storyEntry = StoryEntry(
                    session: entryTemplate.session,
                    mood: entryTemplate.mood,
                    activity: entryTemplate.activity,
                    place: entryTemplate.place,
                    afterActivityNotes: notes,
                    recordedAt: entryTime,
                    dailySession: dailySession
                )
                
                notes?.storyEntry = storyEntry
                entries.append(storyEntry)
            }

            let reflection = EndOfDayReflection(
                text: template.reflectionText,
                createdAt: endOfDayTime,
                dailySession: dailySession
            )

            dailySession.endOfDayReflection = reflection
            dailySession.entries = entries

            sessions.append(dailySession)
        }

        return sessions
    }
    
    // MARK: - Daftar Template Cerita Harian (Dapat Ditambah kapan saja)
    static let templates: [DayTemplate] = [
        // Hari 1: Sangat Aktif & Bahagia
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .sad, activity: .wakeUp, place: .house, noteText: "Bangun pagi dengan sedih langsung minta minum susu."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Sore hari bermain sepeda di taman komplek."),
                EntryTemplate(session: .night, mood: .fear, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari yang sangat aktif di luar ruangan. Maya tidur dengan cepat karena lelah beraktivitas fisik."
        ),
        
        // Hari 2: Rewel Saat Makan Siang (GTM)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .angry, activity: .eat, place: .house, noteText: "Marah dan menangis saat makan siang karena ada wortel di piringnya."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Kembali ceria setelah diajak bermain boneka bersama."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Ada sedikit drama di siang hari karena masalah makanan (sayur), namun secara umum emosinya stabil kembali setelah bermain."
        ),
        
        // Hari 3: Hari Sekolah
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .getReady, place: .house, noteText: "Semangat bersiap-siap memakai seragam sekolah sendiri."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .study, place: .school, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Bermain perosotan bersama teman sekolahnya setelah pulang."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Transisi ke sekolah berjalan lancar. Maya tampak menikmati waktu bersosialisasi dengan temannya."
        ),
        
        // Hari 4: Kurang Tidur di Pagi Hari
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .sad, activity: .wakeUp, place: .house, noteText: "Sangat rewel saat bangun pagi, menangis tanpa sebab yang jelas."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur siang cukup lama hampir 2 jam."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Setelah tidur siang badannya kembali segar dan moodnya membaik."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Rewel di pagi hari tampaknya disebabkan karena kurang tidur semalam. Masalah teratasi setelah tidur siang yang cukup."
        ),
        
        // Hari 5: Pergi ke Tempat Umum & Sensitif Suara Bising
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .publicPlace, noteText: "Makan siang bersama keluarga di restoran, bersikap tenang."),
                EntryTemplate(session: .evening, mood: .fear, activity: .play, place: .publicPlace, noteText: "Ketakutan dan menangis keras saat mendengar suara mesin pembersih lantai di mall."),
                EntryTemplate(session: .night, mood: .sad, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Maya sempat panik di mall akibat suara bising yang tiba-tiba. Butuh ditenangkan sampai malam sebelum tidur."
        ),
        
        // Hari 6: Aktivitas Dalam Rumah karena Hujan
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: "Bermain mewarnai gambar di ruang tamu."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Karena hujan, bermain petak umpet di dalam rumah bersama Ayah."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Meskipun seharian di dalam rumah karena hujan, Maya tetap ceria dengan aktivitas dalam ruangan yang bervariasi."
        ),
        
        // Hari 7: Akhir Pekan yang Seru
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .play, place: .outdoor, noteText: "Bermain air di kolam renang karet di halaman belakang."),
                EntryTemplate(session: .evening, mood: .surprise, activity: .play, place: .house, noteText: "Terkejut gembira saat diberikan mainan baru oleh Ibu."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari akhir pekan yang sangat menyenangkan bagi Maya. Ia sangat menyukai aktivitas bermain air dan kejutan mainan barunya."
        ),
        
        // Hari 8: Semangat karena Hal Kecil (Pagi Hari Bahagia)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .getReady, place: .house, noteText: "Pagi ini bersemangat memakai kaos kaki bergambar kartun favoritnya."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .study, place: .school, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Senang sekali menggambar bersama Ibu di ruang tamu."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari berjalan sangat baik dengan antusiasme tinggi sejak pagi hari karena hal kecil (kaos kaki bergambar)."
        ),
        
        // Hari 9: Terlalu Lelah Bermain (Cranky Sebelum Tidur)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .outdoor, noteText: "Menikmati bermain pasir di taman perumahan."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .publicPlace, noteText: "Bermain lari-larian di supermarket sampai kelelahan."),
                EntryTemplate(session: .night, mood: .angry, activity: .sleep, place: .house, noteText: "Sangat rewel dan menangis saat mau ditidurkan karena terlalu lelah bermain.")
            ],
            reflectionText: "Maya terlalu aktif bermain di sore hari sehingga melewati batas waktu tidurnya (overtired), memicu tantrum saat tidur malam."
        ),
        
        // Hari 10: Penolakan Sayuran di Makan Malam
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .wakeUp, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .play, place: .house, noteText: "Membangun kastil dari lego bersama Ayah dengan sabar."),
                EntryTemplate(session: .evening, mood: .disgust, activity: .eat, place: .house, noteText: "Menolak makan sup brokoli, menutup mulut rapat-rapat dan mendorong piring."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Makan malam penuh penolakan terhadap brokoli. Namun, emosinya kembali stabil setelah dibacakan buku dongeng sebelum tidur."
        ),
        
        // Hari 11: Ketakutan di Tempat Umum
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .publicPlace, noteText: nil),
                EntryTemplate(session: .evening, mood: .fear, activity: .play, place: .publicPlace, noteText: "Ketakutan melihat boneka maskot berukuran besar di pusat perbelanjaan dan terus memeluk erat Ibu."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur dengan tenang setelah ditenangkan dan diberikan boneka kesayangannya.")
            ],
            reflectionText: "Maya mengalami kecemasan saat melihat karakter maskot yang besar di mall. Dukungan emosional yang cepat membantunya tenang sebelum tidur."
        ),
        
        // Hari 12: Hari Pemulihan (Kondisi Kurang Sehat)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .sad, activity: .wakeUp, place: .house, noteText: "Bangun dengan tubuh agak hangat, tampak lemas dan manja."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur siang sangat nyenyak setelah minum obat hangat."),
                EntryTemplate(session: .evening, mood: .sad, activity: .eat, place: .house, noteText: "Hanya mau makan bubur hangat beberapa suap saja."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari pemulihan karena kurang sehat. Maya lebih banyak menghabiskan waktu dengan istirahat dan tidur siang yang lama."
        ),
        
        // Hari 13: Kembali Aktif Pasca Sembuh
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .getReady, place: .house, noteText: "Senang bisa kembali sehat dan siap-siap ke sekolah."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .study, place: .school, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Bersepeda sore hari di sekitar taman komplek bersama temannya."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Setelah sehat, energinya kembali penuh. Maya sangat senang berinteraksi kembali di sekolah dan bermain di luar."
        ),
        
        // Hari 14: Akhir Pekan Ceria dengan Kejutan
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .play, place: .outdoor, noteText: "Bermain air dan gelembung sabun di halaman rumah bersama sepupu."),
                EntryTemplate(session: .evening, mood: .surprise, activity: .play, place: .house, noteText: "Terkejut bahagia saat dibelikan es krim rasa stroberi kesukaannya."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari akhir pekan yang ditutup dengan manis. Kejutan kecil berupa es krim stroberi membuat emosinya sangat bahagia hingga waktu tidur."
        ),
        
        // Hari 15: Penyesuaian Rutinitas Pagi
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .sad, activity: .getReady, place: .house, noteText: "Pagi ini sempat menangis karena tidak mau ditinggal Ibu saat memakai sepatu."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .study, place: .school, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Menyusun puzzle gambar hewan bersama Ibu setelah mandi sore."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Meskipun sempat cemas di pagi hari saat bersiap-siap, Maya dapat beradaptasi dengan baik di sekolah dan menutup hari dengan tenang."
        ),
        
        // Hari 16: Sensitivitas Sensorik terhadap Rumput Basah
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: "Makan siang lahap dengan menu nasi goreng telur kesukaannya."),
                EntryTemplate(session: .evening, mood: .disgust, activity: .play, place: .outdoor, noteText: "Menolak memegang rumput basah di taman, tampak risih dan langsung meminta digendong."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Maya menunjukkan sensitivitas sensorik terhadap tekstur basah (rumput basah) di sore hari, namun emosinya kembali stabil setelah berada di area kering."
        ),
        
        // Hari 17: Pencapaian Kemandirian & Kejutan Makanan Kreatif
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .wakeUp, place: .house, noteText: "Bangun tidur sendiri tanpa dibangunkan dan langsung tersenyum ceria."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .play, place: .house, noteText: "Berhasil merapikan semua mainan baloknya sendiri ke dalam keranjang."),
                EntryTemplate(session: .evening, mood: .surprise, activity: .eat, place: .house, noteText: "Terkejut senang saat disuapi buah semangka yang dipotong menyerupai bentuk bintang."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Maya menunjukkan kemandirian yang baik hari ini dengan merapikan mainan sendiri. Bentuk makanan yang kreatif juga berhasil memicu antusiasme makannya."
        ),
        
        // Hari 18: Kaget Suara Bising di Dalam Rumah
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .fear, activity: .play, place: .house, noteText: "Sangat terkejut dan ketakutan saat mendengar suara blender yang dinyalakan di dapur, langsung berlari mencari pelukan."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur dengan tenang setelah ditenangkan dengan elusan punggung sebelum tidur.")
            ],
            reflectionText: "Ketakutan terhadap suara bising di dalam rumah sempat membuat Maya kaget, tetapi penjelasan yang tenang dari orang tua membantunya mengatasi rasa takut tersebut."
        ),
        
        // Hari 19: Hari Mengantuk (Growth Spurt)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .sad, activity: .wakeUp, place: .house, noteText: "Tampak masih sangat mengantuk saat dibangunkan pagi hari."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur siang sangat pulas dan lebih lama dari biasanya."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Bermain kejar-kejaran dengan ceria di halaman depan rumah setelah segar kembali."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Kondisi fisik yang tampaknya sedang dalam masa pertumbuhan (growth spurt) membuat Maya membutuhkan waktu tidur siang yang lebih panjang untuk memulihkan energinya."
        ),
        
        // Hari 20: Sosialisasi di Tempat Bermain Umum
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .publicPlace, noteText: "Makan siang dengan tenang di area bermain anak."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .publicPlace, noteText: "Sangat senang bisa berbagi mainan perosotan dengan anak lain di playground tanpa berebut."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari sosialisasi yang berjalan lancar di tempat umum. Maya menunjukkan sikap ramah dan mau berbagi mainan dengan teman barunya."
        ),
        
        // Hari 21: Akhir Pekan yang Aktif dan Menyenangkan
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .getReady, place: .house, noteText: "Bersemangat bersiap-siap memakai topi kesayangannya untuk jalan-jalan sore."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Berlari gembira mengejar gelembung sabun di taman kota."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur dengan senyum di wajahnya setelah hari yang penuh tawa.")
            ],
            reflectionText: "Hari akhir pekan yang menyenangkan. Aktivitas fisik yang cukup di sore hari membuat suasana hatinya positif sepanjang hari hingga waktu tidur."
        ),
        
        // Hari 22: Penolakan Rutinitas Pagi (Masalah Sepatu Baru)
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .angry, activity: .getReady, place: .house, noteText: "Menolak memakai sepatu sekolah yang berbeda dari biasanya, sempat tantrum kecil di teras."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .study, place: .school, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Asyik bermain plastisin membuat berbagai bentuk kue di meja makan."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Tantrum pagi hari dipicu oleh perubahan kecil pada barang pribadinya (sepatu baru). Setelah diberi pengertian, suasana hatinya lekas membaik di sekolah."
        ),
        
        // Hari 23: Kelelahan Fisik di Sore Hari
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .sad, activity: .play, place: .outdoor, noteText: "Menangis karena lelah berlarian terlalu lama di lapangan bola komplek."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Aktivitas fisik sore hari yang terlalu intens membuat fisiknya kelelahan, memicu tangisan di akhir bermain. Ia tidur lebih awal malam ini."
        ),
        
        // Hari 24: Rasa Ingin Tahu saat Belajar Mencampur Warna
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: "Senang sekali menemukan mainan lamanya yang sempat terselip di bawah lemari."),
                EntryTemplate(session: .afternoon, mood: .surprise, activity: .study, place: .school, noteText: "Terkejut gembira saat belajar mencampur warna air di kelas sains sekolah."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Hari yang penuh dengan rasa ingin tahu. Maya sangat antusias menceritakan eksperimen mencampur warna yang ia pelajari hari ini."
        ),
        
        // Hari 25: Tidur Siang Terganggu Suara Bising
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .sad, activity: .sleep, place: .house, noteText: "Tidur siangnya terganggu oleh suara ketukan palu tetangga, bangun dengan kondisi rewel."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Ditenangkan dengan diajak mewarnai buku gambar kesukaannya."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Terbangun mendadak dari tidur siang karena suara bising membuat Maya rewel, tetapi aktivitas mewarnai berhasil mengalihkan perhatian dan menenangkannya."
        ),
        
        // Hari 26: Belajar Berbagi Mainan di Taman Komplek
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .angry, activity: .play, place: .outdoor, noteText: "Sempat berebut mainan sekop pasir dengan anak lain di taman bermain."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Ada konflik kecil saat bermain di luar rumah hari ini. Ini menjadi kesempatan baik untuk mengajarkan konsep berbagi dan mengantre."
        ),
        
        // Hari 27: Waktu Berkualitas di Rumah saat Hujan
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .getReady, place: .house, noteText: "Membantu Ibu menyiapkan meja makan untuk sarapan pagi."),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .house, noteText: "Bermain petak umpet di dalam kamar bersama Ayah karena di luar hujan deras."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Meskipun cuaca hujan membatasi aktivitas luar ruang, Maya tetap tenang dan menikmati waktu berkualitas bersama keluarga di dalam rumah."
        ),
        
        // Hari 28: Takut Bayangan Malam di Kamar Tidur
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .outdoor, noteText: "Bermain kejar-kejaran dengan kucing peliharaan di teras rumah."),
                EntryTemplate(session: .night, mood: .fear, activity: .sleep, place: .house, noteText: "Takut melihat bayangan gorden kamar yang bergerak tertiup angin malam.")
            ],
            reflectionText: "Ketakutan malam hari dipicu oleh imajinasi visual bayangan gorden. Setelah lampu dinyalakan sebentar dan diberi penjelasan, ia bisa tidur kembali."
        ),
        
        // Hari 29: Interaksi Sosial dengan Keluarga Besar
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .happy, activity: .play, place: .house, noteText: nil),
                EntryTemplate(session: .afternoon, mood: .happy, activity: .eat, place: .publicPlace, noteText: "Makan siang bersama sepupu-sepupunya di restoran keluarga dengan ceria."),
                EntryTemplate(session: .evening, mood: .happy, activity: .play, place: .publicPlace, noteText: "Asyik bermain petak umpet di area ramah anak dekat restoran."),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: nil)
            ],
            reflectionText: "Interaksi sosial yang positif dengan keluarga besar. Maya menunjukkan emosi yang stabil dan sangat kooperatif sepanjang hari di tempat umum."
        ),
        
        // Hari 30: Hari Santai Berkebun Ringan
        DayTemplate(
            entries: [
                EntryTemplate(session: .morning, mood: .disgust, activity: .wakeUp, place: .house, noteText: "Bangun tidur agak siang lalu berjemur di halaman belakang bersama Ayah."),
                EntryTemplate(session: .afternoon, mood: .fear, activity: .play, place: .outdoor, noteText: "Membantu menyiram tanaman bunga menggunakan selang air kecil."),
                EntryTemplate(session: .evening, mood: .angry, activity: .eat, place: .house, noteText: nil),
                EntryTemplate(session: .night, mood: .happy, activity: .sleep, place: .house, noteText: "Tidur nyenyak dengan senyuman setelah hari yang tenang.")
            ],
            reflectionText: "Hari yang santai dan agak menyenangkan. Maya hampir menikmati aktivitas berkebun ringan di luar rumah bersama orang tua."
        )
    ]
}

//struct DummyStoryDebug {
//
//    /// Fungsi utama untuk menjalankan semua skenario pengujian debug di konsol.
//    static func runAllTests() {
//        print("====================================")
//        print("🔍 MEMULAI DEBUG DUMMY STORY TEST")
//        print("====================================\n")
//
//        let child = DummyProfile.maya
//
//        // Menjalankan skenario pengujian satu per satu
//        testWeek1(for: child)
//        testWeek4(for: child)
//        testSingleDay(for: child)
//        testFullMonth(for: child)
//
//        print("====================================")
//        print("✅ SEMUA DEBUG TEST SELESAI TANPA ERROR")
//        print("====================================")
//    }
//
//    // MARK: - 1. Ambil data dari day 1 - 7 (Week Pertama)
//    private static func testWeek1(for child: ChildProfile) {
//        print("--- 📂 TEST 1: Ambil Data Day 1 - 7 (Week Pertama) ---")
//        let sessions = DummyStory.generateSessions(for: child, startDay: 1, endDay: 7)
//
//        print("Jumlah hari diperoleh: \(sessions.count) (Target: 7)")
//        if let first = sessions.first, let last = sessions.last {
//            print("📅 Hari Pertama (Day 1): \(formattedDate(first.startedAt))")
//            print("📅 Hari Terakhir (Day 7): \(formattedDate(last.startedAt))")
//            print("📝 Refleksi Terakhir (Day 7): \"\(last.endOfDayReflection?.text ?? "")\"")
//        }
//        print("----------------------------------------------------\n")
//    }
//
//    // MARK: - 2. Ambil data dari day 21 - 28 (Week Keempat)
//    private static func testWeek4(for child: ChildProfile) {
//        print("--- 📂 TEST 2: Ambil Data Day 21 - 28 (Week Keempat) ---")
//        let sessions = DummyStory.generateSessions(for: child, startDay: 21, endDay: 28)
//
//        print("Jumlah hari diperoleh: \(sessions.count) (Target: 8)")
//        if let first = sessions.first, let last = sessions.last {
//            print("📅 Hari Pertama (Day 21): \(formattedDate(first.startedAt))")
//            print("📅 Hari Terakhir (Day 28): \(formattedDate(last.startedAt))")
//            print("📝 Refleksi Terakhir (Day 28): \"\(last.endOfDayReflection?.text ?? "")\"")
//        }
//        print("----------------------------------------------------\n")
//    }
//
//    // MARK: - 3. Ambil data dari day 5 - 5 (Tepat 1 Hari)
//    private static func testSingleDay(for child: ChildProfile) {
//        print("--- 📂 TEST 3: Ambil Data Day 5 - 5 (Tepat 1 Hari) ---")
//        let sessions = DummyStory.generateSessions(for: child, startDay: 5, endDay: 5)
//
//        print("Jumlah hari diperoleh: \(sessions.count) (Target: 1)")
//        if let singleDay = sessions.first {
//            print("📅 Tanggal Sesi (Day 5): \(formattedDate(singleDay.startedAt))")
//            print("📝 Refleksi Hari Ini: \"\(singleDay.endOfDayReflection?.text ?? "")\"")
//        }
//        print("----------------------------------------------------\n")
//    }
//
//    // MARK: - 4. Ambil data full dari day 1 - 30 (Full 1 Bulan)
//    private static func testFullMonth(for child: ChildProfile) {
//        print("--- 📂 TEST 4: Ambil Data Day 1 - 30 (Full 1 Bulan) ---")
//        let sessions = DummyStory.generateSessions(for: child, startDay: 1, endDay: 30)
//
//        print("Jumlah hari diperoleh: \(sessions.count) (Target: 30)")
//        if let first = sessions.first, let last = sessions.last {
//            print("📅 Hari Pertama (Day 1): \(formattedDate(first.startedAt))")
//            print("📅 Hari Terakhir (Day 30): \(formattedDate(last.startedAt))")
//            print("📝 Refleksi Hari Terakhir (Day 30): \"\(last.endOfDayReflection?.text ?? "")\"")
//        }
//        print("----------------------------------------------------\n")
//    }
//
//    // MARK: - Helper Formatting Tanggal
//    private static func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "EEEE, dd MMMM yyyy"
//        formatter.locale = Locale(identifier: "id_ID")
//        return formatter.string(from: date)
//    }
//}
