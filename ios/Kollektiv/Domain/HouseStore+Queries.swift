import Foundation

struct AttendanceSplit {
    var eating: [Member] = []
    var away: [Member] = []
    var unknown: [Member] = []
}

enum WeekItem: Identifiable, Hashable {
    case dinner(Dinner)
    case chore(ChoreOccurrence)
    case event(HouseEvent)

    var id: UUID {
        switch self {
        case .dinner(let d): return d.id
        case .chore(let c): return c.id
        case .event(let e): return e.id
        }
    }
    var date: LocalDate {
        switch self {
        case .dinner(let d): return d.date
        case .chore(let c): return c.date
        case .event(let e): return e.date
        }
    }
}

struct ChoreGroups {
    var yourTurn: [ChoreOccurrence] = []
    var needsSomeone: [ChoreOccurrence] = []
    var comingUp: [ChoreOccurrence] = []
}

extension HouseStore {
    func attendanceSplit(on date: LocalDate) -> AttendanceSplit {
        var split = AttendanceSplit()
        let row = attendance(on: date)
        for m in members {
            switch row[m.id] ?? .unknown {
            case .eating: split.eating.append(m)
            case .away: split.away.append(m)
            case .unknown: split.unknown.append(m)
            }
        }
        return split
    }

    func weekItems(from start: LocalDate, days: Int = 7) -> [(date: LocalDate, items: [WeekItem])] {
        (0..<days).map { i in
            let d = start.adding(days: i)
            var items: [WeekItem] = []
            if let dinner = dinner(on: d) { items.append(.dinner(dinner)) }
            items += occurrences.filter { $0.date == d }.map(WeekItem.chore)
            items += events.filter { $0.date == d }.map(WeekItem.event)
            return (d, items)
        }
    }

    func choreGroups(for member: MemberID) -> ChoreGroups {
        var g = ChoreGroups()
        for o in occurrences where o.date >= today && !o.isCompleted {
            if o.assigneeID == member { g.yourTurn.append(o) }
            else if o.assigneeID == nil { g.needsSomeone.append(o) }
            else { g.comingUp.append(o) }
        }
        return g
    }

    /// Plain-text snapshot the model reads via `read_house_context`.
    func contextText(from start: LocalDate, to end: LocalDate) -> String {
        var lines: [String] = []
        lines.append("House: \(houseName). Timezone: Europe/Oslo. Today: \(today.iso) (\(today.weekdayName)).")
        lines.append("Members: " + members.map { "\($0.displayName) (id: \($0.id))" }.joined(separator: ", "))
        lines.append("")
        lines.append("DINNERS")
        var d = start
        while d <= end {
            let dinner = dinner(on: d)
            let split = attendanceSplit(on: d)
            let dish = dinner?.dish ?? "not planned"
            let cook = dinner?.cookID.flatMap { member($0)?.displayName } ?? "no cook"
            lines.append("- \(d.iso) \(d.weekdayName): \(dish), cook: \(cook)\(dinner?.time.map { ", \($0)" } ?? ""). Eating: \(names(split.eating)); Away: \(names(split.away)); Not answered: \(names(split.unknown))")
            d = d.adding(days: 1)
        }
        lines.append("")
        lines.append("CHORE OCCURRENCES")
        for o in occurrences where o.date >= start && o.date <= end {
            let who = o.assigneeID.flatMap { member($0)?.displayName } ?? "unassigned"
            let pending = openProposal(forOccurrence: o.id) != nil ? " [cover request open]" : ""
            lines.append("- id \(o.id.uuidString) | \(o.date.iso) \(o.date.weekdayName) | \(o.name) | assignee: \(who)\(o.isCompleted ? " | completed" : "")\(pending)")
        }
        lines.append("")
        lines.append("EVENTS")
        for e in events where e.date >= start && e.date <= end {
            lines.append("- \(e.date.iso) \(e.date.weekdayName): \(e.title)\(e.time.map { " at \($0)" } ?? "")")
        }
        return lines.joined(separator: "\n")
    }

    private func names(_ ms: [Member]) -> String { ms.isEmpty ? "none" : ms.map(\.displayName).joined(separator: ", ") }
}
