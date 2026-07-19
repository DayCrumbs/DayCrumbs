import Testing

@testable import DayCrumbs

@Suite("Dashboard VoiceOver announcements")
struct DashboardAccessibilityAnnouncementTests {
    @Test("Only insight generation produces a loading announcement")
    func loadingAnnouncements() {
        #expect(
            DashboardAccessibilityAnnouncement(
                state: .loading(.insight),
                selectedTimeRange: .week,
                hasEnglishFallback: false
            )?.message == "Generating Week insight."
        )
        #expect(
            DashboardAccessibilityAnnouncement(
                state: .loading(.stories),
                selectedTimeRange: .day,
                hasEnglishFallback: false
            ) == nil
        )
        #expect(
            DashboardAccessibilityAnnouncement(
                state: .loading(.outputTranslation),
                selectedTimeRange: .day,
                hasEnglishFallback: false
            ) == nil
        )
    }

    @Test("Completion uses the selected range")
    func completionAnnouncement() {
        let announcement = DashboardAccessibilityAnnouncement(
            state: .loaded,
            selectedTimeRange: .month,
            hasEnglishFallback: false
        )

        #expect(announcement?.message == "Month insight is ready.")
    }

    @Test("English fallback replaces the generic completion announcement")
    func englishFallbackAnnouncement() {
        let announcement = DashboardAccessibilityAnnouncement(
            state: .loaded,
            selectedTimeRange: .day,
            hasEnglishFallback: true
        )

        #expect(
            announcement?.message
                == "Insight is available in English. Translation can be retried."
        )
    }

    @Test("Empty and failed states use safe user-facing messages")
    func terminalStateAnnouncements() {
        let emptyAnnouncement = DashboardAccessibilityAnnouncement(
            state: .empty,
            selectedTimeRange: .week,
            hasEnglishFallback: false
        )
        let failureAnnouncement = DashboardAccessibilityAnnouncement(
            state: .failed(message: "Please try again."),
            selectedTimeRange: .week,
            hasEnglishFallback: false
        )

        #expect(
            emptyAnnouncement?.message
                == "There are no stories for this range."
        )
        #expect(failureAnnouncement?.message == "Please try again.")
    }
}
