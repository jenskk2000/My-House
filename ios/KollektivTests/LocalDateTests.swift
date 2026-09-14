import Testing
@testable import Kollektiv

@Suite struct LocalDateTests {
    @Test func parsesAndFormatsISO() {
        let d = LocalDate(iso: "2026-09-19")
        #expect(d?.iso == "2026-09-19")
        #expect(d?.isSaturday == true)
        #expect(LocalDate(iso: "19/09/2026") == nil)
    }
    @Test func addingDaysCrossesMonth() {
        let d = LocalDate(year: 2026, month: 9, day: 30).adding(days: 1)
        #expect(d == LocalDate(year: 2026, month: 10, day: 1))
    }
    @Test func acrossDSTEnd() {
        // DST ends 25 Oct 2026 in Oslo; adding a day must not drift.
        let d = LocalDate(year: 2026, month: 10, day: 24).adding(days: 1).adding(days: 1)
        #expect(d == LocalDate(year: 2026, month: 10, day: 26))
    }
}
