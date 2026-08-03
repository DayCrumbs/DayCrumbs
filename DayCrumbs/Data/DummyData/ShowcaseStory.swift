import Foundation

/// A 16-day Indonesian showcase dataset for DayCrumbs demonstrations.
///
/// The first template is anchored to the current calendar day and the last
/// template is 15 days ahead. Each day keeps all four sessions so the Dashboard
/// chart remains useful while the notes and reflections provide explicit,
/// non-diagnostic circumstance-response relationships for insight generation.
///
/// The recurring signals are deliberately repeated inside every six-day window.
/// This matters because the primary Foundation Models context retains the latest
/// 24 events, or six complete showcase days:
/// - a changed getting-ready sequence alongside anger or sadness
/// - an unfamiliar food texture alongside disgust
/// - darkness or interrupting noise alongside fear at bedtime
/// - outdoor movement alongside a return to a happy mood
enum ShowcaseStory {

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

    static let templates: [DayTemplate] = [
        // Day 1: two clear single-day circumstances for the initial showcase.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .angry,
                    activity: .getReady,
                    place: .house,
                    noteText: "Saat urutan bersiap berubah karena kaus kaki belum ditemukan, Arya menangis dan melempar sepatunya."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .study,
                    place: .school,
                    noteText: "Arya kembali tersenyum ketika guru memberi satu petunjuk sederhana saat menempel gambar."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Setelah berlari dan bermain bola di halaman, Arya tertawa dan mengajak ayah bermain lagi."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Ketika lampu kamar dipadamkan, Arya berkata takut gelap dan meminta pintu tetap terbuka."
                ),
            ],
            reflectionText: "Hari ini perubahan urutan bersiap muncul bersama kemarahan Arya, sedangkan kamar gelap muncul bersama rasa takut sebelum tidur. Ia tampak lebih ceria setelah bergerak di luar."
        ),

        // Day 2: food texture and sleep-area noise.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .wakeUp,
                    place: .house,
                    noteText: "Arya bangun sambil tersenyum setelah tidur tanpa terbangun."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .surprise,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Arya tampak takjub saat menemukan ulat kecil ketika menyiram tanaman di halaman."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Saat merasakan tekstur brokoli yang lunak, Arya meringis, melepehkannya, lalu menolak suapan berikutnya."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Suara televisi yang keras dari ruang tengah membuat Arya terkejut dan memanggil ibu saat mulai tidur."
                ),
            ],
            reflectionText: "Tekstur brokoli yang lunak muncul bersama penolakan makan, dan suara televisi yang keras mengganggu proses Arya untuk tenang menjelang tidur."
        ),

        // Day 3: predictable morning choices and a dark bedroom.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .sad,
                    activity: .getReady,
                    place: .house,
                    noteText: "Ketika pilihan baju berubah mendadak, Arya menangis dan meminta baju yang masih dicuci."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .study,
                    place: .school,
                    noteText: "Arya tenang menyelesaikan gambar setelah guru membagi kegiatan menjadi satu langkah kecil."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Bermain gelembung sabun sambil berlari di taman diikuti tawa dan ajakan untuk mengulang permainan."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Saat kamar menjadi gelap, Arya menunjuk bayangan tirai dan meminta lampu redup dinyalakan."
                ),
            ],
            reflectionText: "Perubahan pilihan baju berkaitan dengan kesedihan pagi ini. Kamar yang gelap kembali muncul bersama rasa takut, sementara permainan bergerak di taman diikuti suasana yang lebih ceria."
        ),

        // Day 4: public-place noise and an unfamiliar vegetable texture.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .getReady,
                    place: .house,
                    noteText: "Arya memilih satu dari dua kaus yang tersedia lalu bersiap tanpa menangis."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .fear,
                    activity: .play,
                    place: .publicPlace,
                    noteText: "Ketika pengeras suara di pusat bermain berbunyi keras, Arya menutup telinga dan bersembunyi di belakang ayah."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Potongan wortel yang lembek membuat Arya meringis dan memindahkannya ke tepi piring."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .happy,
                    activity: .sleep,
                    place: .house,
                    noteText: "Urutan sikat gigi, membaca satu buku, lalu tidur berjalan tenang malam ini."
                ),
            ],
            reflectionText: "Suara keras di tempat umum muncul bersama rasa takut Arya. Saat makan malam, tekstur wortel yang lembek muncul bersama penolakan yang serupa dengan sayur sebelumnya."
        ),

        // Day 5: changed transition and recovery through outdoor movement.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .angry,
                    activity: .getReady,
                    place: .house,
                    noteText: "Saat waktu mandi dimajukan sebelum sarapan, Arya berteriak dan menolak masuk kamar mandi."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .study,
                    place: .school,
                    noteText: "Arya mengikuti kegiatan menyusun bentuk setelah guru menunjukkan satu contoh."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Sesudah berjalan cepat dan menendang bola di taman, Arya tertawa serta berbicara lebih banyak."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Bayangan dari lampu lorong membuat Arya takut dan meminta tirai kamar dirapikan."
                ),
            ],
            reflectionText: "Perubahan waktu mandi muncul bersama kemarahan saat bersiap. Gerak di taman diikuti suasana yang lebih ceria, sedangkan bayangan kamar muncul bersama rasa takut sebelum tidur."
        ),

        // Day 6: repeated mealtime texture and bedtime noise.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .sad,
                    activity: .wakeUp,
                    place: .house,
                    noteText: "Arya bangun sambil menangis setelah sempat terbangun oleh suara kendaraan semalam."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Berlari mengejar gelembung di halaman diikuti senyum dan tawa Arya."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Ketika menyentuh pepaya yang lembek, Arya menarik tangannya, meringis, dan tidak mau mencicipi."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Suara kendaraan yang keras dari jalan membuat Arya terbangun dan memanggil ayah."
                ),
            ],
            reflectionText: "Tekstur makanan yang lembek kembali muncul bersama penolakan makan. Suara kendaraan mengganggu tidur Arya, sementara bermain sambil bergerak di halaman diikuti suasana yang lebih ceria."
        ),

        // Day 7: changed getting-ready sequence and school separation.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .angry,
                    activity: .getReady,
                    place: .house,
                    noteText: "Saat sepatu yang biasa dipakai diganti dengan sepatu lain, Arya marah dan menendang tasnya."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .fear,
                    activity: .study,
                    place: .school,
                    noteText: "Ketika ibu berpamitan di pintu kelas, Arya memegang tangan ibu dan menangis."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Setelah bermain kejar-kejaran di halaman, Arya tersenyum dan bercerita tentang sekolah."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .happy,
                    activity: .sleep,
                    place: .house,
                    noteText: "Arya memilih buku, mendengarkan cerita, lalu tidur dengan tenang."
                ),
            ],
            reflectionText: "Pergantian sepatu muncul bersama kemarahan saat bersiap dan perpisahan di pintu kelas muncul bersama rasa takut. Bermain aktif di luar diikuti suasana yang lebih ringan."
        ),

        // Day 8: food texture and darkness.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .wakeUp,
                    place: .house,
                    noteText: "Arya bangun tenang lalu memilih sendiri buku yang ingin dibawa."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .surprise,
                    activity: .study,
                    place: .school,
                    noteText: "Arya terkejut lalu tersenyum ketika warna biru dan kuning yang dicampur berubah menjadi hijau."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Saat menemukan potongan tomat yang lembek, Arya meringis dan mengeluarkannya dari mulut."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Ketika lampu utama dimatikan dan kamar gelap, Arya berkata takut lalu meminta lampu redup."
                ),
            ],
            reflectionText: "Tekstur tomat yang lembek kembali muncul bersama penolakan saat makan. Kamar gelap juga kembali muncul bersama rasa takut sebelum tidur."
        ),

        // Day 9: changed morning order and a manageable public-place pause.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .sad,
                    activity: .getReady,
                    place: .house,
                    noteText: "Ketika sarapan dilakukan setelah berpakaian, berbeda dari urutan biasa, Arya menangis dan meminta kembali ke meja makan."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .fear,
                    activity: .play,
                    place: .publicPlace,
                    noteText: "Keramaian dan suara mesin permainan membuat Arya menutup telinga serta mendekat kepada ibu."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Setelah pindah ke taman yang lebih tenang dan berlari kecil, Arya kembali tersenyum."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .happy,
                    activity: .sleep,
                    place: .house,
                    noteText: "Rutinitas membaca satu buku lalu tidur berlangsung tenang."
                ),
            ],
            reflectionText: "Perubahan urutan pagi muncul bersama kesedihan. Keramaian di tempat umum muncul bersama rasa takut, lalu tempat yang lebih tenang dan gerak di luar diikuti senyum Arya."
        ),

        // Day 10: unfamiliar food and interrupted sleep.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .sad,
                    activity: .wakeUp,
                    place: .house,
                    noteText: "Arya bangun lesu setelah tidurnya terputus oleh suara pintu yang keras."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .study,
                    place: .school,
                    noteText: "Arya tersenyum saat menyusun kepingan gambar setelah diberi satu petunjuk."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Tekstur jamur yang kenyal membuat Arya meringis, melepehkannya, lalu memilih nasi."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Suara pintu yang dibanting membangunkan Arya dan ia menangis mencari ibu."
                ),
            ],
            reflectionText: "Tekstur jamur yang kenyal muncul bersama penolakan makan. Suara pintu yang keras mengganggu tidur dan diikuti rasa takut Arya."
        ),

        // Day 11: changed transition and outdoor movement.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .angry,
                    activity: .getReady,
                    place: .house,
                    noteText: "Saat sikat gigi dilakukan sebelum memilih baju, tidak seperti urutan biasa, Arya marah dan meletakkan sikat di lantai."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .play,
                    place: .school,
                    noteText: "Arya tertawa saat bermain bergiliran dengan bola bersama dua teman."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Berjalan dan menyiram tanaman di halaman diikuti suasana Arya yang lebih tenang dan ceria."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Bayangan lemari di kamar gelap membuat Arya takut dan meminta pintu lemari ditutup."
                ),
            ],
            reflectionText: "Perubahan urutan bersiap muncul bersama kemarahan pagi ini. Kegiatan bergerak dan menyiram tanaman di luar diikuti suasana yang lebih ceria, sedangkan kamar gelap muncul bersama rasa takut."
        ),

        // Day 12: repeated soft vegetable texture and bedtime noise.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .getReady,
                    place: .house,
                    noteText: "Arya mengikuti urutan gambar bersiap dan memilih sendiri antara dua celana."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Bermain bola dan berlari di taman diikuti tawa Arya."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Ketika menggigit buncis yang lembek, Arya meringis dan memindahkan semua potongannya ke tepi piring."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Suara percakapan yang keras di luar kamar membuat Arya terbangun dan memanggil ayah."
                ),
            ],
            reflectionText: "Tekstur buncis yang lembek kembali muncul bersama penolakan makan. Suara keras di dekat kamar mengganggu tidur Arya, sedangkan gerak di taman diikuti kegembiraan."
        ),

        // Day 13: school separation and a predictable bedtime.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .sad,
                    activity: .getReady,
                    place: .house,
                    noteText: "Saat tas sekolah tidak berada di tempat biasanya, Arya menangis dan menolak memakai sepatu."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .fear,
                    activity: .study,
                    place: .school,
                    noteText: "Ketika ayah berpamitan di gerbang sekolah, Arya memeluk kaki ayah dan menangis."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Sesudah bermain lempar bola di halaman, Arya tersenyum dan mau bercerita tentang kelas."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .happy,
                    activity: .sleep,
                    place: .house,
                    noteText: "Urutan mandi, memilih buku, membaca, lalu tidur membuat waktu malam berjalan tenang."
                ),
            ],
            reflectionText: "Perubahan letak tas muncul bersama kesedihan saat bersiap, dan perpisahan di gerbang muncul bersama rasa takut. Permainan bergerak di luar diikuti suasana yang lebih ceria."
        ),

        // Day 14: unfamiliar texture and a dark room.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .wakeUp,
                    place: .house,
                    noteText: "Arya bangun sambil tersenyum dan langsung merapikan selimut bersama ibu."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .surprise,
                    activity: .study,
                    place: .house,
                    noteText: "Arya tampak takjub saat berhasil membuat bentuk ikan dari adonan mainan."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Tekstur ikan yang lembek membuat Arya meringis, melepehkannya, dan tidak mau mencoba lagi."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Saat kamar menjadi gelap, Arya berkata takut pada bayangan dan meminta lampu redup dinyalakan."
                ),
            ],
            reflectionText: "Tekstur lauk yang lembek kembali muncul bersama penolakan makan. Kamar gelap dan bayangan kembali muncul bersama rasa takut sebelum tidur."
        ),

        // Day 15: changed getting-ready sequence and calm outdoor play.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .angry,
                    activity: .getReady,
                    place: .house,
                    noteText: "Ketika mandi harus dilakukan lebih awal dari urutan biasa, Arya berteriak dan menolak melepas pakaian."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .study,
                    place: .school,
                    noteText: "Arya menyelesaikan tugas menempel setelah guru memberi satu arahan pada setiap langkah."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Berjalan, berlari kecil, dan menyiram tanaman di halaman diikuti senyum serta percakapan yang lebih banyak."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .happy,
                    activity: .sleep,
                    place: .house,
                    noteText: "Arya memilih satu buku, mendengarkan cerita, lalu tertidur dengan tenang."
                ),
            ],
            reflectionText: "Perubahan urutan mandi muncul bersama kemarahan saat bersiap. Gerak dan kegiatan menyiram tanaman di luar diikuti suasana Arya yang lebih ceria."
        ),

        // Day 16: final showcase day retains the same high-signal themes.
        DayTemplate(
            entries: [
                EntryTemplate(
                    session: .morning,
                    mood: .happy,
                    activity: .getReady,
                    place: .house,
                    noteText: "Arya mengikuti urutan bersiap yang biasa dan memilih sendiri kaus kakinya."
                ),
                EntryTemplate(
                    session: .afternoon,
                    mood: .happy,
                    activity: .play,
                    place: .outdoor,
                    noteText: "Berlari dan bermain bola di halaman diikuti tawa serta ajakan bermain lagi."
                ),
                EntryTemplate(
                    session: .evening,
                    mood: .disgust,
                    activity: .eat,
                    place: .house,
                    noteText: "Saat merasakan tekstur terong yang lembek, Arya meringis, melepehkannya, lalu menutup mulut."
                ),
                EntryTemplate(
                    session: .night,
                    mood: .fear,
                    activity: .sleep,
                    place: .house,
                    noteText: "Suara kendaraan yang keras dari jalan membangunkan Arya dan ia memanggil ibu dengan takut."
                ),
            ],
            reflectionText: "Tekstur terong yang lembek kembali muncul bersama penolakan makan, dan suara kendaraan yang keras mengganggu tidur Arya. Bermain aktif di luar diikuti kegembiraan."
        ),
    ]

    /// Generates daily sessions constrained by template indices.
    ///
    /// Day 1 is the reference calendar day. Day 16 is 15 calendar days after
    /// the reference day.
    static func generateSessions(
        for child: ChildProfile,
        startDay: Int = 1,
        endDay: Int? = nil,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [DailySession] {
        let maxDays = templates.count
        let resolvedEndDay = min(endDay ?? maxDays, maxDays)
        let resolvedStartDay = max(1, min(startDay, resolvedEndDay))
        guard resolvedStartDay <= resolvedEndDay else {
            return []
        }

        let allSessions = generateAllAvailableSessions(
            for: child,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let startIndex = resolvedStartDay - 1
        let endIndex = resolvedEndDay - 1
        return Array(allSessions[startIndex...endIndex])
    }

    private static func generateAllAvailableSessions(
        for child: ChildProfile,
        referenceDate: Date,
        calendar: Calendar
    ) -> [DailySession] {
        var sessions: [DailySession] = []

        for (dayOffset, template) in templates.enumerated() {
            guard let baseDate = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: referenceDate
            ) else {
                continue
            }

            let startOfDay = calendar.startOfDay(for: baseDate)
            let morningTime = calendar.date(
                byAdding: .hour,
                value: 8,
                to: startOfDay
            ) ?? baseDate
            let afternoonTime = calendar.date(
                byAdding: .hour,
                value: 13,
                to: startOfDay
            ) ?? baseDate
            let eveningTime = calendar.date(
                byAdding: .hour,
                value: 17,
                to: startOfDay
            ) ?? baseDate
            let nightTime = calendar.date(
                byAdding: .hour,
                value: 20,
                to: startOfDay
            ) ?? baseDate
            let endOfDayTime = calendar.date(
                byAdding: .hour,
                value: 21,
                to: startOfDay
            ) ?? baseDate

            let dailySession = DailySession(
                startedAt: morningTime,
                childProfile: child
            )
            dailySession.endedAt = endOfDayTime

            let entries = template.entries.map { entryTemplate in
                let entryTime = switch entryTemplate.session {
                case .morning:
                    morningTime
                case .afternoon:
                    afternoonTime
                case .evening:
                    eveningTime
                case .night:
                    nightTime
                }

                let notes = entryTemplate.noteText.map {
                    AfterActivityNotes(text: $0, createdAt: entryTime)
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
                return storyEntry
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
}
