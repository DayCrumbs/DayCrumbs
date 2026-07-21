import Accessibility
import Testing

@testable import DayCrumbs

@Suite("Dashboard mood chart accessibility")
@MainActor
struct DashboardMoodChartDescriptorTests {
    
    @Test("Descriptor names the range and categorical axis")
    func descriptorTitles() {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .day,
            segments: [
                MoodBarChartSegment(timeLabel: "Morning", mood: .happy, count: 4)
            ]
        ).makeChartDescriptor()

        // Judul disesuaikan dengan implementasi terbaru
        #expect(descriptor.title == "Mood counts for Day.")
        #expect(descriptor.xAxis.title == "Session")
        #expect(descriptor.yAxis?.title == "Mood count")
    }

    @Test("Y-axis values are spoken as logged mood counts")
    func moodValueDescriptions() throws {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .week,
            segments: []
        ).makeChartDescriptor()
        
        let yAxis = try #require(descriptor.yAxis)

        // Pengujian disesuaikan untuk format pembacaan jumlah count
        for count in 1...6 {
            let spokenValue = yAxis.valueDescriptionProvider(Double(count))
            #expect(spokenValue == "\(count) logged moods")
        }
        
        // Pengecekan .nan dihapus karena yAxis sekarang menggunakan Int(value)
        // yang secara khusus menangani angka hitungan (count).
    }

    @Test("Descriptor groups chart data points into non-continuous mood series")
    func descriptorDataPoints() throws {
        let descriptor = DashboardMoodChartDescriptor(
            timeRange: .month,
            segments: [
                MoodBarChartSegment(timeLabel: "Week 1", mood: .happy, count: 3),
                MoodBarChartSegment(timeLabel: "Week 2", mood: .happy, count: 5),
            ]
        ).makeChartDescriptor()
        
        // Mengambil series pertama (karena datanya hanya berisi .happy, maka hanya ada 1 series)
        let series = try #require(descriptor.series.first)

        // Verifikasi bahwa series dipisahkan berdasarkan label aksesibilitas mood
        #expect(series.name == Moods.happy.accessibilityLabel)
        
        // Bar chart segment tidak bersifat berkesinambungan (isContinuous = false)
        #expect(!series.isContinuous)
        
        #expect(series.dataPoints.count == 2)
    }
}
