import Foundation

/// A calendar date in the house timezone (Europe/Oslo). No time component.
struct LocalDate: Hashable, Comparable, CustomStringConvertible, Codable {
    let year: Int
    let month: Int
    let day: Int

    static let timeZone = TimeZone(identifier: "Europe/Oslo")!
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        c.locale = Locale(identifier: "en_GB")
        return c
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    init(_ date: Date) {
        let c = Self.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Parses "YYYY-MM-DD". Returns nil for anything else.
    init?(iso: String) {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var description: String { iso }

    /// Noon on this date in the house timezone, safe across DST changes.
    var noon: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func adding(days: Int) -> LocalDate {
        LocalDate(Self.calendar.date(byAdding: .day, value: days, to: noon)!)
    }

    /// 1 = Sunday ... 7 = Saturday (Foundation convention).
    var weekday: Int { Self.calendar.component(.weekday, from: noon) }
    var isSaturday: Bool { weekday == 7 }
    var isSunday: Bool { weekday == 1 }

    var weekdayName: String { format("EEEE") }
    var shortLabel: String { format("EEE d MMM") }      // "Sat 19 Sep"
    var longLabel: String { format("EEEE d MMMM") }     // "Saturday 19 September"

    private static func format(_ pattern: String, _ d: LocalDate) -> String {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = timeZone; f.locale = calendar.locale
        f.dateFormat = pattern
        return f.string(from: d.noon)
    }
    private func format(_ pattern: String) -> String { Self.format(pattern, self) }

    static func < (a: LocalDate, b: LocalDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }
}

extension LocalDate: Identifiable {
    var id: String { iso }
}
