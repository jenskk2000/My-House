import Foundation
import SwiftUI

extension HouseStore {
    /// Demo data generated relative to `today` so weekday phrases work on demo day.
    /// Guarantees: today's dinner is cooked by Sam; the upcoming Saturday kitchen belongs to Kristian.
    func seed() {
        let kristian = Member(id: "kristian", displayName: "Kristian", color: Theme.coral)
        let sam = Member(id: "sam", displayName: "Sam", color: Theme.cobalt)
        let mia = Member(id: "mia", displayName: "Mia", color: Theme.teal)
        let members = [kristian, sam, mia]

        let t = today
        var dinners: [Dinner] = []
        for i in 0..<14 {
            dinners.append(Dinner(id: UUID(), date: t.adding(days: i), dish: nil, cookID: nil, time: nil, revision: 0))
        }
        dinners[0].dish = "Pasta"; dinners[0].cookID = "sam"; dinners[0].time = "19:00"; dinners[0].revision = 1
        // Upcoming Sunday (at least 2 days out so it never collides with Thursday demo phrases)
        let sundayOffset = (1 - t.weekday + 7) % 7 == 0 ? 7 : (1 - t.weekday + 7) % 7
        if sundayOffset < 14 {
            dinners[sundayOffset].dish = "Sunday roast"; dinners[sundayOffset].cookID = "mia"
            dinners[sundayOffset].time = "18:00"; dinners[sundayOffset].revision = 1
        }
        var attendance: [LocalDate: [MemberID: Attendance]] = [:]
        attendance[t] = ["kristian": .eating, "sam": .eating]

        let kitchen = ChoreTemplate(id: UUID(), name: "Kitchen", instructions: "Wipe surfaces, mop the floor, empty the dishwasher.", weekday: 7)
        let bathroom = ChoreTemplate(id: UUID(), name: "Bathroom", instructions: "Sink, shower, toilet, fresh towels.", weekday: 1)
        let bins = ChoreTemplate(id: UUID(), name: "Bins", instructions: "Take out general waste and recycling before 07:00.", weekday: 4)
        let templates = [kitchen, bathroom, bins]
        let rotation: [MemberID] = ["kristian", "sam", "mia"]

        var occurrences: [ChoreOccurrence] = []
        for tpl in templates {
            // first upcoming date with this weekday (today counts)
            let offset = (tpl.weekday - t.weekday + 7) % 7
            for week in 0..<4 {
                let date = t.adding(days: offset + week * 7)
                let startIndex: Int
                switch tpl.name {
                case "Kitchen": startIndex = 0   // Kristian first
                case "Bathroom": startIndex = 1  // Sam first
                default: startIndex = 2          // Mia first
                }
                let assignee = week < 2 ? rotation[(startIndex + week) % 3] : nil  // later weeks unclaimed
                occurrences.append(ChoreOccurrence(id: UUID(), templateID: tpl.id, name: tpl.name, date: date,
                                                   assigneeID: assignee, completedByID: nil, revision: 0))
            }
        }

        let events = [
            HouseEvent(id: UUID(), title: "Board game night", date: t.adding(days: 3), time: "20:00", creatorID: "mia"),
            HouseEvent(id: UUID(), title: "Landlord inspection", date: t.adding(days: 8), time: "10:00", creatorID: "kristian"),
        ]

        let base = now().addingTimeInterval(-3600)
        let messages = [
            Message(id: UUID(), sender: .member("sam"), body: "Anyone home for dinner Friday?", mentionsHouse: false, sentAt: base, taskID: nil),
            Message(id: UUID(), sender: .member("mia"), body: "I am, probably late though", mentionsHouse: false, sentAt: base.addingTimeInterval(120), taskID: nil),
        ]

        _seedSet(members: members, dinners: dinners, attendance: attendance, templates: templates,
                 occurrences: occurrences, events: events, messages: messages)
    }
}
